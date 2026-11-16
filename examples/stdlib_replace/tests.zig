// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const component = @import("component");
const z = @import("zean");

test "stdlib replacement changes matching words and preserves neighboring words" {
    var storage = [_]u32{ 0xaaaaaaaa, 2, 7, 2, 9, 0xbbbbbbbb };
    component.replace(storage[1..].ptr, 4, 2, 3);
    try std.testing.expectEqualSlices(u32, &.{ 0xaaaaaaaa, 3, 7, 3, 9, 0xbbbbbbbb }, &storage);
}

test "empty and identical replacement preserve every word" {
    var storage = [_]u32{ 1, 2, 3, 2 };
    component.replace(&storage, 0, 2, 9);
    try std.testing.expectEqualSlices(u32, &.{ 1, 2, 3, 2 }, &storage);
    component.replace(&storage, storage.len, 2, 2);
    try std.testing.expectEqualSlices(u32, &.{ 1, 2, 3, 2 }, &storage);
}

test "full word values and a view inside an allocation" {
    var storage = [_]u32{ 0, 0xffffffff, 0, 0xffffffff, 0 };
    component.replace(storage[1..].ptr, 3, 0xffffffff, 0);
    try std.testing.expectEqualSlices(u32, &.{ 0, 0, 0, 0, 0 }, &storage);
}

test "retained model identifies the actual standard library" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    const source = try ctx.read(std.testing.io, try ctx.fmt("{s}/std/mem.zig", .{@import("example_options").zig_lib}), z.common.max_json_bytes);
    const model = try ctx.read(std.testing.io, try ctx.fmt("{s}/lean/Compiler/Components/Replace/Generated.lean", .{z.project_root}), 65536);
    try std.testing.expect(std.mem.indexOf(u8, model, try ctx.fmt("-- Source SHA-256: {s}\n", .{&z.common.digest(source)})) != null);
}
