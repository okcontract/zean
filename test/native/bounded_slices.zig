// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");
const f = @import("fixtures.zig");
const shared = @import("cases/shared.zig");

const size = f.obj(&.{ .{ "kind", f.s("int") }, .{ "bits", f.n("64") }, .{ "signedness", f.s("unsigned") } });
const view = f.ref(&shared.pointer_21);
const pointer = f.ref(&shared.pointer_17);
fn ref(comptime index: []const u8) f.Value {
    return comptime f.obj(&.{ .{ "kind", f.s("instruction") }, .{ "index", f.n(index) } });
}
const bounded = f.derive(&shared.air_memory_program_2_input_13, &.{
    f.set("/signature/parameters", f.arr(&.{ view, size, size })),                                               f.set("/signature/returnType", view),
    f.set("/sourceOperationTags", f.arr(&.{f.s("slice_length")})),
    f.set("/sourceValidity/slices", f.arr(&.{f.obj(&.{
        .{ "source", f.obj(&.{ .{ "file", f.s("fixture.zig") }, .{ "sha256", f.s("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") }, .{ "span", f.obj(&.{ .{ "start", f.n("0") }, .{ "main", f.n("1") }, .{ "end", f.n("4") } }) } }) },
        .{ "anchor", f.obj(&.{ .{ "kind", f.s("beforeInstruction") }, .{ "index", f.n("6") }, .{ "inSupportedBody", f.b(true) } }) },
        .{ "start", ref("1") },
        .{ "end", ref("5") },
        .{ "upperBound", f.obj(&.{ .{ "kind", f.s("sliceLength") }, .{ "original", ref("0") } }) },
        .{ "unsupportedReason", .null },
    })})),
    f.set("/body", f.arr(&.{ f.n("0"), f.n("1"), f.n("2"), f.n("3"), f.n("4"), f.n("5"), f.n("6"), f.n("7") })),
    f.set("/instructions", f.arr(&.{
        f.obj(&.{ .{ "index", f.n("0") }, .{ "tag", f.s("arg") }, .{ "payloadVisited", f.b(true) }, .{ "type", view }, .{ "zirParameterIndex", f.n("0") } }),
        f.obj(&.{ .{ "index", f.n("1") }, .{ "tag", f.s("arg") }, .{ "payloadVisited", f.b(true) }, .{ "type", size }, .{ "zirParameterIndex", f.n("1") } }),
        f.obj(&.{ .{ "index", f.n("2") }, .{ "tag", f.s("arg") }, .{ "payloadVisited", f.b(true) }, .{ "type", size }, .{ "zirParameterIndex", f.n("2") } }),
        f.obj(&.{ .{ "index", f.n("3") }, .{ "tag", f.s("slice_ptr") }, .{ "payloadVisited", f.b(true) }, .{ "type", pointer }, .{ "operand", ref("0") } }),
        f.obj(&.{ .{ "index", f.n("4") }, .{ "tag", f.s("ptr_add") }, .{ "payloadVisited", f.b(true) }, .{ "type", pointer }, .{ "lhs", ref("3") }, .{ "rhs", ref("1") } }),
        f.obj(&.{ .{ "index", f.n("5") }, .{ "tag", f.s("add") }, .{ "payloadVisited", f.b(true) }, .{ "type", size }, .{ "lhs", ref("1") }, .{ "rhs", ref("2") } }),
        f.obj(&.{ .{ "index", f.n("6") }, .{ "tag", f.s("slice") }, .{ "payloadVisited", f.b(true) }, .{ "type", view }, .{ "lhs", ref("4") }, .{ "rhs", ref("2") } }),
        f.obj(&.{ .{ "index", f.n("7") }, .{ "tag", f.s("ret") }, .{ "payloadVisited", f.b(true) }, .{ "type", f.obj(&.{.{ "kind", f.s("noreturn") }}) }, .{ "operand", ref("6") } }),
    })),
});

pub fn controls() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    const decoded = try z.air.decode(&ctx, try f.load(ctx.allocator, bounded), .memory);
    try std.testing.expect(std.mem.indexOf(u8, decoded, "(.checkBounds (.local 1) (.local 5) (.slice (.local 0)))") != null);
    for ([_]f.Value{
        f.derive(&bounded, &.{f.set("/sourceValidity/slices", f.arr(&.{}))}),
        f.derive(&bounded, &.{f.set("/instructions/5/tag", f.s("add_wrap"))}),
        f.derive(&bounded, &.{f.set("/instructions/5/rhs", ref("1"))}),
        f.derive(&bounded, &.{f.set("/instructions/4/rhs", ref("2"))}),
        f.derive(&bounded, &.{f.set("/sourceValidity/slices/0/upperBound/original", ref("6"))}),
        f.derive(&bounded, &.{f.set("/sourceValidity/slices/0/upperBound", f.obj(&.{ .{ "kind", f.s("unboundedPointer") }, .{ "requiresMemoryValidity", f.b(true) } }))}),
    }) |input| try std.testing.expectError(error.InvalidInput, z.air.decode(&ctx, try f.load(ctx.allocator, input), .memory));
}

pub fn emitted(ctx: *z.common.Context) ![]const u8 {
    const raw = try f.load(ctx.allocator, bounded);
    return ctx.fmt(
        \\import Compiler.ZigAir.Captured
        \\open Compiler.ZigAir Compiler.ZigAir.MemoryAir Compiler.ZigAir.Memory
        \\def boundedSlice : Program := {s}
        \\{s}
        \\def heap : State := ⟨[(0, ⟨1, .array 5 (.scalar (.int false 8)), [], true, false⟩)], 1, 6⟩
        \\def view : Value := .slice (.slice false (.scalar (.int false 8))) ⟨0, 0⟩ 3
        \\example : boundedSlice.run [view, .scalar (.int false 64 2), .scalar (.int false 64 1)] heap =
        \\  (.ok (.slice (.slice false (.scalar (.int false 8))) ⟨0, 2⟩ 1), heap) := rfl
        \\example : boundedSlice.run [view, .scalar (.int false 64 2), .scalar (.int false 64 2)] heap =
        \\  (.error .sourceBounds, heap) := rfl
        \\
    , .{ try z.air.decode(ctx, raw, .memory), try z.certificate.declaration(ctx, raw, "boundedSlice", false) });
}
