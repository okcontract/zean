// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Shared immutable fixtures with explicit, checked field and text mutations.
//! Expected values are recorded independently of the implementation under test.
const std = @import("std");

pub const Field = struct { []const u8, Value };
pub const Value = union(enum) {
    null,
    boolean: bool,
    number: []const u8,
    string: []const u8,
    object: []const Field,
    array: []const Value,
    reference: *const Value,
    derived: struct { base: *const Value, edits: []const Edit },
    repeated: struct { byte: u8, count: usize },
};
pub const TextEdit = struct { at: usize, old: []const u8, new: []const u8 };
pub const Edit = struct {
    path: []const u8,
    action: union(enum) { set: Value, add: Value, remove, text: []const TextEdit },
};
pub fn obj(fields: []const Field) Value {
    return .{ .object = fields };
}
pub fn arr(values: []const Value) Value {
    return .{ .array = values };
}
pub fn s(bytes: []const u8) Value {
    return .{ .string = bytes };
}
pub fn n(bytes: []const u8) Value {
    return .{ .number = bytes };
}
pub fn b(value: bool) Value {
    return .{ .boolean = value };
}
pub fn ref(value: *const Value) Value {
    return .{ .reference = value };
}
pub fn repeat(byte: u8, count: usize) Value {
    return .{ .repeated = .{ .byte = byte, .count = count } };
}
pub fn derive(base: *const Value, edits: []const Edit) Value {
    return .{ .derived = .{ .base = base, .edits = edits } };
}
pub fn set(path: []const u8, value: Value) Edit {
    return .{ .path = path, .action = .{ .set = value } };
}
pub fn add(path: []const u8, value: Value) Edit {
    return .{ .path = path, .action = .{ .add = value } };
}
pub fn remove(path: []const u8) Edit {
    return .{ .path = path, .action = .remove };
}
pub fn text(path: []const u8, edits: []const TextEdit) Edit {
    return .{ .path = path, .action = .{ .text = edits } };
}

pub fn load(allocator: std.mem.Allocator, fixture: Value) anyerror!std.json.Value {
    return switch (fixture) {
        .null => .null,
        .boolean => |value| .{ .bool = value },
        .number => |value| .{ .number_string = value },
        .string => |value| .{ .string = value },
        .repeated => |value| blk: {
            const bytes = try allocator.alloc(u8, value.count);
            @memset(bytes, value.byte);
            break :blk .{ .string = bytes };
        },
        .reference => |value| load(allocator, value.*),
        .array => |values| blk: {
            var result: std.json.Value = .{ .array = std.json.Array.init(allocator) };
            for (values) |value| try result.array.append(try load(allocator, value));
            break :blk result;
        },
        .object => |fields| blk: {
            var result: std.json.Value = .{ .object = .empty };
            for (fields) |field| {
                if (result.object.contains(field[0])) return error.DuplicateFixtureField;
                try result.object.put(allocator, field[0], try load(allocator, field[1]));
            }
            break :blk result;
        },
        .derived => |value| blk: {
            var result = try load(allocator, value.base.*);
            for (value.edits) |edit| try apply(allocator, &result, edit);
            break :blk result;
        },
    };
}
pub fn cases(allocator: std.mem.Allocator, fixtures: []const Value) !std.json.Value {
    return load(allocator, arr(fixtures));
}
fn segment(allocator: std.mem.Allocator, raw: []const u8) ![]const u8 {
    var result: std.ArrayList(u8) = .empty;
    var i: usize = 0;
    while (i < raw.len) : (i += 1) {
        if (raw[i] != '~') {
            try result.append(allocator, raw[i]);
            continue;
        }
        i += 1;
        if (i >= raw.len) return error.InvalidFixturePath;
        try result.append(allocator, switch (raw[i]) {
            '0' => '~',
            '1' => '/',
            else => return error.InvalidFixturePath,
        });
    }
    return result.items;
}
fn arrayIndex(raw: []const u8, limit: usize) !usize {
    const index = std.fmt.parseInt(usize, raw, 10) catch return error.InvalidFixturePath;
    if (index >= limit) return error.InvalidFixturePath;
    return index;
}
fn replaceText(allocator: std.mem.Allocator, target: *std.json.Value, edits: []const TextEdit) !void {
    if (target.* != .string) return error.InvalidFixtureText;
    const original = target.string;
    var result: std.ArrayList(u8) = .empty;
    var position: usize = 0;
    for (edits) |edit| {
        if (edit.at < position or edit.at > original.len or edit.old.len > original.len - edit.at) return error.InvalidFixtureText;
        const end = edit.at + edit.old.len;
        if (!std.mem.eql(u8, original[edit.at..end], edit.old)) return error.InvalidFixtureText;
        try result.appendSlice(allocator, original[position..edit.at]);
        try result.appendSlice(allocator, edit.new);
        position = end;
    }
    try result.appendSlice(allocator, original[position..]);
    target.* = .{ .string = try result.toOwnedSlice(allocator) };
}
fn apply(allocator: std.mem.Allocator, root: *std.json.Value, edit: Edit) !void {
    if (edit.path.len == 0) switch (edit.action) {
        .set => |value| {
            root.* = try load(allocator, value);
            return;
        },
        .text => |edits| return replaceText(allocator, root, edits),
        else => return error.InvalidFixturePath,
    };
    if (edit.path[0] != '/') return error.InvalidFixturePath;
    var tokens = std.mem.splitScalar(u8, edit.path[1..], '/');
    var target = root;
    while (tokens.next()) |raw| {
        const key = try segment(allocator, raw);
        if (tokens.peek() != null) {
            target = switch (target.*) {
                .object => |*object| object.getPtr(key) orelse return error.InvalidFixturePath,
                .array => |*array| &array.items[try arrayIndex(key, array.items.len)],
                else => return error.InvalidFixturePath,
            };
            continue;
        }
        switch (target.*) {
            .object => |*object| switch (edit.action) {
                .add => |value| {
                    if (object.contains(key)) return error.InvalidFixturePath;
                    try object.put(allocator, key, try load(allocator, value));
                },
                .set => |value| {
                    const entry = object.getPtr(key) orelse return error.InvalidFixturePath;
                    entry.* = try load(allocator, value);
                },
                .remove => {
                    if (!object.orderedRemove(key)) return error.InvalidFixturePath;
                },
                .text => |edits| try replaceText(allocator, object.getPtr(key) orelse return error.InvalidFixturePath, edits),
            },
            .array => |*array| switch (edit.action) {
                .add => |value| try array.insert(try arrayIndex(key, array.items.len + 1), try load(allocator, value)),
                .set => |value| {
                    array.items[try arrayIndex(key, array.items.len)] = try load(allocator, value);
                },
                .remove => {
                    _ = array.orderedRemove(try arrayIndex(key, array.items.len));
                },
                .text => |edits| try replaceText(allocator, &array.items[try arrayIndex(key, array.items.len)], edits),
            },
            else => return error.InvalidFixturePath,
        }
        return;
    }
    return error.InvalidFixturePath;
}

test "fixture edits preserve independent baselines and reject stale paths or text" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const base = obj(&.{ .{ "instructions", arr(&.{ n("0"), n("2") }) }, .{ "a/b~c", s("old body") }, .{ "drop", b(true) } });
    const changed = derive(&base, &.{ add("/instructions/1", n("1")), remove("/drop"), text("/a~1b~0c", &.{.{ .at = 0, .old = "old", .new = "new" }}), set("/instructions/2", n("3")) });
    const result = try load(a, changed);
    try std.testing.expectEqualStrings("1", result.object.get("instructions").?.array.items[1].number_string);
    try std.testing.expectEqualStrings("3", result.object.get("instructions").?.array.items[2].number_string);
    try std.testing.expectEqualStrings("new body", result.object.get("a/b~c").?.string);
    try std.testing.expect(!result.object.contains("drop"));
    const unchanged = try load(a, base);
    try std.testing.expectEqual(@as(usize, 2), unchanged.object.get("instructions").?.array.items.len);
    try std.testing.expectEqualStrings("old body", unchanged.object.get("a/b~c").?.string);
    try std.testing.expectError(error.InvalidFixturePath, load(a, derive(&base, &.{set("/missing", .null)})));
    try std.testing.expectError(error.InvalidFixtureText, load(a, derive(&base, &.{text("/a~1b~0c", &.{.{ .at = 0, .old = "stale", .new = "new" }})})));
}
