// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");
const f = @import("fixtures.zig");
const shared = @import("cases/shared.zig");

const byte = f.obj(&.{ .{ "kind", f.s("int") }, .{ "bits", f.n("8") }, .{ "signedness", f.s("unsigned") } });
const size = f.derive(&byte, &.{f.set("/bits", f.n("64"))});
const view = f.ref(&shared.pointer_21);
const pointer = f.ref(&shared.pointer_17);
const first = f.obj(&.{ .{ "kind", f.s("instruction") }, .{ "index", f.n("0") } });
const second = f.derive(&first, &.{f.set("/index", f.n("1"))});
const read = f.derive(&shared.air_memory_program_2_input_13, &.{
    f.set("/signature/parameters", f.arr(&.{ view, size })),
    f.set("/signature/returnType", byte),
    f.set("/sourceValidity/slices", f.arr(&.{})),
    f.set("/body", f.arr(&.{ f.n("0"), f.n("1"), f.n("2"), f.n("3") })),
    f.set("/instructions", f.arr(&.{
        f.obj(&.{ .{ "index", f.n("0") }, .{ "tag", f.s("arg") }, .{ "payloadVisited", f.b(true) }, .{ "type", view }, .{ "zirParameterIndex", f.n("0") } }),
        f.obj(&.{ .{ "index", f.n("1") }, .{ "tag", f.s("arg") }, .{ "payloadVisited", f.b(true) }, .{ "type", size }, .{ "zirParameterIndex", f.n("1") } }),
        f.obj(&.{ .{ "index", f.n("2") }, .{ "tag", f.s("slice_elem_val") }, .{ "payloadVisited", f.b(true) }, .{ "type", byte }, .{ "lhs", first }, .{ "rhs", second } }),
        f.obj(&.{ .{ "index", f.n("3") }, .{ "tag", f.s("ret") }, .{ "payloadVisited", f.b(true) }, .{ "type", f.obj(&.{.{ "kind", f.s("noreturn") }}) }, .{ "operand", f.derive(&first, &.{f.set("/index", f.n("2"))}) } }),
    })),
});
const indirect = f.derive(&read, &.{
    f.set("/signature/parameters/0", pointer), f.set("/instructions/0/type", pointer), f.set("/instructions/2/tag", f.s("ptr_elem_val")),
});

pub fn controls() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    for ([_]f.Value{ read, indirect }) |input| {
        const decoded = try z.air.decode(&ctx, try f.load(ctx.allocator, input), .memory);
        try std.testing.expect(std.mem.indexOf(u8, decoded, "(.load (.local 6))") != null);
    }
    const constant_kind = f.derive(&read, &.{f.set("/instructions/3/operand", f.obj(&.{.{ "kind", f.s("emptySlice") }}))});
    try std.testing.expectError(error.InvalidInput, z.air.decode(&ctx, try f.load(ctx.allocator, constant_kind), .memory));
    try std.testing.expectEqualStrings("AIR instruction 3 (ret) rejected. unsupported AIR constant kind 'emptySlice'", ctx.diagnostic);

    const unsupported_type = f.derive(&read, &.{f.set("/instructions/2/type", f.obj(&.{
        .{ "kind", f.s("unsupported") }, .{ "zigTypeTag", f.s("optional") },
    }))});
    try std.testing.expectError(error.InvalidInput, z.air.decode(&ctx, try f.load(ctx.allocator, unsupported_type), .memory));
    try std.testing.expectEqualStrings("AIR instruction 2 (slice_elem_val) rejected. unsupported Zig AIR type 'optional'", ctx.diagnostic);
    const unsupported_layout = f.derive(&read, &.{f.set("/instructions/2/type", f.obj(&.{
        .{ "kind", f.s("unsupported") }, .{ "reason", f.s("unresolved-enum") },
    }))});
    try std.testing.expectError(error.InvalidInput, z.air.decode(&ctx, try f.load(ctx.allocator, unsupported_layout), .memory));
    try std.testing.expectEqualStrings("AIR instruction 2 (slice_elem_val) rejected. unsupported Zig AIR type (unresolved-enum)", ctx.diagnostic);

    for ([_]f.Value{
        f.derive(&read, &.{f.set("/instructions/2/type", size)}),
        f.derive(&read, &.{f.set("/instructions/2/rhs/index", f.n("0"))}),
        f.derive(&read, &.{f.set("/instructions/2/tag", f.s("ptr_elem_val"))}),
        f.derive(&read, &.{f.set("/instructions/2/lhs/index", f.n("2"))}),
    }) |input| try std.testing.expectError(error.InvalidInput, z.air.decode(&ctx, try f.load(ctx.allocator, input), .memory));
}

pub fn emitted(ctx: *z.common.Context) ![]const u8 {
    const raw = try f.load(ctx.allocator, read);
    const wrong_type = try f.load(ctx.allocator, f.derive(&read, &.{f.set("/instructions/2/type", size)}));
    const wrong_owner = try f.load(ctx.allocator, f.derive(&read, &.{f.set("/instructions/2/tag", f.s("ptr_elem_val"))}));
    return ctx.fmt(
        \\import Compiler.ZigAir.Captured
        \\open Compiler.ZigAir Compiler.ZigAir.MemoryAir Compiler.ZigAir.Memory
        \\def readByte : Program := {s}
        \\{s}
        \\def heap : State := ⟨[(0, ⟨1, .array 2 (.scalar (.int false 8)), [(0, .scalar (.int false 8 42))], true, false⟩)], 1, 3⟩
        \\def view : Value := .slice (.slice false (.scalar (.int false 8))) ⟨0, 0⟩ 1
        \\example : readByte.run [view, .scalar (.int false 64 0)] heap = (.ok (.scalar (.int false 8 42)), heap) := rfl
        \\example : readByte.run [view, .scalar (.int false 64 1)] heap = (.error .sourceBounds, heap) := rfl
        \\example : readByte.run [.slice (.slice false (.scalar (.int false 8))) ⟨0, 0⟩ 2, .scalar (.int false 64 1)] heap = (.error .uninitialized, heap) := rfl
        \\example : Captured.decode false {s} = none := rfl
        \\example : Captured.decode false {s} = none := rfl
        \\
    , .{ try z.air.decode(ctx, raw, .memory), try z.certificate.declaration(ctx, raw, "readByte", false), try z.certificate.lift(ctx, wrong_type, 0), try z.certificate.lift(ctx, wrong_owner, 0) });
}
