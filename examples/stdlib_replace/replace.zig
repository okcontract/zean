// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");

// Capture driver for the unchanged standard-library specialization. The Lean
// contract applies to that callee's slice interface, not this pointer wrapper.
pub export fn replace(buffer: [*]u32, len: usize, match: u32, replacement: u32) void {
    std.mem.replaceScalar(u32, buffer[0..len], match, replacement);
}
