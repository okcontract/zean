// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Preserve the fixed-length many-pointer conversion used by Ziglings 054.
//! The memory profile preserves its static extent and checks AIR correspondence.
pub export fn select(bytes: [*]const u8, index: usize) u8 {
    const phrase: []const u8 = bytes[0..21];
    if (index >= phrase.len) return 0;
    return phrase[index];
}
