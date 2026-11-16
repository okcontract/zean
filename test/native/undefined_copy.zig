// Copyright (C) 2026 OKcontract Pte. Ltd.
// SPDX-License-Identifier: Apache-2.0
const std = @import("std");

/// Copying an undefined byte transports its initialization state. The byte is
/// initialized before a value read; no particular undefined bit pattern is used.
export fn transfer() u8 {
    var source: [2]u8 = undefined;
    source[0] = 3;
    var destination: [2]u8 = undefined;
    @memcpy(&destination, &source);
    destination[1] = 4;
    return destination[0] + destination[1];
}

pub fn controls() !void {
    try std.testing.expectEqual(@as(u8, 7), transfer());
    comptime {
        if (transfer() != 7) @compileError("undefined-byte transport changed");
    }
}
