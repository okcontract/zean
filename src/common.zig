// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
pub const Value = std.json.Value;
pub const Error = error{ InvalidInput, OutOfMemory };
pub const max_json_bytes = 16 * 1024 * 1024;

pub const Context = struct {
    allocator: std.mem.Allocator,
    diagnostic: []const u8 = "unsupported input",

    pub fn fail(self: *Context, comptime format: []const u8, args: anytype) Error {
        self.diagnostic = std.fmt.allocPrint(self.allocator, format, args) catch "out of memory";
        return error.InvalidInput;
    }
    pub fn require(self: *Context, condition: bool, message: []const u8) Error!void {
        if (!condition) return self.fail("{s}", .{message});
    }
    pub fn fmt(self: *Context, comptime format: []const u8, args: anytype) Error![]const u8 {
        try self.require(std.fmt.count(format, args) <= max_json_bytes, "generated expression exceeds the output resource limit");
        return std.fmt.allocPrint(self.allocator, format, args);
    }
    pub fn make(self: *Context, comptime T: type, value: T) Error!*const T {
        const pointer = try self.allocator.create(T);
        pointer.* = value;
        return pointer;
    }
    pub fn parse(self: *Context, bytes: []const u8) Error!Value {
        try self.require(bytes.len <= max_json_bytes, "capture record exceeds inspection limit");
        const value = std.json.parseFromSliceLeaky(Value, self.allocator, bytes, .{
            .parse_numbers = false,
            .allocate = .alloc_always,
            .max_value_len = max_json_bytes,
        }) catch |err| {
            if (err == error.OutOfMemory) return error.OutOfMemory;
            return self.fail("invalid JSON: {s}", .{@errorName(err)});
        };
        try jsonDepth(self, value, 0);
        return value;
    }
    pub fn field(self: *Context, value: Value, name: []const u8) Error!Value {
        return get(value, name) orelse return self.fail("missing field: {s}", .{name});
    }
    pub fn fields(self: *Context, value: Value, names: []const u8) Error!void {
        if (value != .object) return self.fail("expected an AIR object with fields [{s}], found {s}", .{ names, @tagName(value) });
        var words = std.mem.tokenizeScalar(u8, names, ' ');
        var count: usize = 0;
        while (words.next()) |word| {
            if (!value.object.contains(word)) return self.fail("missing AIR field '{s}' (expected [{s}])", .{ word, names });
            count += 1;
        }
        if (value.object.count() != count) {
            for (value.object.keys()) |key| {
                var expected = std.mem.tokenizeScalar(u8, names, ' ');
                while (expected.next()) |word| {
                    if (std.mem.eql(u8, key, word)) break;
                } else return self.fail("unexpected AIR field '{f}' (expected [{s}])", .{ std.zig.fmtString(key[0..@min(key.len, 160)]), names });
            }
            return self.fail("AIR field count differs from expected [{s}]", .{names});
        }
    }
    pub fn str(self: *Context, value: Value) Error![]const u8 {
        if (value != .string) return self.fail("expected a string", .{});
        return value.string;
    }
    pub fn array(self: *Context, value: Value) Error![]const Value {
        if (value != .array) return self.fail("expected an array", .{});
        return value.array.items;
    }
    pub fn nat(self: *Context, value: Value, maximum: u64) Error!u64 {
        const result: u64 = switch (value) {
            .integer => |number| if (number >= 0) @intCast(number) else return self.fail("invalid or unsupported AIR integer", .{}),
            .number_string => |number| std.fmt.parseInt(u64, number, 10) catch return self.fail("invalid or unsupported AIR integer", .{}),
            else => return self.fail("invalid or unsupported AIR integer", .{}),
        };
        try self.require(result <= maximum, "invalid or unsupported AIR integer");
        return result;
    }
    pub fn integer(self: *Context, value: Value) Error!i1024 {
        return switch (value) {
            .integer => |number| number,
            .number_string => |number| std.fmt.parseInt(i1024, number, 10) catch return self.fail("invalid AIR constant integer", .{}),
            else => self.fail("invalid AIR constant integer", .{}),
        };
    }
    pub fn json(self: *Context, value: anytype) Error![]const u8 {
        return std.json.Stringify.valueAlloc(self.allocator, value, .{});
    }
    pub fn read(self: *Context, io: std.Io, path: []const u8, limit: usize) ![]const u8 {
        return std.Io.Dir.cwd().readFileAlloc(io, path, self.allocator, .limited(limit));
    }
};
fn jsonDepth(ctx: *Context, value: Value, depth: usize) Error!void {
    try ctx.require(depth <= 128, "JSON nesting exceeds inspection limit");
    if (value == .object) {
        for (value.object.values()) |child| try jsonDepth(ctx, child, depth + 1);
    } else if (value == .array) {
        for (value.array.items) |child| try jsonDepth(ctx, child, depth + 1);
    }
}

pub fn get(value: Value, name: []const u8) ?Value {
    return if (value == .object) value.object.get(name) else null;
}
pub fn stringIs(value: Value, expected: []const u8) bool {
    return value == .string and std.mem.eql(u8, value.string, expected);
}
pub fn tag(value: Value, name: []const u8, expected: []const u8) bool {
    return stringIs(get(value, name) orelse return false, expected);
}
pub fn boolean(value: Value, expected: bool) bool {
    return value == .bool and value.bool == expected;
}
pub fn flag(value: Value, name: []const u8, expected: bool) bool {
    return boolean(get(value, name) orelse return false, expected);
}
pub fn none(value: Value, name: []const u8) bool {
    return (get(value, name) orelse return false) == .null;
}
pub fn equal(a: Value, b: Value) bool {
    if (std.meta.activeTag(a) != std.meta.activeTag(b)) return false;
    return switch (a) {
        .null => true,
        .bool => |value| value == b.bool,
        .integer => |value| value == b.integer,
        .float => |value| value == b.float,
        .string => |value| std.mem.eql(u8, value, b.string),
        .number_string => |value| std.mem.eql(u8, value, b.number_string),
        .array => |value| blk: {
            if (value.items.len != b.array.items.len) break :blk false;
            for (value.items, b.array.items) |left, right| if (!equal(left, right)) break :blk false;
            break :blk true;
        },
        .object => |value| blk: {
            if (value.count() != b.object.count()) break :blk false;
            var iterator = value.iterator();
            while (iterator.next()) |entry| if (!equal(entry.value_ptr.*, b.object.get(entry.key_ptr.*) orelse break :blk false)) break :blk false;
            break :blk true;
        },
    };
}
pub fn oneOf(value: []const u8, choices: []const []const u8) bool {
    for (choices) |choice| if (std.mem.eql(u8, value, choice)) return true;
    return false;
}
pub fn boolText(value: bool) []const u8 {
    return if (value) "true" else "false";
}
pub fn isDigest(value: []const u8) bool {
    if (value.len != 64) return false;
    for (value) |char| if (!std.ascii.isDigit(char) and !(char >= 'a' and char <= 'f')) return false;
    return true;
}
pub fn digest(bytes: []const u8) [64]u8 {
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &hash, .{});
    return std.fmt.bytesToHex(hash, .lower);
}
pub fn identifier(value: []const u8, dotted: bool) bool {
    var start = true;
    for (value) |char| {
        if (dotted and char == '.') {
            if (start) return false;
            start = true;
        } else if (start) {
            if (!std.ascii.isAlphabetic(char)) return false;
            start = false;
        } else if (!std.ascii.isAlphanumeric(char) and char != '_') return false;
    }
    return !start;
}

test "JSON is bounded, exact and rejects duplicate keys" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var context: Context = .{ .allocator = arena.allocator() };
    try std.testing.expectError(error.InvalidInput, context.parse("{\"x\":1,\"x\":2}"));
    const value = try context.parse("123456789123456789123456789123456789123456789");
    try std.testing.expectEqual(@as(i1024, 123456789123456789123456789123456789123456789), try context.integer(value));
    try std.testing.expectError(error.InvalidInput, context.nat(.{ .bool = true }, 1));
}

test "AIR field diagnostics identify missing and additional keys" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: Context = .{ .allocator = arena.allocator() };
    const record = try ctx.parse("{\"kind\":1,\"layout\":2}");
    try std.testing.expectError(error.InvalidInput, ctx.fields(record, "kind identity"));
    try std.testing.expectEqualStrings("missing AIR field 'identity' (expected [kind identity])", ctx.diagnostic);
    try std.testing.expectError(error.InvalidInput, ctx.fields(record, "kind"));
    try std.testing.expectEqualStrings("unexpected AIR field 'layout' (expected [kind])", ctx.diagnostic);
}

pub fn ordered(ctx: *Context, value: Value) Error!Value {
    if (value == .object) {
        const keys = try ctx.allocator.dupe([]const u8, value.object.keys());
        std.mem.sort([]const u8, keys, {}, struct {
            fn less(_: void, a: []const u8, b: []const u8) bool {
                return std.mem.lessThan(u8, a, b);
            }
        }.less);
        var result: Value = .{ .object = .empty };
        for (keys) |key| try result.object.put(ctx.allocator, key, try ordered(ctx, value.object.get(key).?));
        return result;
    }
    if (value == .array) {
        var result: Value = .{ .array = std.array_list.Managed(Value).init(ctx.allocator) };
        for (value.array.items) |entry| try result.array.append(try ordered(ctx, entry));
        return result;
    }
    return value;
}
pub fn fingerprint(ctx: *Context, value: Value) Error![]const u8 {
    const bytes = try std.json.Stringify.valueAlloc(ctx.allocator, try ordered(ctx, value), .{ .escape_unicode = true });
    return ctx.allocator.dupe(u8, &digest(bytes));
}
