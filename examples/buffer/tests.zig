// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const buffer = @import("buffer");

// Sentinels before and after the logical view detect writes which remain inside
// the backing allocation but violate the caller's smaller buffer contract.
const baseline = [_]u32{ 17, 29, 41, 53, 67, 79, 83, 97 };

fn check(first: usize, length: usize, index: usize, value: u32) !void {
    var actual = baseline;
    var expected = baseline;
    const accepted = index < length;
    if (accepted) expected[first + index] = value;
    try std.testing.expectEqual(accepted, buffer.replace(actual[first..].ptr, length, index, value));
    try std.testing.expectEqualSlices(u32, &expected, &actual);
}

test "replacement and rejection preserve every other word of the backing allocation" {
    for (0..baseline.len + 1) |first| {
        for (0..baseline.len - first + 1) |length| {
            for (0..baseline.len + 2) |index| {
                for ([_]u32{ 0, 1, 0xffffffff }) |value| try check(first, length, index, value);
            }
            try check(first, length, std.math.maxInt(usize), 123);
        }
    }
}

test {
    _ = @import("identity.zig");
}
