// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");
const f = @import("fixtures.zig");
const shared = @import("cases/shared.zig");
const golden = @import("cases/golden.zig");

pub fn controls() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    try std.testing.expectEqualStrings("\"quote\\\" slash\\\\ line\\n λ\"", try z.certificate.string(&ctx, "quote\" slash\\ line\n λ"));
    try std.testing.expectError(error.InvalidInput, z.certificate.string(&ctx, "\x01"));
    try std.testing.expectError(error.InvalidInput, z.certificate.string(&ctx, "\xff"));
    try std.testing.expectError(error.InvalidInput, z.certificate.lift(&ctx, .{ .float = 1.5 }, 0));
    try std.testing.expectError(error.InvalidInput, z.certificate.lift(&ctx, .null, 129));
}

pub const mutations = [_]f.Edit{
    f.set("/instructions/0/zirParameterIndex", f.n("1")),
    f.set("/instructions/3/operand/value", f.n("2")),
    f.set("/instructions/2/tag", f.s("ptr_add")),
    f.set("/body", f.arr(&.{ f.n("1"), f.n("0"), f.n("2"), f.n("3") })),
    f.set("/body", f.arr(&.{ f.n("0"), f.n("1"), f.n("3") })),
    f.set("/sourceValidity/slices/0/upperBound", f.obj(&.{ .{ "kind", f.s("arrayLength") }, .{ "value", f.n("0") } })),
    f.set("/instructions/2/tag", f.s("unrecognized_operation")),
    f.set("/signature/parameters/0/flags/isConst", f.b(false)),
};

pub fn emitted(ctx: *z.common.Context, mutation: ?usize) ![]const u8 {
    const raw = try f.load(ctx.allocator, if (mutation) |index| f.derive(&shared.air_memory_program_2_input_13, mutations[index .. index + 1]) else f.ref(&shared.air_memory_program_2_input_13));
    // Independently recorded model, not constructed from the input decoder.
    const model = try f.load(ctx.allocator, golden.air_memory_program_2_output_30);
    return ctx.fmt("import Compiler.ZigAir.Captured\nopen Compiler.ZigAir.MemoryAir\ndef program : Program :=\n{s}\n{s}\n", .{ model.string, try z.certificate.declaration(ctx, raw, "program", false) });
}

pub const scalar_mutations = [_]f.Edit{
    f.set("/instructions/0/zirParameterIndex", f.n("1")),
    f.set("/instructions/2/rhs/value", f.n("129")),
    f.set("/instructions/4/tag", f.s("sub")),
    f.set("/instructions/4/tag", f.s("add_wrap")),
    f.set("/instructions/3/thenBody", f.arr(&.{ f.n("5"), f.n("4") })),
    f.set("/instructions/3/thenBody", f.arr(&.{f.n("5")})),
    f.set("/instructions/3/thenBody", f.arr(&.{f.n("6")})),
    f.set("/instructions/4/payloadVisited", f.b(false)),
    f.set("/instructions/4/tag", f.s("unrecognized_operation")),
    f.set("/instructions/4/tag", f.s("store")),
    f.set("/instructions/4/type/bits", f.n("257")),
    f.set("/sourceValidity/slices", f.arr(&.{.null})),
    f.set("/instructions/7/operand/index", f.n("0")),
};

pub fn scalarEmitted(ctx: *z.common.Context, mutation: ?usize) ![]const u8 {
    const raw = try f.load(ctx.allocator, if (mutation) |index| f.derive(&shared.air_scalar_program_1_input_2, scalar_mutations[index .. index + 1]) else f.ref(&shared.air_scalar_program_1_input_2));
    // Retain the independently recorded model when changing the raw input.
    const model = try f.load(ctx.allocator, golden.air_scalar_program_1_output_11);
    return ctx.fmt("import Compiler.ZigAir.CapturedScalar\nopen Compiler.ZigAir.Scalar\ndef program : Program :=\n{s}\n{s}\n", .{ model.string, try z.certificate.scalarDeclaration(ctx, raw, "program") });
}
