// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");
const f = @import("fixtures.zig");
const shared = @import("cases/shared.zig");

const boolean = f.obj(&.{.{ "kind", f.s("bool") }});
const never = f.obj(&.{.{ "kind", f.s("noreturn") }});
const mode = f.obj(&.{
    .{ "kind", f.s("finiteEnum") },
    .{ "identity", f.obj(&.{
        .{ "name", f.s("fixture.Mode") },
        .{ "sourceFile", f.s("fixture.zig") },
        .{ "sourceSha256", f.s("0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef") },
    }) },
    .{ "backingType", f.obj(&.{ .{ "kind", f.s("int") }, .{ "bits", f.n("2") }, .{ "signedness", f.s("unsigned") } }) },
    .{ "layout", f.obj(&.{ .{ "kind", f.s("abi") }, .{ "bytes", f.n("1") }, .{ "alignment", f.n("1") } }) },
    .{ "nonexhaustive", f.b(false) },
    .{ "fields", f.arr(&.{
        f.obj(&.{ .{ "index", f.n("0") }, .{ "name", f.s("alpha") }, .{ "value", f.n("1") } }),
        f.obj(&.{ .{ "index", f.n("1") }, .{ "name", f.s("beta") }, .{ "value", f.n("3") } }),
    }) },
});

fn ref(index: []const u8) f.Value {
    return f.obj(&.{ .{ "kind", f.s("instruction") }, .{ "index", f.n(index) } });
}

fn tag(value: []const u8) f.Value {
    return f.obj(&.{ .{ "kind", f.s("enumTag") }, .{ "type", mode }, .{ "value", f.n(value) } });
}

fn boolConstant(value: []const u8) f.Value {
    return f.obj(&.{ .{ "kind", f.s("constant") }, .{ "type", boolean }, .{ "value", f.n(value) } });
}

fn returns(index: []const u8, operand: f.Value) f.Value {
    return f.obj(&.{
        .{ "index", f.n(index) }, .{ "tag", f.s("ret") },  .{ "payloadVisited", f.b(true) },
        .{ "type", never },       .{ "operand", operand },
    });
}

const argument = f.obj(&.{
    .{ "index", f.n("0") }, .{ "tag", f.s("arg") },             .{ "payloadVisited", f.b(true) },
    .{ "type", mode },      .{ "zirParameterIndex", f.n("0") },
});
const compare = f.derive(&shared.air_memory_program_2_input_13, &.{
    f.set("/signature/parameters", f.arr(&.{mode})),
    f.set("/signature/returnType", boolean),
    f.set("/sourceOperationTags", f.arr(&.{})),
    f.set("/sourceValidity/slices", f.arr(&.{})),
    f.set("/body", f.arr(&.{ f.n("0"), f.n("1"), f.n("2") })),
    f.set("/instructions", f.arr(&.{ argument, f.obj(&.{
        .{ "index", f.n("1") }, .{ "tag", f.s("cmp_eq") }, .{ "payloadVisited", f.b(true) },
        .{ "type", boolean },   .{ "lhs", ref("0") },      .{ "rhs", tag("3") },
    }), returns("2", ref("1")) })),
});

fn arm(value: []const u8, destination: []const u8) f.Value {
    return f.obj(&.{
        .{ "ranges", f.arr(&.{f.arr(&.{ tag(value), tag(value) })}) },
        .{ "body", f.arr(&.{f.n(destination)}) },
    });
}

const choose = f.derive(&compare, &.{
    f.set("/body", f.arr(&.{ f.n("0"), f.n("1") })),
    f.set("/instructions", f.arr(&.{ argument, f.obj(&.{
        .{ "index", f.n("1") },               .{ "tag", f.s("switch_br") }, .{ "payloadVisited", f.b(true) },
        .{ "type", never },                   .{ "operand", ref("0") },     .{ "cases", f.arr(&.{arm("3", "2")}) },
        .{ "elseBody", f.arr(&.{f.n("3")}) },
    }), returns("2", boolConstant("1")), returns("3", boolConstant("0")) })),
});

const hole = f.derive(&compare, &.{f.set("/instructions/1/rhs/value", f.n("2"))});
const foreign = f.derive(&compare, &.{f.set("/instructions/1/rhs/type/identity/name", f.s("fixture.Other"))});
const range = f.derive(&choose, &.{f.set("/instructions/1/cases/0/ranges/0/0", tag("1"))});
const exhaustive = f.derive(&choose, &.{
    f.set("/instructions/1/elseBody", f.arr(&.{})),
    f.add("/instructions/1/cases/1", arm("1", "3")),
});
const incomplete = f.derive(&choose, &.{
    f.set("/instructions/1/elseBody", f.arr(&.{})),
    f.remove("/instructions/3"),
});
const repeated = f.derive(&exhaustive, &.{f.set("/instructions/1/cases/1", arm("3", "3"))});

pub fn controls() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    const compared = try z.air.decode(&ctx, try f.load(ctx.allocator, compare), .memory);
    const chosen = try z.air.decode(&ctx, try f.load(ctx.allocator, choose), .memory);
    const full = try z.air.decode(&ctx, try f.load(ctx.allocator, exhaustive), .memory);
    try std.testing.expect(std.mem.indexOf(u8, compared, "(.compareEnum true ") != null);
    try std.testing.expect(std.mem.indexOf(u8, chosen, "(.enumInTags (.local 0) [3])") != null);
    try std.testing.expect(std.mem.indexOf(u8, full, ".unreachable") != null);
    for ([_]f.Value{
        hole,
        foreign,
        range,
        incomplete,
        repeated,
        f.derive(&compare, &.{f.set("/instructions/1/tag", f.s("cmp_lt"))}),
        f.derive(&compare, &.{f.set("/instructions/1/rhs/kind", f.s("constant"))}),
        f.derive(&compare, &.{f.set("/signature/parameters/0/fields/1/value", f.n("1"))}),
        f.derive(&compare, &.{f.set("/signature/parameters/0/layout/bytes", f.n("2"))}),
    }) |mutated| try std.testing.expectError(error.InvalidInput, z.air.decode(&ctx, try f.load(ctx.allocator, mutated), .memory));
}

pub fn emitted(ctx: *z.common.Context) ![]const u8 {
    const comparison = try f.load(ctx.allocator, compare);
    const selection = try f.load(ctx.allocator, choose);
    const complete = try f.load(ctx.allocator, exhaustive);
    return ctx.fmt(
        \\import Compiler.ZigAir.Captured
        \\open Compiler.ZigAir Compiler.ZigAir.MemoryAir
        \\namespace EnumControls
        \\def compare : Program :=
        \\{s}
        \\{s}
        \\def choose : Program :=
        \\{s}
        \\{s}
        \\def full : Program :=
        \\{s}
        \\{s}
        \\def hole : Captured.Raw := {s}
        \\def foreign : Captured.Raw := {s}
        \\def range : Captured.Raw := {s}
        \\def incomplete : Captured.Raw := {s}
        \\def repeated : Captured.Raw := {s}
        \\def declaration : Scalar.EnumDecl := ⟨"fixture.Mode", "fixture.zig", "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef", 2, [("alpha", 1), ("beta", 3)]⟩
        \\example : compare.run [.scalar (.enumTag declaration 1)] {{}} = (.ok (.scalar (.bool false)), {{}}) := rfl
        \\example : compare.run [.scalar (.enumTag declaration 3)] {{}} = (.ok (.scalar (.bool true)), {{}}) := rfl
        \\example : choose.run [.scalar (.enumTag declaration 1)] {{}} = (.ok (.scalar (.bool false)), {{}}) := rfl
        \\example : choose.run [.scalar (.enumTag declaration 3)] {{}} = (.ok (.scalar (.bool true)), {{}}) := rfl
        \\example : choose.run [.scalar (.enumTag declaration 2)] {{}} = (.error .malformed, {{}}) := rfl
        \\example : full.run [.scalar (.enumTag declaration 1)] {{}} = (.ok (.scalar (.bool false)), {{}}) := rfl
        \\example : full.run [.scalar (.enumTag declaration 3)] {{}} = (.ok (.scalar (.bool true)), {{}}) := rfl
        \\example : Captured.decode false hole = none := rfl
        \\example : Captured.decode false foreign = none := rfl
        \\example : Captured.decode false range = none := rfl
        \\example : Captured.decode false incomplete = none := rfl
        \\example : Captured.decode false repeated = none := rfl
        \\end EnumControls
        \\
    , .{
        try z.air.decode(ctx, comparison, .memory),                          try z.certificate.declaration(ctx, comparison, "compare", false),
        try z.air.decode(ctx, selection, .memory),                           try z.certificate.declaration(ctx, selection, "choose", false),
        try z.air.decode(ctx, complete, .memory),                            try z.certificate.declaration(ctx, complete, "full", false),
        try z.certificate.lift(ctx, try f.load(ctx.allocator, hole), 0),     try z.certificate.lift(ctx, try f.load(ctx.allocator, foreign), 0),
        try z.certificate.lift(ctx, try f.load(ctx.allocator, range), 0),    try z.certificate.lift(ctx, try f.load(ctx.allocator, incomplete), 0),
        try z.certificate.lift(ctx, try f.load(ctx.allocator, repeated), 0),
    });
}
