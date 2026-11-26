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
const division = f.derive(&maximum, &.{
    f.set("/instructions/0/tag", f.s("div_trunc")),
    f.set("/instructions/0/rhs/value", f.n("2")),
});
const division_by_zero = f.derive(&division, &.{f.set("/instructions/0/rhs/value", f.n("0"))});
const signed_divisor = f.derive(&division, &.{f.set("/instructions/0/rhs/type/signedness", f.s("signed"))});
const wrong_divisor_width = f.derive(&division, &.{f.set("/instructions/0/rhs/type/bits", f.n("32"))});
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
const writable_pointer = f.derive(&byte_pointer, &.{f.set("/flags/isConst", f.b(false))});
const borrowed_destination = f.derive(&copy_slices, &.{
    f.set("/signature/parameters", f.arr(&.{ writable_pointer, byte_slice })),
    f.set("/instructions/0/type", writable_pointer),
    f.set("/instructions/1/type", byte_slice),
    f.set("/instructions/2/operand", ref("1")),
    f.set("/instructions/3", f.obj(&.{
        .{ "index", f.n("3") },  .{ "tag", f.s("slice") }, .{ "payloadVisited", f.b(true) },
        .{ "type", byte_slice }, .{ "lhs", ref("0") },     .{ "rhs", ref("2") },
    })),
    f.set("/instructions/4/type", writable_pointer),
    f.set("/instructions/5/lhs", ref("3")),
    f.set("/instructions/5/copyLengths/destination", f.obj(&.{ .{ "kind", f.s("manyPointer") }, .{ "operand", ref("0") } })),
    f.set("/instructions/5/copyLengths/source", ref("2")),
});
const changed_pointer = f.derive(&borrowed_destination, &.{f.set("/instructions/5/copyLengths/destination/operand", ref("4"))});
const changed_length = f.derive(&borrowed_destination, &.{f.set("/instructions/3/rhs", f.derive(&literal, &.{f.set("/value", f.n("2"))}))});

fn byteArrayPointer(comptime count: []const u8) f.Value {
    const layout = f.obj(&.{ .{ "kind", f.s("abi") }, .{ "bytes", f.n(count) }, .{ "alignment", f.n("1") } });
    const byte = f.derive(&word, &.{f.set("/bits", f.n("8"))});
    return f.derive(&writable_pointer, &.{
        f.set("/flags/size", f.s("one")),
        f.set("/child", f.obj(&.{ .{ "kind", f.s("array") }, .{ "length", f.n(count) }, .{ "child", byte }, .{ "layout", layout }, .{ "sentinel", .null } })),
        f.set("/pointeeLayout", layout),
    });
}

const one_byte_array = byteArrayPointer("1");
const borrowed_array = f.derive(&copy, &.{
    f.set("/sourceOperationTags", f.arr(&.{f.s("memcpy")})),
    f.add("/sourceValidity/copyLengthsAnchored", f.b(true)),
    f.set("/signature/parameters", f.arr(&.{ writable_pointer, one_byte_array })),
    f.set("/instructions/0/type", writable_pointer),
    f.set("/instructions/1/type", one_byte_array),
    f.set("/instructions/2", unary("2", "ptr_cast", one_byte_array, ref("0"))),
    f.set("/instructions/3", f.obj(&.{
        .{ "index", f.n("3") }, .{ "tag", f.s("memcpy") }, .{ "payloadVisited", f.b(true) }, .{ "type", unit },
        .{ "lhs", ref("2") },   .{ "rhs", ref("1") },
        .{ "copyLengths", f.obj(&.{
            .{ "destination", f.obj(&.{ .{ "kind", f.s("manyPointer") }, .{ "operand", ref("0") } }) },
            .{ "source", f.derive(&literal, &.{f.set("/value", f.n("1"))}) },
        }) },
    })),
    f.add("/instructions/4", unary("4", "ret", never, f.obj(&.{.{ "kind", f.s("unit") }}))),
    f.add("/body/4", f.n("4")),
});
const changed_extent = f.derive(&borrowed_array, &.{f.set("/instructions/2/type", byteArrayPointer("2"))});
const move_slices = f.derive(&copy_slices, &.{
    f.set("/sourceOperationTags/0", f.s("memmove")),
    f.set("/instructions/5/tag", f.s("memmove")),
});
const undefined_byte = f.obj(&.{
    .{ "kind", f.s("undefined") },
    .{ "type", f.obj(&.{ .{ "kind", f.s("int") }, .{ "signedness", f.s("unsigned") }, .{ "bits", f.n("8") } }) },
});
const undefined_fill = f.derive(&copy, &.{
    f.set("/signature/parameters", f.arr(&.{byte_slice})),
    f.set("/body", f.arr(&.{ f.n("0"), f.n("1"), f.n("2") })),
    f.remove("/instructions/1"),
    f.set("/instructions/1/index", f.n("1")),
    f.set("/instructions/1/tag", f.s("memset")),
    f.set("/instructions/1/rhs", undefined_byte),
    f.set("/instructions/2/index", f.n("2")),
});
const signed_fill = f.derive(&undefined_fill, &.{f.set("/instructions/1/rhs/type/signedness", f.s("signed"))});
const readonly_fill = f.derive(&undefined_fill, &.{
    f.set("/signature/parameters/0", const_slice),
    f.set("/instructions/0/type", const_slice),
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
    for ([_]z.air.Profile{ .scalar, .memory }) |profile| {
        const decoded = try z.air.decode(&ctx, try f.load(ctx.allocator, division), profile);
        try std.testing.expect(std.mem.indexOf(u8, decoded, "(.divideUnsigned ") != null);
        for ([_]f.Value{ signed_divisor, wrong_divisor_width }) |input|
            try std.testing.expectError(error.InvalidInput, z.air.decode(&ctx, try f.load(ctx.allocator, input), profile));
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
    _ = try z.air.decode(&ctx, try f.load(ctx.allocator, borrowed_destination), .memory);
    _ = try z.air.decode(&ctx, try f.load(ctx.allocator, borrowed_array), .memory);
    for ([_]f.Value{
        changed_extent,
        changed_pointer,
        changed_length,
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
    const moved = try z.air.decode(&ctx, try f.load(ctx.allocator, move_slices), .memory);
    try std.testing.expect(std.mem.indexOf(u8, moved, "(.moveBytes (.local 0) (.local 4))") != null);
    for ([_]f.Value{
        f.derive(&move_slices, &.{f.remove("/instructions/5/copyLengths")}),
        f.derive(&move_slices, &.{f.set("/instructions/5/type", word)}),
        f.derive(&move_slices, &.{f.set("/instructions/5/rhs/index", f.n("0"))}),
    }) |input| try std.testing.expectError(error.InvalidInput, z.air.decode(&ctx, try f.load(ctx.allocator, input), .memory));
    const invalidated = try z.air.decode(&ctx, try f.load(ctx.allocator, undefined_fill), .memory);
    try std.testing.expect(std.mem.indexOf(u8, invalidated, "(.invalidateSlice (.local 0))") != null);
    for ([_]f.Value{
        signed_fill,
        readonly_fill,
        f.derive(&undefined_fill, &.{f.set("/instructions/1/rhs", literal)}),
        f.derive(&undefined_fill, &.{f.set("/instructions/1/type", word)}),
        f.derive(&undefined_fill, &.{f.set("/instructions/1/tag", f.s("memset_safe"))}),
    }) |input| try std.testing.expectError(error.InvalidInput, z.air.decode(&ctx, try f.load(ctx.allocator, input), .memory));
}

pub fn invalidationEmitted(ctx: *z.common.Context) ![]const u8 {
    const raw = try f.load(ctx.allocator, undefined_fill);
    return ctx.fmt(
        \\import Compiler.ZigAir.Captured
        \\open Compiler.ZigAir Compiler.ZigAir.Memory Compiler.ZigAir.MemoryAir
        \\def fill : Program :=
        \\{s}
        \\{s}
        \\def wrongType : Captured.Raw := {s}
        \\def readOnly : Captured.Raw := {s}
        \\example : Captured.decode false wrongType = none := rfl
        \\example : Captured.decode false readOnly = none := rfl
        \\def byte : Ty := .scalar (.int false 8)
        \\def item (n : Nat) : Value := .scalar (.int false 8 n)
        \\def initial : State :=
        \\  ⟨[(0, ⟨1, .array 3 byte, [(0, item 1), (1, item 2), (2, item 3)], true, false⟩)], 1, 4⟩
        \\def target (offset length : Nat) : Value := .slice (.slice true byte) ⟨0, offset⟩ length
        \\def observations (state : State) :=
        \\  [0, 1, 2].map (fun i => load state (.pointer (.pointer false false byte) ⟨0, i⟩))
        \\def observes (offset length : Nat) :=
        \\  let reached := fill.run [target offset length] initial
        \\  (reached.1, observations reached.2, reached.2.nextId, reached.2.nextAddress)
        \\example : observes 1 1 =
        \\    (.ok (.scalar .unit), [.ok (item 1), .error .uninitialized, .ok (item 3)], 1, 4) := rfl
        \\example : fill.run [target 3 0] initial = (.ok (.scalar .unit), initial) := rfl
        \\example : observes 2 2 =
        \\    (.error .memoryValidity, [.ok (item 1), .ok (item 2), .error .uninitialized], 1, 4) := rfl
        \\
    , .{
        try z.air.decode(ctx, raw, .memory),
        try z.certificate.declaration(ctx, raw, "fill", false),
        try z.certificate.lift(ctx, try f.load(ctx.allocator, signed_fill), 0),
        try z.certificate.lift(ctx, try f.load(ctx.allocator, readonly_fill), 0),
    });
}

pub fn nativeMoves() !void {
    var bytes = "abcde".*;
    @memmove(bytes[1..], bytes[0..4]);
    try std.testing.expectEqualStrings("aabcd", &bytes);
    bytes = "abcde".*;
    @memmove(bytes[0..4], bytes[1..]);
    try std.testing.expectEqualStrings("bcdee", &bytes);
    @memmove(&bytes, &bytes);
    try std.testing.expectEqualStrings("bcdee", &bytes);
}

pub fn moveEmitted(ctx: *z.common.Context) ![]const u8 {
    const raw = try f.load(ctx.allocator, move_slices);
    const copy_raw = try f.load(ctx.allocator, copy_slices);
    return ctx.fmt(
        \\import Compiler.ZigAir.Captured
        \\open Compiler.ZigAir Compiler.ZigAir.Memory Compiler.ZigAir.MemoryAir
        \\def move : Program :=
        \\{s}
        \\{s}
        \\def copy : Program :=
        \\{s}
        \\def byte : Ty := .scalar (.int false 8)
        \\def value (n : Nat) : Value := .scalar (.int false 8 n)
        \\def before : State :=
        \\  ⟨[(0, ⟨1, .array 5 byte, [(0, value 97), (1, value 98), (2, value 99),
        \\    (3, value 100), (4, value 101)], true, false⟩)], 1, 6⟩
        \\def dest (offset len : Nat) : Value := .slice (.slice true byte) ⟨0, offset⟩ len
        \\def src (offset len : Nat) : Value := .slice (.slice false byte) ⟨0, offset⟩ len
        \\def atByte (state : State) (index : Nat) : Except Fault Value :=
        \\  load state (.pointer (.pointer false false byte) ⟨0, index⟩)
        \\def bytes (state : State) : List (Except Fault Value) := (List.range 5).map (atByte state)
        \\def observes (target source : Value) (initial : State) :=
        \\  let after := move.run [target, source] initial
        \\  (after.1, bytes after.2)
        \\set_option maxHeartbeats 1000000
        \\example : observes (dest 1 4) (src 0 4) before =
        \\  (.ok (.scalar .unit), [97, 97, 98, 99, 100].map (fun n => .ok (value n))) := rfl
        \\example : observes (dest 0 4) (src 1 4) before =
        \\  (.ok (.scalar .unit), [98, 99, 100, 101, 101].map (fun n => .ok (value n))) := rfl
        \\example : observes (dest 0 5) (src 0 5) before = (.ok (.scalar .unit), bytes before) := rfl
        \\example : move.run [dest 1 0, src 0 0] before = (.ok (.scalar .unit), before) := rfl
        \\example : move.run [dest 1 4, src 0 3] before = (.error .sourceBounds, before) := rfl
        \\example : copy.run [dest 1 4, src 0 4] before = (.error .memoryValidity, before) := rfl
        \\def holes : State :=
        \\  ⟨[(0, ⟨1, .array 5 byte, [(0, value 97), (2, value 99),
        \\    (3, value 100), (4, value 101)], true, false⟩)], 1, 6⟩
        \\example : observes (dest 1 4) (src 0 4) holes =
        \\  (.ok (.scalar .unit), [.ok (value 97), .ok (value 97), .error .uninitialized,
        \\    .ok (value 99), .ok (value 100)]) := rfl
        \\example : observes (dest 4 2) (src 0 2) before =
        \\  (.error .memoryValidity, [97, 98, 99, 100, 97].map (fun n => .ok (value n))) := rfl
        \\
    , .{ try z.air.decode(ctx, raw, .memory), try z.certificate.declaration(ctx, raw, "move", false), try z.air.decode(ctx, copy_raw, .memory) });
}

pub fn lengthsEmitted(ctx: *z.common.Context) ![]const u8 {
    const raw = try f.load(ctx.allocator, copy_slices);
    const borrowed = try f.load(ctx.allocator, borrowed_destination);
    return ctx.fmt(
        \\import Compiler.ZigAir.Captured
        \\import Compiler.ZigAir.AggregateAir
        \\open Compiler.ZigAir Compiler.ZigAir.Memory Compiler.ZigAir.MemoryAir
        \\def copySlices : Program :=
        \\{s}
        \\{s}
        \\def borrowedCopy : Program :=
        \\{s}
        \\{s}
        \\example : Captured.decode false {s} = none := rfl
        \\example : Captured.decode false {s} = none := rfl
        \\example : (Captured.decode false {s}).isSome = true := rfl
        \\example : Captured.decode false {s} = none := rfl
        \\def aggregateCopy : AggregateAir.Program :=
        \\{s}
        \\def aggregateMove : AggregateAir.Program :=
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
        \\example : aggregateCopy.run [.value dst, .value (src 1)] initial = (.error .sourceBounds, initial) := rfl
        \\example : aggregateMove.run [.value dst, .value (src 1)] initial = (.error .sourceBounds, initial) := rfl
        \\
    , .{
        try z.air.decode(ctx, raw, .memory),
        try z.certificate.declaration(ctx, raw, "copySlices", false),
        try z.air.decode(ctx, borrowed, .memory),
        try z.certificate.declaration(ctx, borrowed, "borrowedCopy", false),
        try z.certificate.lift(ctx, try f.load(ctx.allocator, changed_pointer), 0),
        try z.certificate.lift(ctx, try f.load(ctx.allocator, changed_length), 0),
        try z.certificate.lift(ctx, try f.load(ctx.allocator, borrowed_array), 0),
        try z.certificate.lift(ctx, try f.load(ctx.allocator, changed_extent), 0),
        try z.air.decode(ctx, raw, .aggregate),
        try z.air.decode(ctx, try f.load(ctx.allocator, move_slices), .aggregate),
        try z.certificate.lift(ctx, try f.load(ctx.allocator, missing_lengths), 0),
    });
}

pub fn divisionEmitted(ctx: *z.common.Context) ![]const u8 {
    const raw = try f.load(ctx.allocator, division);
    const zero = try f.load(ctx.allocator, division_by_zero);
    return ctx.fmt(
        \\import Compiler.ZigAir.CapturedScalar
        \\open Compiler.ZigAir
        \\def quotient : Scalar.Program :=
        \\{s}
        \\{s}
        \\def quotientMemory : MemoryAir.Program :=
        \\{s}
        \\{s}
        \\def zeroDivisor : Scalar.Program :=
        \\{s}
        \\example : quotient.run [] = .ok (.int false 64 3) := rfl
        \\example : quotientMemory.run [] {{}} = (.ok (.scalar (.int false 64 3)), {{}}) := rfl
        \\example : zeroDivisor.run [] = .error .illegalBehavior := rfl
        \\example : CapturedScalar.decode {s} = none := rfl
        \\example : Captured.decode false {s} = none := rfl
        \\
    , .{
        try z.air.decode(ctx, raw, .scalar),
        try z.certificate.scalarDeclaration(ctx, raw, "quotient"),
        try z.air.decode(ctx, raw, .memory),
        try z.certificate.declaration(ctx, raw, "quotientMemory", false),
        try z.air.decode(ctx, zero, .scalar),
        try z.certificate.lift(ctx, try f.load(ctx.allocator, signed_divisor), 0),
        try z.certificate.lift(ctx, try f.load(ctx.allocator, wrong_divisor_width), 0),
    });
}

pub fn emitted(ctx: *z.common.Context) ![]const u8 {
    return ctx.fmt(
        \\import Compiler.ZigAir.MemoryAir
        \\open Compiler.ZigAir.MemoryAir
        \\def maximum : Program :=
        \\{s}
        \\def minimum : Program :=
        \\{s}
        \\example : maximum.run [] {{}} = (.ok (.scalar (.int false 64 9)), {{}}) := rfl
        \\example : minimum.run [] {{}} = (.ok (.scalar (.int false 64 7)), {{}}) := rfl
        \\
    , .{ try z.air.decode(ctx, try f.load(ctx.allocator, maximum), .memory), try z.air.decode(ctx, try f.load(ctx.allocator, minimum), .memory) });
}
