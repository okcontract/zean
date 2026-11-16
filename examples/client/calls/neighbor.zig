// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
// Negative counterpart of cell.zig: change only the helper's write target.

noinline fn put(pointer: *u32, value: u32) void {
    const words: [*]u32 = @ptrCast(pointer);
    words[1] = value;
}

export fn update(pointer: *u32, value: u32) void {
    put(pointer, value);
}
