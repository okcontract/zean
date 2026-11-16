// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.

// Intentionally incorrect: index == length writes beyond the supplied buffer.
// Capture this function for the negative proof; do not execute it natively.
pub export fn replace(buffer: [*]u32, length: usize, index: usize, value: u32) bool {
    if (index <= length) {
        buffer[index] = value;
        return true;
    }
    return false;
}
