// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const c = @import("common.zig");

pub fn readJson(ctx: *c.Context, io: std.Io, path: []const u8) !struct { bytes: []const u8, value: c.Value } {
    const bytes = try ctx.read(io, path, c.max_json_bytes + 1);
    return .{ .bytes = bytes, .value = try ctx.parse(bytes) };
}
pub fn exists(io: std.Io, path: []const u8) !bool {
    _ = std.Io.Dir.cwd().statFile(io, path, .{ .follow_symlinks = false }) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => return err,
    };
    return true;
}
pub fn regular(ctx: *c.Context, io: std.Io, path: []const u8) !void {
    const stat = try std.Io.Dir.cwd().statFile(io, path, .{ .follow_symlinks = false });
    try ctx.require(stat.kind == .file, "captured AIR must be a regular file");
}
/// Resolve an explicit closure member without following any relative symlink.
/// The caller chooses the trusted base directory; every member component is
/// normalized and checked before the file is read.
pub fn closureMember(ctx: *c.Context, io: std.Io, base: []const u8, relative: []const u8) ![]const u8 {
    try ctx.require(@import("runtime.zig").safeArchiveName(relative), "invalid captured source path");
    var parts = std.mem.splitScalar(u8, relative, '/');
    var path = base;
    while (parts.next()) |part| {
        try ctx.require(part.len > 0 and !std.mem.eql(u8, part, "."), "captured source path must be normalized");
        path = try join(ctx, &.{ path, part });
        const stat = try std.Io.Dir.cwd().statFile(io, path, .{ .follow_symlinks = false });
        try ctx.require(if (parts.peek() == null) stat.kind == .file else stat.kind == .directory, "captured source path contains a link or special file");
    }
    return path;
}
pub fn write(io: std.Io, path: []const u8, bytes: []const u8) !void {
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = bytes });
}
pub fn join(ctx: *c.Context, parts: []const []const u8) ![]const u8 {
    return std.fs.path.join(ctx.allocator, parts);
}
pub const Artifact = struct { name: []const u8, bytes: []const u8 };

pub fn publish(ctx: *c.Context, io: std.Io, output: []const u8, artifacts: []const Artifact) !void {
    try ctx.require(!try exists(io, output), "output directory already exists; use a new directory");
    const parent = std.fs.path.dirname(output) orelse ".";
    try std.Io.Dir.cwd().createDirPath(io, parent);
    var nonce: [16]u8 = undefined;
    io.random(&nonce);
    const staging = try join(ctx, &.{ parent, try ctx.fmt(".zean-{s}", .{std.fmt.bytesToHex(nonce, .lower)}) });
    try std.Io.Dir.cwd().createDir(io, staging, .default_dir);
    defer std.Io.Dir.cwd().deleteTree(io, staging) catch {};
    for (artifacts) |artifact| {
        const dot = std.mem.lastIndexOfScalar(u8, artifact.name, '.') orelse return ctx.fail("artifact needs a Lean or JSON extension", .{});
        try ctx.require(c.identifier(artifact.name[0..dot], false) and c.oneOf(artifact.name[dot..], &.{ ".lean", ".json" }), "invalid artifact name");
        try write(io, try join(ctx, &.{ staging, artifact.name }), artifact.bytes);
    }
    try std.Io.Dir.renamePreserve(.cwd(), staging, .cwd(), output, io);
}
