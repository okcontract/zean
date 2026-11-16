// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Select a concrete captured specialization under its actual file-level owner.
//! This binds provenance and explicit type parameters, not source/AIR refinement.
const std = @import("std");
const c = @import("common.zig");
const source = @import("source.zig");
const specialization = @import("specialization.zig");

pub fn select(ctx: *c.Context, record: c.Value, filename: []const u8, bytes: []const u8) !specialization.Mapping {
    try ctx.require(std.mem.endsWith(u8, filename, ".zig") and std.mem.eql(u8, filename, std.fs.path.basename(filename)), "specialization requires a file-level source identity");
    const sha = c.digest(bytes);
    try ctx.require(c.tag(record, "sourceFile", filename) and c.tag(record, "sourceSha256", &sha), "specialization source identity mismatch");
    var sources: c.Value = .{ .object = .empty };
    try sources.object.put(ctx.allocator, filename, .{ .string = try ctx.allocator.dupe(u8, &sha) });
    const signature = try ctx.field(record, "signature");
    try ctx.require(c.flag(signature, "genericInstance", true) and try ctx.nat(try ctx.field(signature, "noaliasBits"), 0) == 0, "only explicit type specializations without noalias are admitted");
    const mapping = try specialization.mapping(ctx, record, sources);
    const spec = try ctx.field(record, "specialization");
    const owner = try ctx.str(try ctx.field(try ctx.field(spec, "owner"), "name"));
    const prefix = try ctx.fmt("{s}.", .{filename[0 .. filename.len - 4]});
    try ctx.require(std.mem.startsWith(u8, owner, prefix) and source.plainIdentifier(owner[prefix.len..]), "specialization owner must be a file-level function");
    const instance = try ctx.str(try ctx.field(record, "name"));
    const instance_prefix = try ctx.fmt("{s}__func_", .{owner});
    try ctx.require(std.mem.startsWith(u8, instance, instance_prefix) and instance.len > instance_prefix.len, "instance does not identify its declared owner");
    _ = std.fmt.parseInt(u64, instance[instance_prefix.len..], 10) catch return ctx.fail("invalid specialization instance identity", .{});
    var declarations = try source.Declarations.init(ctx, bytes);
    defer declarations.deinit();
    var buffer: [1]std.zig.Ast.Node.Index = undefined;
    const function = try declarations.root().function(owner[prefix.len..], &buffer);
    try ctx.require(function.ast.callconv_expr == .none and function.ast.align_expr == .none and function.ast.addrspace_expr == .none, "unsupported specialized source function attributes");
    var iterator = function.iterate(&declarations.tree);
    var count: u64 = 0;
    var comptime_bits: u64 = 0;
    const arguments = try ctx.array(try ctx.field(spec, "arguments"));
    while (iterator.next()) |parameter| : (count += 1) {
        try ctx.require(count < arguments.len and count < 32 and parameter.anytype_ellipsis3 == null and parameter.type_expr != null, "unsupported source parameter or specialization arity");
        if (parameter.comptime_noalias) |token| {
            try ctx.require(declarations.tree.tokenTag(token) == .keyword_comptime, "source noalias contract is not admitted");
            const ty = parameter.type_expr.?;
            try ctx.require(declarations.tree.firstToken(ty) == declarations.tree.lastToken(ty) and std.mem.eql(u8, declarations.tree.tokenSlice(declarations.tree.firstToken(ty)), "type") and c.tag(arguments[@intCast(count)], "kind", "type"), "only explicit comptime type parameters are admitted");
            comptime_bits |= @as(u64, 1) << @intCast(count);
        } else try ctx.require(c.tag(arguments[@intCast(count)], "kind", "runtime"), "source runtime parameter changed specialization");
    }
    try ctx.require(count == arguments.len and count == try ctx.nat(try ctx.field(spec, "sourceParameterCount"), 32) and comptime_bits == try ctx.nat(try ctx.field(spec, "sourceComptimeBits"), std.math.maxInt(u32)) and try ctx.nat(try ctx.field(spec, "sourceNoaliasBits"), 0) == 0, "source signature disagrees with specialization metadata");
    return mapping;
}
