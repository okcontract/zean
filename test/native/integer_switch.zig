// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");
const f = @import("fixtures.zig");
const shared = @import("cases/shared.zig");

const byte = f.obj(&.{ .{ "kind", f.s("int") }, .{ "signedness", f.s("signed") }, .{ "bits", f.n("8") } });
const never = f.obj(&.{.{ "kind", f.s("noreturn") }});

fn ref(comptime index: []const u8) f.Value {
    return f.obj(&.{ .{ "kind", f.s("instruction") }, .{ "index", f.n(index) } });
}

fn integer(comptime value: []const u8) f.Value {
    return f.obj(&.{ .{ "kind", f.s("constant") }, .{ "type", byte }, .{ "value", f.n(value) } });
}

fn jump(comptime index: []const u8, comptime operand: f.Value) f.Value {
    return f.obj(&.{
        .{ "index", f.n(index) },
        .{ "tag", f.s("br") },
        .{ "payloadVisited", f.b(true) },
        .{ "type", never },
        .{ "target", f.n("1") },
        .{ "operand", operand },
    });
}

const selector = f.derive(&shared.air_memory_program_2_input_13, &.{
    f.set("/signature/parameters", f.arr(&.{byte})),
    f.set("/signature/returnType", byte),
    f.set("/sourceValidity/slices", f.arr(&.{})),
    f.set("/sourceOperationTags", f.arr(&.{f.s("switch_block")})),
    f.set("/body", f.arr(&.{ f.n("0"), f.n("1"), f.n("6") })),
    f.set("/instructions", f.arr(&.{
        f.obj(&.{ .{ "index", f.n("0") }, .{ "tag", f.s("arg") }, .{ "payloadVisited", f.b(true) }, .{ "type", byte }, .{ "zirParameterIndex", f.n("0") } }),
        f.obj(&.{ .{ "index", f.n("1") }, .{ "tag", f.s("block") }, .{ "payloadVisited", f.b(true) }, .{ "type", byte }, .{ "body", f.arr(&.{f.n("2")}) } }),
        f.obj(&.{
            .{ "index", f.n("2") },
            .{ "tag", f.s("switch_br") },
            .{ "payloadVisited", f.b(true) },
            .{ "type", never },
            .{ "operand", ref("0") },
            .{ "cases", f.arr(&.{
                f.obj(&.{ .{ "ranges", f.arr(&.{f.arr(&.{ integer("-4"), integer("-2") })}) }, .{ "body", f.arr(&.{f.n("3")}) } }),
                f.obj(&.{ .{ "ranges", f.arr(&.{ f.arr(&.{ integer("0"), integer("0") }), f.arr(&.{ integer("2"), integer("3") }) }) }, .{ "body", f.arr(&.{f.n("4")}) } }),
            }) },
            .{ "elseBody", f.arr(&.{f.n("5")}) },
        }),
        jump("3", integer("7")),
        jump("4", integer("8")),
        jump("5", integer("9")),
        f.obj(&.{ .{ "index", f.n("6") }, .{ "tag", f.s("ret") }, .{ "payloadVisited", f.b(true) }, .{ "type", never }, .{ "operand", ref("1") } }),
    })),
});

const overlap = f.derive(&selector, &.{f.set("/instructions/2/cases/0/ranges/0/1/value", f.n("0"))});
const computed_arm = f.derive(&selector, &.{
    f.set("/instructions/2/cases/0/body", f.arr(&.{ f.n("3"), f.n("7") })),
    f.set("/instructions/3", f.obj(&.{
        .{ "index", f.n("3") }, .{ "tag", f.s("add") }, .{ "payloadVisited", f.b(true) },
        .{ "type", byte },      .{ "lhs", ref("0") },   .{ "rhs", integer("11") },
    })),
    f.add("/instructions/7", jump("7", ref("3"))),
});

pub fn controls() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    const raw = try f.load(ctx.allocator, selector);
    for ([_]z.air.Profile{ .scalar, .memory }) |profile| {
        const model = try z.air.decode(&ctx, raw, profile);
        try std.testing.expect(std.mem.indexOf(u8, model, "(.inRanges (.local 0) [((-4), (-2))])") != null);
        try std.testing.expect(std.mem.indexOf(u8, model, "(.inRanges (.local 0) [((0), (0)), ((2), (3))])") != null);
        // Each fallback starts the next case at the same indentation.
        try std.testing.expectEqual(@as(usize, 2), std.mem.count(u8, model, "\n        .branch (.local "));
        try std.testing.expectEqual(@as(usize, 2), std.mem.count(u8, model, ") (.jump 1 "));
    }
    const invalid = [_]f.Value{
        overlap,
        f.derive(&selector, &.{f.set("/instructions/2/cases/0/ranges/0/1/value", f.n("-5"))}),
        f.derive(&selector, &.{f.set("/instructions/2/cases/0/ranges/0/1/value", f.n("128"))}),
        f.derive(&selector, &.{f.set("/instructions/2/cases/0/ranges/0/1/type/signedness", f.s("unsigned"))}),
        f.derive(&selector, &.{f.set("/instructions/2/cases/1/body/0", f.n("3"))}),
        f.derive(&selector, &.{f.set("/instructions/2/elseBody", f.arr(&.{}))}),
        f.derive(&selector, &.{f.set("/instructions/2/operand/index", f.n("1"))}),
        f.derive(&selector, &.{f.set("/instructions/4/tag", f.s("future_opcode"))}),
    };
    for (invalid) |input| try std.testing.expectError(error.InvalidInput, z.air.decode(&ctx, try f.load(ctx.allocator, input), .scalar));
}

pub fn emitted(ctx: *z.common.Context) ![]const u8 {
    const raw = try f.load(ctx.allocator, selector);
    const computed = try f.load(ctx.allocator, computed_arm);
    return ctx.fmt(
        \\import Compiler.ZigAir.CapturedScalar
        \\open Compiler.ZigAir Compiler.ZigAir.Scalar
        \\def selectRange : Program :=
        \\{s}
        \\{s}
        \\def overlap : Captured.Raw := {s}
        \\example : CapturedScalar.decode overlap = none := rfl
        \\example : selectRange.run [.int true 8 (-4)] = .ok (.int true 8 7) := rfl
        \\example : selectRange.run [.int true 8 (-2)] = .ok (.int true 8 7) := rfl
        \\example : selectRange.run [.int true 8 0] = .ok (.int true 8 8) := rfl
        \\example : selectRange.run [.int true 8 3] = .ok (.int true 8 8) := rfl
        \\example : selectRange.run [.int true 8 1] = .ok (.int true 8 9) := rfl
        \\def computedRange : Program :=
        \\{s}
        \\{s}
        \\example : computedRange.run [.int true 8 (-2)] = .ok (.int true 8 9) := rfl
        \\example : (Prim.shiftLeft (.constant (.int false 8 128)) (.constant (.int false 3 1))).eval [] (fun _ => none) =
        \\  .ok (.int false 8 0) := rfl
        \\example : (Prim.shiftLeft (.constant (.int false 3 1)) (.constant (.int false 2 3))).eval [] (fun _ => none) =
        \\  .error .illegalBehavior := rfl
        \\
    , .{
        try z.air.decode(ctx, raw, .scalar),
        try z.certificate.scalarDeclaration(ctx, raw, "selectRange"),
        try z.certificate.lift(ctx, try f.load(ctx.allocator, overlap), 0),
        try z.air.decode(ctx, computed, .scalar),
        try z.certificate.scalarDeclaration(ctx, computed, "computedRange"),
    });
}
