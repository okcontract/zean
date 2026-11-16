// Copyright (C) 2026 OKcontract Pte. Ltd.
// SPDX-License-Identifier: Apache-2.0

noinline fn nonzero(value: u8) bool {
    return value != 0;
}

// Deliberate control: the inclusive bound reaches a one-past-the-end read.
export fn all_nonzero(bytes: [*]const u8, length: usize) bool {
    var index: usize = 0;
    while (index <= length) : (index += 1) {
        if (!nonzero(bytes[index])) return false;
    }
    return true;
}
