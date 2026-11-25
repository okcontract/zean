// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Select a concrete captured specialization under its source declaration.
//! Check the source parameter inventory against the concrete AIR instance.
const std = @import("std");
const c = @import("common.zig");
const source = @import("source.zig");
const specialization = @import("specialization.zig");
const declaration_source = @import("declaration_source.zig");

const Selection = enum { standalone, direct_call };

pub fn select(ctx: *c.Context, record: c.Value, filename: []const u8, bytes: []const u8) !specialization.Mapping {
    var file = try declaration_source.File.init(ctx, filename, bytes);
    defer file.declarations.deinit();
    var sources: c.Value = .{ .object = .empty };
    try sources.object.put(ctx.allocator, filename, .{ .string = &file.sha });
    return bind(ctx, record, &file, sources, null, .standalone);
}

pub fn selectForCall(ctx: *c.Context, record: c.Value, file: *const declaration_source.File, sources: c.Value, retained: *declaration_source.Retained) !specialization.Mapping {
    return bind(ctx, record, file, sources, retained, .direct_call);
}

fn bind(ctx: *c.Context, record: c.Value, file: *const declaration_source.File, sources: c.Value, retained: ?*declaration_source.Retained, selection: Selection) !specialization.Mapping {
    const prefix = file.prefix;
    try ctx.require(c.tag(record, "sourceFile", file.filename) and c.tag(record, "sourceSha256", &file.sha), "specialization source identity mismatch");
    const signature = try ctx.field(record, "signature");
    try ctx.require(c.flag(signature, "genericInstance", true) and try ctx.nat(try ctx.field(signature, "noaliasBits"), 0) == 0, "specialization must be concrete and omit noalias parameters");
    const mapping = try specialization.mapping(ctx, record, sources, retained);
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
            try ctx.require(type_argument or callback, "expected an explicit comptime type or a named callback in a direct call");
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
