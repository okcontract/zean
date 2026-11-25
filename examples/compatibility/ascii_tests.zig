// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const driver = @import("ascii_driver.zig");

test "case conversion covers all bytes and preserves the destination suffix" {
    var input: [256]u8 = undefined;
    for (&input, 0..) |*byte, index| byte.* = @intCast(index);
    var upper: [257]u8 = @splat(0xff);
    var lower: [257]u8 = @splat(0xff);
    driver.upper(&upper, &input, input.len);
    driver.lower(&lower, &input, input.len);
    for (input, 0..) |byte, index| {
        try std.testing.expectEqual(if (byte >= 'a' and byte <= 'z') byte - 32 else byte, upper[index]);
        try std.testing.expectEqual(if (byte >= 'A' and byte <= 'Z') byte + 32 else byte, lower[index]);
    }
    try std.testing.expectEqual(@as(u8, 0xff), upper[input.len]);
    try std.testing.expectEqual(@as(u8, 0xff), lower[input.len]);
}
