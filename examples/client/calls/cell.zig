// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.

noinline fn put(pointer: *u32, value: u32) void {
    pointer.* = value;
}

export fn update(pointer: *u32, value: u32) void {
    put(pointer, value);
}
