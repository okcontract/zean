// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const counter = @import("counter");
const options = @import("example_options");
const UInt = if (options.wide) u32 else u8;

fn check(value: UInt) !void {
    const expected: UInt = @intCast(@min(@as(u64, value) + options.step, std.math.maxInt(UInt)));
    try std.testing.expectEqual(expected, counter.advance(value));
}

test "counter matches an independent widened saturating specification" {
    if (!options.wide) {
        for (0..256) |input| try check(@intCast(input));
    } else {
        // Boundary cases plus reproducible samples; the Lean theorem is universal.
        for (0..256) |input| {
            try check(@intCast(input));
            try check(std.math.maxInt(u32) - @as(u32, @intCast(input)));
        }
        var state: u32 = 0x42658f31;
        for (0..4096) |_| {
            state = state *% 1664525 +% 1013904223;
            try check(state);
        }
    }
}

test {
    _ = @import("identity.zig");
}
