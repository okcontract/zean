// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");

pub export fn upper(destination: [*]u8, source: [*]const u8, length: usize) void {
    _ = std.ascii.upperString(destination[0..length], source[0..length]);
}

pub export fn lower(destination: [*]u8, source: [*]const u8, length: usize) void {
    _ = std.ascii.lowerString(destination[0..length], source[0..length]);
}
