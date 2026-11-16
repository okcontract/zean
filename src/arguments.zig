// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const c = @import("common.zig");
pub const Arguments = struct {
    ctx: *c.Context,
    values: std.StringHashMap([]const []const u8),
    pub fn parse(ctx: *c.Context, args: []const []const u8, allowed: []const []const u8, toggles: []const []const u8) !Arguments {
        var result: Arguments = .{ .ctx = ctx, .values = std.StringHashMap([]const []const u8).init(ctx.allocator) };
        var index: usize = 0;
        while (index < args.len) : (index += 1) {
            const key = args[index];
            try ctx.require(c.oneOf(key, allowed) or c.oneOf(key, toggles), "unknown command argument");
            const toggle = c.oneOf(key, toggles);
            if (!toggle) index += 1;
            try ctx.require(index < args.len, "missing argument value");
            const value = if (toggle) "true" else args[index];
            const old = result.values.get(key) orelse &.{};
            const entries = try ctx.allocator.alloc([]const u8, old.len + 1);
            @memcpy(entries[0..old.len], old);
            entries[old.len] = value;
            try result.values.put(key, entries);
        }
        return result;
    }
    pub fn many(self: Arguments, key: []const u8) []const []const u8 {
        return self.values.get(key) orelse &.{};
    }
    pub fn optional(self: Arguments, key: []const u8) !?[]const u8 {
        const values = self.many(key);
        try self.ctx.require(values.len <= 1, "duplicate command argument");
        return if (values.len == 0) null else values[0];
    }
    pub fn one(self: Arguments, key: []const u8) ![]const u8 {
        return try self.optional(key) orelse return self.ctx.fail("missing argument {s}", .{key});
    }
    pub fn either(self: Arguments, primary: []const u8, alias: []const u8) !?[]const u8 {
        const a = try self.optional(primary);
        const b = try self.optional(alias);
        try self.ctx.require(a == null or b == null, "supply one spelling of an aliased argument");
        return a orelse b;
    }
    pub fn default(self: Arguments, key: []const u8, value: []const u8) ![]const u8 {
        return try self.optional(key) orelse value;
    }
    pub fn flag(self: Arguments, key: []const u8) bool {
        return self.many(key).len > 0;
    }
};
