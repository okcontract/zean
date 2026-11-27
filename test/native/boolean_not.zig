// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");
const f = @import("fixtures.zig");
const shared = @import("cases/shared.zig");

const boolean = f.obj(&.{.{ "kind", f.s("bool") }});
const byte = f.obj(&.{ .{ "kind", f.s("int") }, .{ "bits", f.n("8") }, .{ "signedness", f.s("unsigned") } });

const negate = f.derive(&shared.air_scalar_program_1_input_2, &.{
    f.set("/signature/parameters", f.arr(&.{boolean})),
    f.set("/signature/returnType", boolean),
    f.set("/body", f.arr(&.{ f.n("0"), f.n("1"), f.n("2") })),
    f.set("/instructions", f.arr(&.{
        f.obj(&.{ .{ "index", f.n("0") }, .{ "tag", f.s("arg") }, .{ "type", boolean }, .{ "payloadVisited", f.b(true) }, .{ "zirParameterIndex", f.n("0") } }),
        f.obj(&.{ .{ "index", f.n("1") }, .{ "tag", f.s("not") }, .{ "type", boolean }, .{ "payloadVisited", f.b(true) }, .{ "operand", ref("0") } }),
        f.obj(&.{ .{ "index", f.n("2") }, .{ "tag", f.s("ret") }, .{ "type", f.obj(&.{.{ "kind", f.s("noreturn") }}) }, .{ "payloadVisited", f.b(true) }, .{ "operand", ref("1") } }),
    })),
});
fn ref(index: []const u8) f.Value {
    return f.obj(&.{ .{ "kind", f.s("instruction") }, .{ "index", f.n(index) } });
}
pub fn controls() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    const program = try z.air.decode(&ctx, try f.load(ctx.allocator, negate), .scalar);
    try std.testing.expect(std.mem.find(u8, program, "(.booleanNot (.local 0))") != null);
    for ([_]f.Value{
        f.derive(&negate, &.{ f.set("/signature/parameters/0", byte), f.set("/instructions/0/type", byte) }),
        f.derive(&negate, &.{f.set("/instructions/1/type", byte)}),
    }) |input| try std.testing.expectError(error.InvalidInput, z.air.decode(&ctx, try f.load(ctx.allocator, input), .scalar));
}
