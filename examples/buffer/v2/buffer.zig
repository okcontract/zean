// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.

/// `buffer[0..length]` must designate live, writable u32 storage.
/// Reject the boundary before computing or dereferencing the element pointer.
pub export fn replace(buffer: [*]u32, length: usize, index: usize, value: u32) bool {
    if (index >= length) return false;
    buffer[index] = value;
    return true;
}
