// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Snapshot inputs and stream hash-checked verification evidence.
const std = @import("std");
const c = @import("common.zig");
const files = @import("files.zig");
const runtime = @import("runtime.zig");

pub const Bundle = struct {
    ctx: *c.Context,
    io: std.Io,
    output: []const u8,
    input_root: []const u8,
    hashes: c.Value = .{ .object = .empty },
    inputs: c.Value = .{ .object = .empty },

    pub fn path(self: *Bundle, relative: []const u8) ![]const u8 {
        return files.join(self.ctx, &.{ self.output, relative });
    }
    pub fn remember(self: *Bundle, relative: []const u8) !void {
        const hash = try runtime.fileDigest(self.ctx, self.io, try self.path(relative));
        try self.hashes.object.put(self.ctx.allocator, relative, .{ .string = try self.ctx.allocator.dupe(u8, &hash) });
    }
    pub fn write(self: *Bundle, relative: []const u8, bytes: []const u8) !void {
        const destination = try self.path(relative);
        try std.Io.Dir.cwd().createDirPath(self.io, std.fs.path.dirname(destination).?);
        try files.write(self.io, destination, bytes);
        try self.remember(relative);
    }
    pub fn input(self: *Bundle, relative: []const u8) ![]const u8 {
        const bytes = try self.ctx.read(self.io, try files.join(self.ctx, &.{ self.input_root, relative }), c.max_json_bytes);
        const identity = c.digest(bytes);
        if (self.inputs.object.get(relative)) |previous|
            try self.ctx.require(c.stringIs(previous, &identity), "verification input changed after its first snapshot");
        try self.inputs.object.put(self.ctx.allocator, relative, .{ .string = try self.ctx.allocator.dupe(u8, &identity) });
        try self.write(try self.ctx.fmt("inputs/{s}", .{relative}), bytes);
        return bytes;
    }
    pub fn unchanged(self: *Bundle) !void {
        var iterator = self.inputs.object.iterator();
        while (iterator.next()) |entry| try self.ctx.require(c.stringIs(entry.value_ptr.*, &(try runtime.fileDigest(self.ctx, self.io, try files.join(self.ctx, &.{ self.input_root, entry.key_ptr.* })))), "verification input changed during regeneration");
        iterator = self.hashes.object.iterator();
        while (iterator.next()) |entry| try self.ctx.require(c.stringIs(entry.value_ptr.*, &(try runtime.fileDigest(self.ctx, self.io, try self.path(entry.key_ptr.*)))), "verification evidence changed during regeneration");
    }
    pub fn receipt(self: *Bundle, label: []const u8) !void {
        for ([_][]const u8{ "stdout", "stderr", "process.json" }) |extension| try self.remember(try self.ctx.fmt("{s}.{s}", .{ label, extension }));
    }
};

/// Hash exactly the bytes streamed into the archive. Compiled proof modules
/// can exceed the source/JSON read limit and must not accumulate in the arena.
pub fn archiveFile(ctx: *c.Context, io: std.Io, tar: *std.tar.Writer, path: []const u8, name: []const u8, expected: []const u8) !void {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    var reader = file.reader(io, &.{});
    var hashed = reader.interface.hashed(std.crypto.hash.sha2.Sha256.init(.{}), &.{});
    try tar.writeFileStream(name, try reader.getSize(), &hashed.reader, .{});
    var digest: [32]u8 = undefined;
    hashed.hasher.final(&digest);
    try ctx.require(std.mem.eql(u8, expected, &std.fmt.bytesToHex(digest, .lower)), "verification evidence changed during archiving");
}
