// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.

/// The source word must be initialized; the destination must be writable.
pub export fn copy_word(destination: *u32, source: *const u32) void {
    copyWord(destination, source);
}

inline fn copyWord(destination: *u32, source: *const u32) void {
    destination.* = source.*;
}

/// The ranges must be valid and disjoint, and the source initialized.
/// The helper is inlined because runtime calls are outside the admitted profile.
pub export fn copy(destination: [*]u32, source: [*]const u32, length: usize) void {
    var index: usize = 0;
    while (index < length) : (index += 1) {
        copyWord(&destination[index], &source[index]);
    }
}
