// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
export fn put(pointer: *u32, value: u32) void {
    pointer.* = value;
}
