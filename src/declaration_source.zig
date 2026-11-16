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
    const prefix = try ctx.fmt("{s}.", .{stem});
    const writable = @constCast(prefix);
    for (writable) |*byte| if (byte.* == '/') {
        byte.* = '.';
    };
    return prefix;
}

pub fn select(ctx: *c.Context, record: c.Value, sources: c.Value, filename: []const u8, bytes: []const u8) !void {
    const prefix = try ownerPrefix(ctx, filename);
    const sha = c.digest(bytes);
    try ctx.require(c.tag(record, "sourceFile", filename) and c.tag(record, "sourceSha256", &sha) and c.tag(sources, filename, &sha), "declaration source is outside the captured source closure or changed");
    const signature = try ctx.field(record, "signature");
    try ctx.require(c.flag(signature, "genericInstance", false) and c.flag(signature, "varArgs", false) and try ctx.nat(try ctx.field(signature, "noaliasBits"), 0) == 0, "ordinary declaration requires concrete runtime parameters without noalias");
    const name = try ctx.str(try ctx.field(record, "name"));
    try ctx.require(std.mem.startsWith(u8, name, prefix), "captured function has a different source owner");
    var declarations = try source.Declarations.init(ctx, bytes);
    defer declarations.deinit();
    var owner = declarations.root();
    var parts = std.mem.splitScalar(u8, name[prefix.len..], '.');
    var component = parts.next().?;
    var depth: usize = 0;
    while (parts.next()) |next| {
        depth += 1;
        try ctx.require(depth <= 32 and source.plainIdentifier(component), "unsupported declaration owner path");
        owner = try owner.containerNamed(component);
        component = next;
    }
    try ctx.require(source.plainIdentifier(component), "unsupported captured function name");
    var buffer: [1]std.zig.Ast.Node.Index = undefined;
    const function = try owner.function(component, &buffer);
    try ctx.require(function.ast.callconv_expr == .none and function.ast.align_expr == .none and function.ast.addrspace_expr == .none, "unsupported source function attributes");
    var parameters = function.iterate(&declarations.tree);
    var count: usize = 0;
    while (parameters.next()) |parameter| : (count += 1) {
        try ctx.require(parameter.comptime_noalias == null and parameter.anytype_ellipsis3 == null and parameter.type_expr != null, "ordinary declaration has unsupported parameter semantics");
    }
    try ctx.require(count == (try ctx.array(try ctx.field(signature, "parameters"))).len, "source parameter count disagrees with captured signature");
}
