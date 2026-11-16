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
