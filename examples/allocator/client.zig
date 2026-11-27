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

test "reserved append uses the existing fixed-buffer allocation" {
    var buffer: [16]u8 = undefined;
    var arena: Arena = .init(&buffer);
    const allocator = arena.allocator();
    var list = try List.initCapacity(allocator, 2);
    defer list.deinit(allocator);
    const pointer = list.items.ptr;
    const end_index = arena.end_index;
    const capacity = list.capacity;
    append_reserved(&list, 10);
    append_reserved(&list, 42);
    try std.testing.expectEqualSlices(u8, &.{ 10, 42 }, list.items);
    try std.testing.expect(list.items.ptr == pointer);
    try std.testing.expectEqual(capacity, list.capacity);
    try std.testing.expectEqual(end_index, arena.end_index);
}
