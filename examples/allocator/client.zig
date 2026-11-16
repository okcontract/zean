// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Compatibility evaluation of unchanged allocator-backed standard-library
//! operations. Ordinary allocation failures remain visible to the caller.
const std = @import("std");
const List = std.ArrayList(u8);
const Arena = std.heap.FixedBufferAllocator;

export fn append(list: *List, arena: *Arena, value: u8) bool {
    list.append(arena.allocator(), value) catch return false;
    return true;
}

export fn append_slice(list: *List, arena: *Arena, bytes: [*]const u8, length: usize) bool {
    list.appendSlice(arena.allocator(), bytes[0..length]) catch return false;
    return true;
}

export fn append_reserved(list: *List, value: u8) void {
    list.appendAssumeCapacity(value);
}

export fn clear(list: *List) void {
    list.clearRetainingCapacity();
}

export fn release(list: *List, arena: *Arena) void {
    list.deinit(arena.allocator());
}

export fn reset(arena: *Arena) void {
    arena.reset();
}
