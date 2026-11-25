// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");
const f = @import("fixtures.zig");
const shared = @import("cases/shared.zig");

const byte = f.obj(&.{ .{ "kind", f.s("int") }, .{ "bits", f.n("8") }, .{ "signedness", f.s("unsigned") } });
const boolean = f.obj(&.{.{ "kind", f.s("bool") }});
const never = f.obj(&.{.{ "kind", f.s("noreturn") }});
const optional = f.obj(&.{
    .{ "kind", f.s("optionalScalar") },                                                                      .{ "child", byte },
    .{ "layout", f.obj(&.{ .{ "kind", f.s("abi") }, .{ "bytes", f.n("2") }, .{ "alignment", f.n("1") } }) },
});
const none = f.obj(&.{ .{ "kind", f.s("optionalValue") }, .{ "type", optional }, .{ "payload", .null } });
const zero = f.obj(&.{
    .{ "kind", f.s("optionalValue") },                                                                    .{ "type", optional },
    .{ "payload", f.obj(&.{ .{ "kind", f.s("constant") }, .{ "type", byte }, .{ "value", f.n("0") } }) },
});

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

const unwrapped = f.derive(&shared.air_memory_program_2_input_13, &.{
    f.set("/signature/parameters", f.arr(&.{optional})),
    f.set("/signature/returnType", byte),
    f.set("/sourceOperationTags", f.arr(&.{})),
    f.set("/sourceValidity/slices", f.arr(&.{})),
    f.set("/body", f.arr(&.{ f.n("0"), f.n("1"), f.n("2") })),
    f.set("/instructions", f.arr(&.{ arg(optional), unary("1", "optional_payload", byte, ref("0")), unary("2", "ret", never, ref("1")) })),
});

const wrapped = f.derive(&unwrapped, &.{
    f.set("/signature/parameters", f.arr(&.{byte})),
    f.set("/signature/returnType", optional),
    f.set("/instructions/0", arg(byte)),
    f.set("/instructions/1", unary("1", "wrap_optional", optional, ref("0"))),
});

const present = f.derive(&unwrapped, &.{
    f.set("/signature/returnType", boolean),
    f.set("/instructions/1", unary("1", "is_non_null", boolean, zero)),
});
const absent = f.derive(&present, &.{f.set("/instructions/1", unary("1", "is_null", boolean, none))});

const mutations = [_]f.Value{
    f.derive(&wrapped, &.{f.set("/instructions/1/operand", zero)}),
    f.derive(&unwrapped, &.{f.set("/instructions/1/type/bits", f.n("16"))}),
    f.derive(&unwrapped, &.{f.set("/signature/parameters/0/layout/bytes", f.n("1"))}),
    f.derive(&unwrapped, &.{f.set("/signature/parameters/0/child/signedness", f.s("signed"))}),
    f.derive(&present, &.{f.set("/instructions/1/operand/payload/value", f.n("256"))}),
    f.derive(&present, &.{f.set("/instructions/1/operand/payload/kind", f.s("undefined"))}),
    f.derive(&absent, &.{f.remove("/instructions/1/operand/payload")}),
    f.derive(&absent, &.{f.set("/instructions/1/type", byte)}),
};

pub fn controls() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    for ([_]f.Value{ unwrapped, wrapped, present, absent }) |fixture|
        _ = try z.air.decode(&ctx, try f.load(ctx.allocator, fixture), .memory);
    for (mutations) |mutated|
        try std.testing.expectError(error.InvalidInput, z.air.decode(&ctx, try f.load(ctx.allocator, mutated), .memory));
    try std.testing.expectError(error.InvalidInput, z.air.decode(&ctx, try f.load(ctx.allocator, wrapped), .scalar));
}

pub fn emitted(ctx: *z.common.Context) ![]const u8 {
    var parts: std.ArrayList([]const u8) = .empty;
    try parts.append(ctx.allocator,
        \\import Compiler.ZigAir.Captured
        \\open Compiler.ZigAir Compiler.ZigAir.MemoryAir
        \\namespace OptionalByteControls
        \\
    );
    for ([_]f.Value{ unwrapped, wrapped, present, absent }, [_][]const u8{ "unwrapped", "wrapped", "present", "absent" }) |fixture, name| {
        const raw = try f.load(ctx.allocator, fixture);
        try parts.append(ctx.allocator, try ctx.fmt("def {s} : Program := {s}\n{s}\n", .{
            name, try z.air.decode(ctx, raw, .memory), try z.certificate.declaration(ctx, raw, name, false),
        }));
    }
    for (mutations) |mutation| {
        const raw = try z.certificate.lift(ctx, try f.load(ctx.allocator, mutation), 0);
        try parts.append(ctx.allocator, try ctx.fmt("example : Captured.decode false ({s}) = none := rfl\n", .{raw}));
    }
    try parts.append(ctx.allocator,
        \\def noByte : Memory.Value := .optionalScalar (.int false 8) none
        \\def zeroByte : Memory.Value := .optionalScalar (.int false 8) (some (.int false 8 0))
        \\example : wrapped.run [.scalar (.int false 8 0)] {} = (.ok zeroByte, {}) := rfl
        \\example : unwrapped.run [zeroByte] {} = (.ok (.scalar (.int false 8 0)), {}) := rfl
        \\example : unwrapped.run [noByte] {} = (.error (.scalar .illegalBehavior), {}) := rfl
        \\example : present.run [noByte] {} = (.ok (.scalar (.bool true)), {}) := rfl
        \\example : absent.run [zeroByte] {} = (.ok (.scalar (.bool true)), {}) := rfl
        \\end OptionalByteControls
        \\
    );
    return std.mem.concat(ctx.allocator, u8, parts.items);
}
