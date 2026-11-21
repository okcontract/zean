// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.

// One writer, two distinct table entries, and a separate flag initially zero.
// After this single publication both entries stay live and immutable.
pub export fn publish(first: *u8, second: *u8, ready: *u8, a: u8, b: u8) void {
    first.* = a;
    second.* = b;
    @atomicStore(u8, ready, 1, .release);
}

// slot points to either table entry and ready is the publisher's flag.
pub export fn readEntry(slot: *const u8, ready: *const u8) u8 {
    if (@atomicLoad(u8, ready, .acquire) == 1) return slot.*;
    return 0;
}
