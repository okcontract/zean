// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");
const f = @import("fixtures.zig");
const shared = @import("cases/shared.zig");

const unit = f.obj(&.{.{ "kind", f.s("void") }});
const never = f.obj(&.{.{ "kind", f.s("noreturn") }});
const word = f.obj(&.{ .{ "kind", f.s("int") }, .{ "signedness", f.s("unsigned") }, .{ "bits", f.n("64") } });
const literal = f.obj(&.{ .{ "kind", f.s("constant") }, .{ "type", word }, .{ "value", f.n("7") } });
const maximum = f.derive(&shared.air_memory_program_2_input_13, &.{
    f.set("/signature/parameters", f.arr(&.{})),
    f.set("/signature/returnType", word),
    f.set("/sourceValidity/slices", f.arr(&.{})),
    f.set("/body", f.arr(&.{ f.n("0"), f.n("1") })),
    f.set("/instructions", f.arr(&.{
        f.obj(&.{ .{ "index", f.n("0") }, .{ "tag", f.s("max") }, .{ "payloadVisited", f.b(true) }, .{ "type", word }, .{ "lhs", literal }, .{ "rhs", f.derive(&literal, &.{f.set("/value", f.n("9"))}) } }),
        f.obj(&.{ .{ "index", f.n("1") }, .{ "tag", f.s("ret") }, .{ "payloadVisited", f.b(true) }, .{ "type", never }, .{ "operand", f.obj(&.{ .{ "kind", f.s("instruction") }, .{ "index", f.n("0") } }) } }),
    })),
});
const minimum = f.derive(&maximum, &.{f.set("/instructions/0/tag", f.s("min"))});
const byte_slice = f.derive(&shared.pointer_21, &.{f.set("/flags/isConst", f.b(false))});
const byte_pointer = f.ref(&shared.pointer_17);
const copy = f.derive(&maximum, &.{
    f.set("/signature/parameters", f.arr(&.{ byte_slice, byte_pointer })),
    f.set("/signature/returnType", unit),
    f.set("/body", f.arr(&.{ f.n("0"), f.n("1"), f.n("2"), f.n("3") })),
    f.set("/instructions", f.arr(&.{
        f.obj(&.{ .{ "index", f.n("0") }, .{ "tag", f.s("arg") }, .{ "payloadVisited", f.b(true) }, .{ "type", byte_slice }, .{ "zirParameterIndex", f.n("0") } }),
        f.obj(&.{ .{ "index", f.n("1") }, .{ "tag", f.s("arg") }, .{ "payloadVisited", f.b(true) }, .{ "type", byte_pointer }, .{ "zirParameterIndex", f.n("1") } }),
        f.obj(&.{ .{ "index", f.n("2") }, .{ "tag", f.s("memcpy") }, .{ "payloadVisited", f.b(true) }, .{ "type", unit }, .{ "lhs", f.obj(&.{ .{ "kind", f.s("instruction") }, .{ "index", f.n("0") } }) }, .{ "rhs", f.obj(&.{ .{ "kind", f.s("instruction") }, .{ "index", f.n("1") } }) } }),
        f.obj(&.{ .{ "index", f.n("3") }, .{ "tag", f.s("ret") }, .{ "payloadVisited", f.b(true) }, .{ "type", never }, .{ "operand", f.obj(&.{.{ "kind", f.s("unit") }}) } }),
    })),
});

fn ref(index: []const u8) f.Value {
    return f.obj(&.{ .{ "kind", f.s("instruction") }, .{ "index", f.n(index) } });
}

fn unary(index: []const u8, tag: []const u8, ty: f.Value, operand: f.Value) f.Value {
    return f.obj(&.{ .{ "index", f.n(index) }, .{ "tag", f.s(tag) }, .{ "payloadVisited", f.b(true) }, .{ "type", ty }, .{ "operand", operand } });
}

const const_slice = f.ref(&shared.pointer_21);
const copy_slices = f.derive(&copy, &.{
    f.set("/sourceOperationTags", f.arr(&.{f.s("memcpy")})),
    f.add("/sourceValidity/copyLengthsAnchored", f.b(true)),
    f.set("/signature/parameters/1", const_slice),
    f.set("/body", f.arr(&.{ f.n("0"), f.n("1"), f.n("2"), f.n("3"), f.n("4"), f.n("5"), f.n("6") })),
    f.set("/instructions/1/type", const_slice),
    f.set("/instructions/2", unary("2", "slice_len", word, ref("0"))),
    f.set("/instructions/3", unary("3", "slice_len", word, ref("1"))),
    f.add("/instructions/4", unary("4", "slice_ptr", byte_pointer, ref("1"))),
    f.add("/instructions/5", f.obj(&.{
        .{ "index", f.n("5") }, .{ "tag", f.s("memcpy") }, .{ "payloadVisited", f.b(true) },                                                       .{ "type", unit },
        .{ "lhs", ref("0") },   .{ "rhs", ref("4") },      .{ "copyLengths", f.obj(&.{ .{ "destination", ref("2") }, .{ "source", ref("3") } }) },
    })),
    f.add("/instructions/6", unary("6", "ret", never, f.obj(&.{.{ "kind", f.s("unit") }}))),
});
const missing_lengths = f.derive(&copy_slices, &.{f.remove("/instructions/5/copyLengths")});
const pointer_source = f.derive(&copy_slices, &.{
    f.set("/instructions/5/copyLengths/source", f.obj(&.{ .{ "kind", f.s("manyPointer") }, .{ "operand", ref("4") } })),
});

pub fn controls() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    for ([_]f.Value{ maximum, minimum }) |input| {
        const raw = try f.load(ctx.allocator, input);
        const output = try z.air.decode(&ctx, raw, .memory);
        try std.testing.expect(std.mem.indexOf(u8, output, "(.extremum ") != null);
    }
    const invalid = [_]f.Value{
        f.derive(&maximum, &.{f.set("/instructions/0/rhs/type/bits", f.n("32"))}),
        f.derive(&maximum, &.{f.set("/instructions/0/rhs/type/signedness", f.s("signed"))}),
        f.derive(&maximum, &.{f.set("/instructions/0/type", unit)}),
        f.derive(&maximum, &.{f.set("/instructions/0/type/kind", f.s("float"))}),
    };
    for (invalid) |input| try std.testing.expectError(error.InvalidInput, z.air.decode(&ctx, try f.load(ctx.allocator, input), .memory));
    const copied = try z.air.decode(&ctx, try f.load(ctx.allocator, copy), .memory);
    try std.testing.expect(std.mem.indexOf(u8, copied, "(.copyBytes (.local 0) (.local 1))") != null);
    for ([_]f.Value{
        f.derive(&copy, &.{f.set("/instructions/2/type", word)}),
        f.derive(&copy, &.{f.set("/instructions/2/rhs/index", f.n("0"))}),
        f.derive(&copy, &.{f.set("/instructions/2/lhs/index", f.n("1"))}),
        f.derive(&copy, &.{f.set("/instructions/2/tag", f.s("memmove"))}),
    }) |input| try std.testing.expectError(error.InvalidInput, z.air.decode(&ctx, try f.load(ctx.allocator, input), .memory));
    const guarded = try z.air.decode(&ctx, try f.load(ctx.allocator, copy_slices), .memory);
    const guard = std.mem.indexOf(u8, guarded, "(.checkCopyLengths (.local 2) (.local 3))").?;
    const transfer = std.mem.indexOf(u8, guarded, "(.copyBytes (.local 0) (.local 4))").?;
    try std.testing.expect(guard < transfer);
    const unguarded = try z.air.decode(&ctx, try f.load(ctx.allocator, pointer_source), .memory);
    try std.testing.expect(std.mem.indexOf(u8, unguarded, "checkCopyLengths") == null);
    for ([_]f.Value{
        missing_lengths,
        f.derive(&copy_slices, &.{f.remove("/instructions/5/copyLengths/source")}),
        f.derive(&copy_slices, &.{f.set("/instructions/5/copyLengths/source/index", f.n("6"))}),
        f.derive(&copy_slices, &.{f.set("/instructions/5/copyLengths/source/index", f.n("2"))}),
        f.derive(&copy_slices, &.{f.set("/instructions/5/copyLengths/destination/index", f.n("0"))}),
        f.derive(&copy_slices, &.{f.set("/instructions/5/copyLengths/source", .null)}),
        f.derive(&pointer_source, &.{f.set("/instructions/5/copyLengths/source/operand/index", f.n("1"))}),
        f.derive(&copy_slices, &.{f.remove("/sourceValidity/copyLengthsAnchored")}),
        f.derive(&copy_slices, &.{f.set("/sourceValidity/copyLengthsAnchored", f.b(false))}),
    }) |input| try std.testing.expectError(error.InvalidInput, z.air.decode(&ctx, try f.load(ctx.allocator, input), .memory));
}

pub fn lengthsEmitted(ctx: *z.common.Context) ![]const u8 {
    const raw = try f.load(ctx.allocator, copy_slices);
    return ctx.fmt(
        \\import Compiler.ZigAir.Captured
        \\open Compiler.ZigAir Compiler.ZigAir.Memory Compiler.ZigAir.MemoryAir
        \\def copySlices : Program := {s}
        \\{s}
        \\def missingLengths : Captured.Raw := {s}
        \\example : Captured.decode false missingLengths = none := rfl
        \\def byte : Ty := .scalar (.int false 8)
        \\def initial : State :=
        \\  ⟨[(1, ⟨3, .array 2 byte, [(0, .scalar (.int false 8 42)), (1, .scalar (.int false 8 99))], false, false⟩),
        \\    (0, ⟨1, .array 2 byte, [], true, false⟩)], 2, 5⟩
        \\def dst : Value := .slice (.slice true byte) ⟨0, 0⟩ 2
        \\def src (length : Nat) : Value := .slice (.slice false byte) ⟨1, 0⟩ length
        \\example : (copySlices.run [dst, src 2] initial).1 = .ok (.scalar .unit) := rfl
        \\example : load (copySlices.run [dst, src 2] initial).2
        \\    (.pointer (.pointer false false byte) ⟨0, 1⟩) = .ok (.scalar (.int false 8 99)) := rfl
        \\example : copySlices.run [dst, src 1] initial = (.error .sourceBounds, initial) := rfl
        \\
    , .{ try z.air.decode(ctx, raw, .memory), try z.certificate.declaration(ctx, raw, "copySlices", false), try z.certificate.lift(ctx, try f.load(ctx.allocator, missing_lengths), 0) });
}

pub fn emitted(ctx: *z.common.Context) ![]const u8 {
    return ctx.fmt(
        \\import Compiler.ZigAir.MemoryAir
        \\open Compiler.ZigAir.MemoryAir
        \\def maximum : Program := {s}
        \\def minimum : Program := {s}
        \\example : maximum.run [] {{}} = (.ok (.scalar (.int false 64 9)), {{}}) := rfl
        \\example : minimum.run [] {{}} = (.ok (.scalar (.int false 64 7)), {{}}) := rfl
        \\
    , .{ try z.air.decode(ctx, try f.load(ctx.allocator, maximum), .memory), try z.air.decode(ctx, try f.load(ctx.allocator, minimum), .memory) });
}
