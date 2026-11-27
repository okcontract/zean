// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Select a concrete captured specialization under its source declaration.
//! Check the source parameter inventory against the concrete AIR instance.
const std = @import("std");
const c = @import("common.zig");
const source = @import("source.zig");
const specialization = @import("specialization.zig");
const declaration_source = @import("declaration_source.zig");
const Profile = @import("types.zig").Profile;

const Selection = enum { standalone, direct_call };

/// Bind a named file-local enum to its literal source declaration. The AIR
/// constant decoder has already checked the selected value against its tag table.
fn enumArgument(ctx: *c.Context, file: *const declaration_source.File, owner: []const u8, parameter_type: std.zig.Ast.Node.Index, value: c.Value) !void {
    const tree = &file.declarations.tree;
    try ctx.require(source.plainIdentifier(owner) and tree.nodeTag(parameter_type) == .identifier, "comptime enum requires a file-level callee and a named parameter type");
    const name = tree.tokenSlice(tree.nodeMainToken(parameter_type));
    const ty = try ctx.field(value, "type");
    const identity = try ctx.field(ty, "identity");
    try ctx.require(source.plainIdentifier(name) and c.tag(identity, "name", try ctx.fmt("{s}{s}", .{ file.prefix, name })) and
        c.tag(identity, "sourceFile", file.filename) and c.tag(identity, "sourceSha256", &file.sha), "comptime enum source identity mismatch");
    const scope = try file.declarations.root().containerNamed(name);
    var buffer: [2]std.zig.Ast.Node.Index = undefined;
    const decl = tree.fullContainerDecl(&buffer, scope.node).?;
    try ctx.require(tree.tokenTag(decl.ast.main_token) == .keyword_enum and decl.layout_token == null, "expected a literal enum declaration");
    const tags = try ctx.array(try ctx.field(ty, "fields"));
    const backing = try ctx.nat(try ctx.field(try ctx.field(ty, "backingType"), "bits"), 8);
    if (decl.ast.arg.unwrap()) |arg| {
        try ctx.require(tree.nodeTag(arg) == .identifier and std.mem.eql(u8, tree.tokenSlice(tree.nodeMainToken(arg)), try ctx.fmt("u{d}", .{backing})), "comptime enum backing type mismatch");
    } else try ctx.require(backing == std.math.log2_int_ceil(usize, tags.len), "comptime enum inferred width mismatch");
    var index: usize = 0;
    var next: u64 = 0;
    for (decl.ast.members) |member| {
        const field = tree.fullContainerField(member) orelse continue;
        const spelling = tree.tokenSlice(field.ast.main_token);
        try ctx.require(index < tags.len and source.plainIdentifier(spelling) and !std.mem.eql(u8, spelling, "_") and c.tag(tags[index], "name", spelling), "comptime enum source tag mismatch");
        if (field.ast.value_expr.unwrap()) |expr| {
            try ctx.require(tree.nodeTag(expr) == .number_literal, "unsupported comptime enum tag expression");
            next = std.fmt.parseInt(u8, tree.tokenSlice(tree.nodeMainToken(expr)), 0) catch return ctx.fail("unsupported comptime enum tag literal", .{});
        }
        try ctx.require(next == try ctx.nat(try ctx.field(tags[index], "value"), 255), "comptime enum source value mismatch");
        index += 1;
        next += 1;
    }
    try ctx.require(index == tags.len, "comptime enum source field count mismatch");
}

pub fn select(ctx: *c.Context, record: c.Value, profile: Profile, filename: []const u8, bytes: []const u8) !specialization.Mapping {
    var file = try declaration_source.File.init(ctx, filename, bytes);
    defer file.declarations.deinit();
    var sources: c.Value = .{ .object = .empty };
    try sources.object.put(ctx.allocator, filename, .{ .string = &file.sha });
    return bind(ctx, record, profile, &file, sources, null);
}

pub fn selectForCall(ctx: *c.Context, record: c.Value, profile: Profile, file: *const declaration_source.File, sources: c.Value, retained: *declaration_source.Retained) !specialization.Mapping {
    return bind(ctx, record, profile, file, sources, retained);
}

fn bind(ctx: *c.Context, record: c.Value, profile: Profile, file: *const declaration_source.File, sources: c.Value, retained: ?*declaration_source.Retained) !specialization.Mapping {
    const selection: Selection = if (retained != null) .direct_call else .standalone;
    const prefix = file.prefix;
    try ctx.require(c.tag(record, "sourceFile", file.filename) and c.tag(record, "sourceSha256", &file.sha), "specialization source identity mismatch");
    const signature = try ctx.field(record, "signature");
    try ctx.require(c.flag(signature, "genericInstance", true) and try ctx.nat(try ctx.field(signature, "noaliasBits"), 0) == 0, "specialization must be concrete and omit noalias parameters");
    const mapping = try specialization.mapping(ctx, record, profile, sources, retained);
    const spec = try ctx.field(record, "specialization");
    const owner = try ctx.str(try ctx.field(try ctx.field(spec, "owner"), "name"));
    try ctx.require(std.mem.startsWith(u8, owner, prefix), "specialization has a different source owner");
    const relative = owner[prefix.len..];
    if (selection == .standalone) try ctx.require(source.plainIdentifier(relative), "standalone specialization requires a file-level function");
    const instance = try ctx.str(try ctx.field(record, "name"));
    const instance_prefix = try ctx.fmt("{s}__func_", .{owner});
    try ctx.require(std.mem.startsWith(u8, instance, instance_prefix) and instance.len > instance_prefix.len, "instance does not identify its declared owner");
    _ = std.fmt.parseInt(u64, instance[instance_prefix.len..], 10) catch return ctx.fail("invalid specialization instance identity", .{});
    const declarations = &file.declarations;
    var buffer: [1]std.zig.Ast.Node.Index = undefined;
    const function = try declaration_source.functionProto(ctx, record, declarations, relative, &buffer);
    try ctx.require(function.ast.callconv_expr == .none and function.ast.align_expr == .none and function.ast.addrspace_expr == .none, "unsupported specialized source function attributes");
    var iterator = function.iterate(&declarations.tree);
    var count: usize = 0;
    var comptime_bits: u64 = 0;
    var runtime_anytype = false;
    const arguments = try ctx.array(try ctx.field(spec, "arguments"));
    while (iterator.next()) |parameter| : (count += 1) {
        try ctx.require(count < arguments.len and count < 32, "unsupported specialization arity");
        if (parameter.anytype_ellipsis3) |token| {
            try ctx.require(selection == .direct_call and declarations.tree.tokenTag(token) == .keyword_anytype and parameter.comptime_noalias == null, "unsupported anytype or variadic parameter");
            runtime_anytype = true;
        } else try ctx.require(parameter.type_expr != null, "missing specialized source parameter type");
        if (parameter.comptime_noalias) |token| {
            try ctx.require(declarations.tree.tokenTag(token) == .keyword_comptime, "source noalias contract is not admitted");
            const ty = parameter.type_expr.?;
            const arg = arguments[count];
            const tree = &declarations.tree;
            const first = tree.firstToken(ty);
            const type_argument = c.tag(arg, "kind", "type") and first == tree.lastToken(ty) and std.mem.eql(u8, tree.tokenSlice(first), "type");
            var callback_buffer: [1]std.zig.Ast.Node.Index = undefined;
            const callback = selection == .direct_call and c.tag(arg, "kind", "value") and
                c.tag(try ctx.field(arg, "value"), "kind", "function") and tree.fullFnProto(&callback_buffer, ty) != null;
            if (selection == .direct_call and c.tag(arg, "kind", "value") and c.tag(try ctx.field(arg, "value"), "kind", "enumTag")) {
                try enumArgument(ctx, file, relative, ty, try ctx.field(arg, "value"));
            } else try ctx.require(type_argument or callback, "expected an explicit comptime type, named enum value or named callback");
            comptime_bits |= @as(u64, 1) << @intCast(count);
        } else {
            const arg = arguments[count];
            // Older captures classify every runtime parameter as "runtime".
            const marked_anytype = c.tag(arg, "kind", "runtimeAnytype");
            try ctx.require(c.tag(arg, "kind", "runtime") or (marked_anytype and parameter.anytype_ellipsis3 != null), "source runtime parameter changed specialization");
        }
    }
    try ctx.require((comptime_bits != 0 or runtime_anytype) and count == arguments.len and count == try ctx.nat(try ctx.field(spec, "sourceParameterCount"), 32) and comptime_bits == try ctx.nat(try ctx.field(spec, "sourceComptimeBits"), std.math.maxInt(u32)) and try ctx.nat(try ctx.field(spec, "sourceNoaliasBits"), 0) == 0, "source signature disagrees with specialization metadata");
    return mapping;
}
