// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");
const f = @import("fixtures.zig");
const shared = @import("cases/shared.zig");

const errors = f.obj(&.{ .{ "kind", f.s("errorSet") }, .{ "names", f.arr(&.{f.s("OutOfMemory")}) } });
const result = f.obj(&.{ .{ "kind", f.s("errorStatus") }, .{ "errors", errors } });
const success = f.obj(&.{ .{ "kind", f.s("errorStatus") }, .{ "type", result }, .{ "name", .null } });
const unit = f.obj(&.{.{ "kind", f.s("void") }});
const never = f.obj(&.{.{ "kind", f.s("noreturn") }});

fn ref(index: []const u8) f.Value {
    return f.obj(&.{ .{ "kind", f.s("instruction") }, .{ "index", f.n(index) } });
}

fn operation(index: []const u8, tag: []const u8, ty: f.Value, operand: f.Value) f.Value {
    return f.obj(&.{
        .{ "index", f.n(index) }, .{ "tag", f.s(tag) },    .{ "payloadVisited", f.b(true) },
        .{ "type", ty },          .{ "operand", operand },
    });
}

const forward = f.derive(&shared.air_memory_program_2_input_13, &.{
    f.set("/signature/parameters", f.arr(&.{result})),
    f.set("/signature/returnType", result),
    f.set("/sourceOperationTags", f.arr(&.{})),
    f.set("/sourceValidity/slices", f.arr(&.{})),
    f.set("/body", f.arr(&.{ f.n("0"), f.n("1"), f.n("5") })),
    f.set("/instructions", f.arr(&.{
        f.obj(&.{
            .{ "index", f.n("0") }, .{ "tag", f.s("arg") },             .{ "payloadVisited", f.b(true) },
            .{ "type", result },    .{ "zirParameterIndex", f.n("0") },
        }),
        f.obj(&.{
            .{ "index", f.n("1") }, .{ "tag", f.s("try") },   .{ "payloadVisited", f.b(true) },
            .{ "type", unit },      .{ "operand", ref("0") }, .{ "errorBody", f.arr(&.{ f.n("2"), f.n("3"), f.n("4") }) },
        }),
        operation("2", "unwrap_errunion_err", errors, ref("0")),
        operation("3", "wrap_errunion_err", result, ref("2")),
        operation("4", "ret", never, ref("3")),
        operation("5", "ret", never, success),
    })),
});

const block = f.derive(&forward, &.{
    f.set("/body", f.arr(&.{ f.n("0"), f.n("6"), f.n("7") })),
    f.add("/instructions/6", f.obj(&.{
        .{ "index", f.n("6") }, .{ "tag", f.s("block") },                     .{ "payloadVisited", f.b(true) },
        .{ "type", result },    .{ "body", f.arr(&.{ f.n("1"), f.n("5") }) },
    })),
    f.add("/instructions/7", operation("7", "ret", never, ref("6"))),
});

const escapes = f.derive(&block, &.{
    f.set("/instructions/4/tag", f.s("br")),
    f.add("/instructions/4/target", f.n("6")),
});
const wrong_name = f.derive(&forward, &.{f.set("/instructions/5/operand/name", f.s("IoFailure"))});

pub fn controls() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    const program = try z.air.decode(&ctx, try f.load(ctx.allocator, forward), .memory);
    try std.testing.expect(std.mem.indexOf(u8, program, "(.testError false (.local 0))") != null);
    try std.testing.expect(std.mem.indexOf(u8, program, "(.unwrapError true (.local 0))") != null);
    const cold = f.derive(&forward, &.{f.set("/instructions/1/tag", f.s("try_cold"))});
    try std.testing.expectEqualStrings(program, try z.air.decode(&ctx, try f.load(ctx.allocator, cold), .memory));
    _ = try z.air.decode(&ctx, try f.load(ctx.allocator, block), .memory);
    for ([_]f.Value{
        escapes,
        wrong_name,
        f.derive(&forward, &.{f.set("/instructions/1/type", f.obj(&.{.{ "kind", f.s("bool") }}))}),
        f.derive(&forward, &.{f.set("/instructions/2/type", result)}),
        f.derive(&forward, &.{f.add("/signature/parameters/0/errors/names/1", f.s("OutOfMemory"))}),
        f.derive(&forward, &.{f.add("/signature/parameters/0/errors/names/1", f.s("Out\x08OfMemory"))}),
    }) |input| try std.testing.expectError(error.InvalidInput, z.air.decode(&ctx, try f.load(ctx.allocator, input), .memory));
}

pub fn emitted(ctx: *z.common.Context) ![]const u8 {
    const raw = try f.load(ctx.allocator, forward);
    return ctx.fmt(
        \\import Compiler.ZigAir.Captured
        \\open Compiler.ZigAir Compiler.ZigAir.Memory Compiler.ZigAir.MemoryAir
        \\def forward : Program := {s}
        \\{s}
        \\def escapingArm : Captured.Raw := {s}
        \\def wrongName : Captured.Raw := {s}
        \\def status (name : Option String) : Value := .errorValue .result ["OutOfMemory"] name
        \\example : forward.run [status none] {{}} = (.ok (status none), {{}}) := rfl
        \\example : forward.run [status (some "OutOfMemory")] {{}} =
        \\  (.ok (status (some "OutOfMemory")), {{}}) := rfl
        \\example : forward.run [status (some "IoFailure")] {{}} = (.error .malformed, {{}}) := rfl
        \\example : Captured.decode false escapingArm = none := rfl
        \\example : Captured.decode false wrongName = none := rfl
        \\example : unwrapError false (status none) = .error (.scalar .illegalBehavior) := rfl
        \\example : unwrapError true (status (some "OutOfMemory")) = .error (.scalar .illegalBehavior) := rfl
        \\
    , .{
        try z.air.decode(ctx, raw, .memory),                                try z.certificate.declaration(ctx, raw, "forward", false),
        try z.certificate.lift(ctx, try f.load(ctx.allocator, escapes), 0), try z.certificate.lift(ctx, try f.load(ctx.allocator, wrong_name), 0),
    });
}
