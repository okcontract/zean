// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.

/// `buffer[0..length]` must designate live, writable u32 storage.
/// Replace one element, or return false without changing the buffer.
pub export fn replace(buffer: [*]u32, length: usize, index: usize, value: u32) bool {
    if (index < length) {
        buffer[index] = value;
        return true;
    }
    return false;
}
