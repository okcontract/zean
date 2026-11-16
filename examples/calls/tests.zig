// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const calls = @import("calls");
const z = @import("zean");

test "nested direct calls enforce the logical view and preserve neighbors" {
    var words = [_]u32{ 101, 3, 5, 103 };
    try std.testing.expect(calls.update(words[1..].ptr, 2, 1, 17));
    try std.testing.expectEqualSlices(u32, &.{ 101, 3, 17, 103 }, &words);
    try std.testing.expect(!calls.update(words[1..].ptr, 2, 2, 19));
    try std.testing.expect(!calls.update(words[1..].ptr, 0, 0, 23));
    try std.testing.expect(!calls.update(words[1..].ptr, 2, std.math.maxInt(usize), 29));
    try std.testing.expectEqualSlices(u32, &.{ 101, 3, 17, 103 }, &words);
}

test "call capture binds the current source" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    const source = try ctx.read(std.testing.io, try ctx.fmt("{s}/examples/calls/calls.zig", .{z.project_root}), 65536);
    const model = try ctx.read(std.testing.io, try ctx.fmt("{s}/lean/Compiler/Tutorial/Calls/Generated.lean", .{z.project_root}), 65536);
    try std.testing.expect(std.mem.indexOf(u8, model, try ctx.fmt("-- Source SHA-256: {s}\n", .{&z.common.digest(source)})) != null);
}
