// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");
const f = @import("fixtures.zig");
const shared = @import("cases/shared.zig");

fn unsigned(bits: []const u8) f.Value {
    return f.obj(&.{ .{ "kind", f.s("int") }, .{ "bits", f.n(bits) }, .{ "signedness", f.s("unsigned") } });
}

const byte = unsigned("8");
const never = f.obj(&.{.{ "kind", f.s("noreturn") }});
const errors = f.obj(&.{ .{ "kind", f.s("errorSet") }, .{ "names", f.arr(&.{f.s("InvalidDigit")}) } });
pub const result = f.obj(&.{ .{ "kind", f.s("errorScalar") }, .{ "errors", errors }, .{ "child", byte } });
pub const missing = f.obj(&.{
    .{ "kind", f.s("errorScalar") }, .{ "type", result }, .{ "name", f.s("InvalidDigit") }, .{ "payload", .null },
});
const zero = f.obj(&.{
    .{ "kind", f.s("errorScalar") }, .{ "type", result }, .{ "name", .null }, .{ "payload", number(byte, "0") },
});

fn number(ty: f.Value, value: []const u8) f.Value {
    return f.obj(&.{ .{ "kind", f.s("constant") }, .{ "type", ty }, .{ "value", f.n(value) } });
}

fn ref(index: []const u8) f.Value {
    return f.obj(&.{ .{ "kind", f.s("instruction") }, .{ "index", f.n(index) } });
}

fn arg(ty: f.Value) f.Value {
    return f.obj(&.{
        .{ "index", f.n("0") }, .{ "tag", f.s("arg") },             .{ "payloadVisited", f.b(true) },
        .{ "type", ty },        .{ "zirParameterIndex", f.n("0") },
    });
}

fn unary(index: []const u8, tag: []const u8, ty: f.Value, operand: f.Value) f.Value {
    return f.obj(&.{
        .{ "index", f.n(index) }, .{ "tag", f.s(tag) },    .{ "payloadVisited", f.b(true) },
        .{ "type", ty },          .{ "operand", operand },
    });
}

const attempt = f.derive(&shared.air_memory_program_2_input_13, &.{
    f.set("/signature/parameters", f.arr(&.{result})),
    f.set("/signature/returnType", byte),
    f.set("/sourceOperationTags", f.arr(&.{})),
    f.set("/sourceValidity/slices", f.arr(&.{})),
    f.set("/body", f.arr(&.{ f.n("0"), f.n("1"), f.n("2") })),
    f.set("/instructions", f.arr(&.{
        arg(result),
        f.obj(&.{
            .{ "index", f.n("1") }, .{ "tag", f.s("try") },   .{ "payloadVisited", f.b(true) },
            .{ "type", byte },      .{ "operand", ref("0") }, .{ "errorBody", f.arr(&.{f.n("3")}) },
        }),
        unary("2", "ret", never, ref("1")),
        unary("3", "ret", never, number(byte, "255")),
    })),
});

const wide = f.derive(&attempt, &.{
    f.set("/signature/parameters/0/child/bits", f.n("64")),
    f.set("/signature/returnType", unsigned("64")),
    f.set("/instructions/0/type/child/bits", f.n("64")),
    f.set("/instructions/1/type", unsigned("64")),
    f.set("/instructions/1/tag", f.s("try_cold")),
    f.set("/instructions/3/operand/type", unsigned("64")),
});
const from_zero = f.derive(&attempt, &.{f.set("/instructions/1/operand", zero)});
const from_error = f.derive(&attempt, &.{f.set("/instructions/1/operand", missing)});
const unwrap = f.derive(&attempt, &.{
    f.set("/instructions/1", unary("1", "unwrap_errunion_payload", byte, ref("0"))),
    f.remove("/instructions/3"),
});
const wrap = f.derive(&unwrap, &.{
    f.set("/signature/parameters", f.arr(&.{byte})),
    f.set("/signature/returnType", result),
    f.set("/instructions/0", arg(byte)),
    f.set("/instructions/1", unary("1", "wrap_errunion_payload", result, ref("0"))),
});
const wrap_tag = f.derive(&wrap, &.{
    f.set("/signature/parameters", f.arr(&.{errors})),
    f.set("/instructions/0", arg(errors)),
    f.set("/instructions/1/tag", f.s("wrap_errunion_err")),
});

const programs = [_]struct { fixture: f.Value, name: []const u8 }{
    .{ .fixture = attempt, .name = "attempt" },
    .{ .fixture = wide, .name = "wide" },
    .{ .fixture = from_zero, .name = "fromZero" },
    .{ .fixture = from_error, .name = "fromError" },
    .{ .fixture = unwrap, .name = "unwrap" },
    .{ .fixture = wrap, .name = "wrap" },
    .{ .fixture = wrap_tag, .name = "wrapTag" },
};

const mutations = [_]f.Value{
    f.derive(&attempt, &.{f.set("/instructions/1/type/bits", f.n("16"))}),
    f.derive(&unwrap, &.{f.set("/instructions/1/type/bits", f.n("16"))}),
    f.derive(&wrap, &.{f.set("/instructions/1/type/child/bits", f.n("16"))}),
    f.derive(&wrap_tag, &.{f.set("/instructions/1/type/errors/names/0", f.s("Other"))}),
    f.derive(&from_zero, &.{f.set("/instructions/1/operand/payload/value", f.n("256"))}),
    f.derive(&from_zero, &.{f.set("/instructions/1/operand/payload/type/signedness", f.s("signed"))}),
    f.derive(&from_zero, &.{f.set("/instructions/1/operand/name", f.s("InvalidDigit"))}),
    f.derive(&from_error, &.{f.set("/instructions/1/operand/name", f.s("Other"))}),
    f.derive(&from_error, &.{f.set("/instructions/1/operand/name", .null)}),
};

pub fn controls() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    for (programs) |entry|
        _ = try z.air.decode(&ctx, try f.load(ctx.allocator, entry.fixture), .memory);
    for (mutations) |mutation|
        try std.testing.expectError(error.InvalidInput, z.air.decode(&ctx, try f.load(ctx.allocator, mutation), .memory));
}

pub fn emitted(ctx: *z.common.Context) ![]const u8 {
    var parts: std.ArrayList([]const u8) = .empty;
    try parts.append(ctx.allocator,
        \\import Compiler.ZigAir.Captured
        \\open Compiler.ZigAir Compiler.ZigAir.MemoryAir
        \\namespace ScalarErrorControls
        \\
    );
    for (programs) |entry| {
        const raw = try f.load(ctx.allocator, entry.fixture);
        try parts.append(ctx.allocator, try ctx.fmt("def {s} : Program := {s}\n{s}\n", .{
            entry.name, try z.air.decode(ctx, raw, .memory), try z.certificate.declaration(ctx, raw, entry.name, false),
        }));
    }
    for (mutations) |mutation| {
        const raw = try z.certificate.lift(ctx, try f.load(ctx.allocator, mutation), 0);
        try parts.append(ctx.allocator, try ctx.fmt("example : Captured.decode false ({s}) = none := rfl\n", .{raw}));
    }
    try parts.append(ctx.allocator,
        \\def bad : Memory.Value := .errorScalar (.int false 8) ["InvalidDigit"] (.inl "InvalidDigit")
        \\def good : Memory.Value := .errorScalar (.int false 8) ["InvalidDigit"] (.inr (.int false 8 0))
        \\def word : Memory.Value := .errorScalar (.int false 64) ["InvalidDigit"] (.inr (.int false 64 18446744073709551615))
        \\example : attempt.run [good] {} = (.ok (.scalar (.int false 8 0)), {}) := rfl
        \\example : attempt.run [bad] {} = (.ok (.scalar (.int false 8 255)), {}) := rfl
        \\example : wide.run [word] {} = (.ok (.scalar (.int false 64 18446744073709551615)), {}) := rfl
        \\example : fromZero.run [bad] {} = (.ok (.scalar (.int false 8 0)), {}) := rfl
        \\example : fromError.run [good] {} = (.ok (.scalar (.int false 8 255)), {}) := rfl
        \\example : unwrap.run [bad] {} = (.error (.scalar .illegalBehavior), {}) := rfl
        \\example : wrap.run [.scalar (.int false 8 0)] {} = (.ok good, {}) := rfl
        \\example : wrapTag.run [.errorValue .tag ["InvalidDigit"] (some "InvalidDigit")] {} = (.ok bad, {}) := rfl
        \\example : (Memory.Ty.errorScalar (.int false 8) ["InvalidDigit"]).layout = none := rfl
        \\end ScalarErrorControls
        \\
    );
    return std.mem.concat(ctx.allocator, u8, parts.items);
}
