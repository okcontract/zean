// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Retained sources for slice guards inlined into another declaration's AIR.
const std = @import("std");
const c = @import("common.zig");
const files = @import("files.zig");

pub const Identities = std.StringHashMapUnmanaged(struct { sha: [64]u8, size: usize });

pub const Sources = struct {
    directory: []const u8,
    inventory: ?c.Value,
    checked: Identities = .empty,

    pub fn forRecord(self: *Sources, ctx: *c.Context, io: std.Io, record: c.Value) !*const Identities {
        const owner = try ctx.str(try ctx.field(record, "sourceFile"));
        const validity = try ctx.field(record, "sourceValidity");
        const guards = try ctx.array(try ctx.field(validity, "slices"));
        try ctx.require(guards.len <= 512, "unsupported memory source-validity inventory");
        for (guards) |guard| {
            const source = try ctx.field(guard, "source");
            const file = try ctx.str(try ctx.field(source, "file"));
            if (std.mem.eql(u8, owner, file) or self.checked.contains(file)) continue;
            const inventory = self.inventory orelse return ctx.fail("inline slice guard requires a captured source inventory", .{});
            const identity = c.get(inventory, file) orelse return ctx.fail("inline slice guard source {s} is outside the capture inventory", .{file});
            const path = try files.closureMember(ctx, io, self.directory, file);
            const bytes = try ctx.read(io, path, 64 * 1024 * 1024);
            defer ctx.allocator.free(bytes);
            const sha = c.digest(bytes);
            try ctx.require(c.stringIs(identity, &sha), "inline slice guard source differs from the capture inventory");
            try self.checked.put(ctx.allocator, file, .{ .sha = sha, .size = bytes.len });
        }
        return &self.checked;
    }

    pub fn revalidate(self: *const Sources, ctx: *c.Context, io: std.Io) !void {
        var entries = self.checked.iterator();
        while (entries.next()) |entry| {
            const path = try files.closureMember(ctx, io, self.directory, entry.key_ptr.*);
            const sha = try @import("runtime.zig").fileDigest(ctx, io, path);
            try ctx.require(std.mem.eql(u8, &sha, &entry.value_ptr.sha), "inline slice guard source changed during translation");
        }
    }
};
