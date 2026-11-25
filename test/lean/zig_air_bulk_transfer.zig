// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.

export fn copy_slices(dst: [*]u8, dst_len: usize, src: [*]const u8, src_len: usize) void {
    @memcpy(dst[0..dst_len], src[0..src_len]);
}

export fn copy_from_pointer(dst: [*]u8, length: usize, src: [*]const u8) void {
    @memcpy(dst[0..length], src);
}

export fn copy_erased(dst: [*]u8, dst_len: usize, src: *const [0]u8) void {
    @memcpy(dst[0..dst_len], src);
}
