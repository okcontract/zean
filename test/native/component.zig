// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");

pub fn controls() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    const source =
        \\// fn decoy() void {}
        \\const text = "fn decoy() void {}";
        \\pub fn same() void {}
        \\const Nested = struct { fn same() void {} };
        \\const callback: *const fn () void = undefined;
    ;
    const inventory = try z.component.declarations(&ctx, source);
    const entries = try ctx.array(inventory);
    try std.testing.expectEqual(@as(usize, 2), entries.len);
    for (entries) |entry| try std.testing.expect(z.common.tag(entry, "name", "same"));
    try std.testing.expect(!z.common.equal(try ctx.field(entries[0], "startByte"), try ctx.field(entries[1], "startByte")));
    try std.testing.expectError(error.InvalidInput, z.component.declarations(&ctx, "pub fn missing("));
}
