// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.

noinline fn inside(index: usize, len: usize) bool {
    return index < len;
}

pub noinline fn replace(buffer: [*]u32, len: usize, index: usize, value: u32) bool {
    if (inside(index, len)) {
        buffer[index] = value;
        return true;
    }
    return false;
}

pub export fn update(buffer: [*]u32, len: usize, index: usize, value: u32) bool {
    return replace(buffer, len, index, value);
}
