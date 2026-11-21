// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Bind an ordinary captured function to its actual source declaration and owner.
//! This checks identity and parameter shape, not source-to-AIR preservation.
const std = @import("std");
const c = @import("common.zig");
const source = @import("source.zig");

/// File namespaces retain every directory component. A basename match cannot
/// bind a declaration from a different module with the same leaf filename.
pub fn ownerPrefix(ctx: *c.Context, filename: []const u8) ![]const u8 {
    try ctx.require(@import("runtime.zig").safeArchiveName(filename) and std.mem.endsWith(u8, filename, ".zig"), "invalid declaration source path");
    const stem = filename[0 .. filename.len - 4];
    var parts = std.mem.splitScalar(u8, stem, '/');
    while (parts.next()) |part| try ctx.require(source.plainIdentifier(part), "unsupported declaration source component");
    const prefix = try std.fmt.allocPrint(ctx.allocator, "{s}.", .{stem});
    for (prefix) |*byte| if (byte.* == '/') {
        byte.* = '.';
    };
    return prefix;
}

pub const File = struct {
    filename: []const u8,
    prefix: []const u8,
    sha: [64]u8,
    declarations: source.Declarations,

    pub fn init(ctx: *c.Context, filename: []const u8, bytes: []const u8) !File {
        return .{ .filename = filename, .prefix = try ownerPrefix(ctx, filename), .sha = c.digest(bytes), .declarations = try source.Declarations.init(ctx, bytes) };
    }
};

pub fn select(ctx: *c.Context, record: c.Value, sources: c.Value, filename: []const u8, bytes: []const u8) !void {
    var file = try File.init(ctx, filename, bytes);
    defer file.declarations.deinit();
    try selectParsed(ctx, record, sources, &file);
}

pub fn selectParsed(ctx: *c.Context, record: c.Value, sources: c.Value, file: *const File) !void {
    try ctx.require(c.tag(record, "sourceFile", file.filename) and c.tag(record, "sourceSha256", &file.sha) and c.tag(sources, file.filename, &file.sha), "declaration source is outside the captured source closure or changed");
    const signature = try ctx.field(record, "signature");
    try ctx.require(c.flag(signature, "genericInstance", false) and c.flag(signature, "varArgs", false) and try ctx.nat(try ctx.field(signature, "noaliasBits"), 0) == 0, "ordinary declaration requires concrete runtime parameters without noalias");
    const name = try ctx.str(try ctx.field(record, "name"));
    try ctx.require(std.mem.startsWith(u8, name, file.prefix), "captured function has a different source owner");
    const declarations = &file.declarations;
    var buffer: [1]std.zig.Ast.Node.Index = undefined;
    const function = try functionProto(ctx, record, declarations, name[file.prefix.len..], &buffer);
    try ctx.require(function.ast.callconv_expr == .none and function.ast.align_expr == .none and function.ast.addrspace_expr == .none, "unsupported source function attributes");
    var parameters = function.iterate(&declarations.tree);
    var count: usize = 0;
    while (parameters.next()) |parameter| : (count += 1) {
        try ctx.require(parameter.comptime_noalias == null and parameter.anytype_ellipsis3 == null and parameter.type_expr != null, "ordinary declaration has unsupported parameter semantics");
    }
    try ctx.require(count == (try ctx.array(try ctx.field(signature, "parameters"))).len, "source parameter count disagrees with captured signature");
}

/// Resolve the declaration in its lexical owner and bind the compiler's prototype anchor.
pub fn functionProto(ctx: *c.Context, record: c.Value, declarations: *const source.Declarations, relative: []const u8, buffer: *[1]std.zig.Ast.Node.Index) c.Error!std.zig.Ast.full.FnProto {
    const tree = &declarations.tree;
    const anchor = c.get(record, "sourceDeclarationNode");
    const node = if (std.mem.indexOfScalar(u8, relative, '(')) |arguments| blk: {
        try ctx.require(anchor != null, "instantiated declaration owner requires a captured source anchor");
        break :blk try instantiatedMember(ctx, declarations, relative, arguments);
    } else blk: {
        const selected = try namedOwner(ctx, declarations.root(), relative);
        break :blk try selected.scope.functionNode(selected.member);
    };
    const function = tree.fullFnProto(buffer, node) orelse return ctx.fail("unsupported function declaration", .{});
    if (anchor) |index| try ctx.require(try ctx.nat(index, tree.nodes.len - 1) == @backingInt(function.ast.proto_node), "captured declaration anchor changed");
    return function;
}

fn namedOwner(ctx: *c.Context, root: source.Scope, name: []const u8) !struct { scope: source.Scope, member: []const u8 } {
    var owner = root;
    var parts = std.mem.splitScalar(u8, name, '.');
    var component = parts.next().?;
    var depth: usize = 0;
    while (parts.next()) |next| {
        depth += 1;
        try ctx.require(depth <= 32 and source.plainIdentifier(component), "unsupported declaration owner path");
        owner = try owner.containerNamed(component);
        component = next;
    }
    try ctx.require(source.plainIdentifier(component), "unsupported captured function name");
    return .{ .scope = owner, .member = component };
}

// The compiler's instantiated namespace includes the displayed comptime
// arguments. Bind the method to the captured AST node inside the lexical
// factory rather than guessing among methods with the same name.
fn instantiatedMember(ctx: *c.Context, declarations: *const source.Declarations, name: []const u8, arguments: usize) c.Error!std.zig.Ast.Node.Index {
    const tokens = try source.tokenize(ctx, name[arguments..]);
    const close = try source.balanced(ctx, tokens, 0);
    const suffix = name[arguments + tokens[close].end ..];
    try ctx.require(std.mem.startsWith(u8, suffix, "."), "invalid instantiated declaration path");

    const selected = try namedOwner(ctx, declarations.root(), name[0..arguments]);
    const factory = try selected.scope.functionNode(selected.member);
    const tree = &declarations.tree;
    var factory_buffer: [1]std.zig.Ast.Node.Index = undefined;
    const factory_proto = tree.fullFnProto(&factory_buffer, factory) orelse return ctx.fail("unsupported type factory", .{});
    const return_type = factory_proto.ast.return_type.unwrap() orelse return ctx.fail("type factory has no return type", .{});
    const type_token = tree.firstToken(return_type);
    try ctx.require(type_token == tree.lastToken(return_type) and std.mem.eql(u8, tree.tokenSlice(type_token), "type"), "instantiated owner is not a type factory");

    var statement_buffer: [2]std.zig.Ast.Node.Index = undefined;
    const body = tree.nodeData(factory).node_and_node[1];
    const statements = tree.blockStatements(&statement_buffer, body) orelse return ctx.fail("unsupported type factory body", .{});
    try ctx.require(statements.len > 0, "type factory has no return statement");
    const last = statements[statements.len - 1];
    try ctx.require(tree.nodeTag(last) == .@"return", "type factory must end in a direct return");
    const result = tree.nodeData(last).opt_node.unwrap() orelse return ctx.fail("type factory has no returned container", .{});
    const scope = try selected.scope.containerValue(result);
    const owner = try namedOwner(ctx, scope, suffix[1..]);
    return owner.scope.functionNode(owner.member);
}
