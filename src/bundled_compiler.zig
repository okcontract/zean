// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Extract the compiler packaged by bundle_tool.zig into private run storage.
const std = @import("std");
const c = @import("common.zig");
const files = @import("files.zig");
const capture = @import("capture.zig");
const Dir = std.Io.Dir;

pub const executable = "zig";
pub const source = "source";
pub const libraries = "libraries";
pub const report = "toolchain.json";

pub const Bundle = struct {
    directory: []const u8,
    compiler: capture.Compiler,
    report_path: []const u8,

    pub fn extract(ctx: *c.Context, io: std.Io, payload: []const u8, evidence: []const u8) !Bundle {
        const directory = try files.join(ctx, &.{ evidence, "compiler" });
        const permissions: Dir.Permissions = if (@hasDecl(Dir.Permissions, "fromMode")) .fromMode(0o700) else .default_dir;
        try Dir.cwd().createDir(io, directory, permissions);
        errdefer Dir.cwd().deleteTree(io, directory) catch {};
        const dir = try Dir.cwd().openDir(io, directory, .{});
        defer dir.close(io);
        var compressed: std.Io.Reader = .fixed(payload);
        var buffer: [std.compress.flate.max_window_len]u8 = undefined;
        var decompressor: std.compress.flate.Decompress = .init(&compressed, .gzip, &buffer);
        // The embedded archive contains only regular files written by the packager.
        try std.tar.extract(io, dir, &decompressor.reader, .{});
        // Retain the original report alongside the run receipts.
        const report_path = try files.join(ctx, &.{ evidence, report });
        try files.write(io, report_path, try files.readContained(ctx, io, dir, report));
        return .{
            .directory = directory,
            .report_path = report_path,
            .compiler = .{
                .executable = try files.join(ctx, &.{ directory, executable }),
                .zig_lib = try files.join(ctx, &.{ directory, source, "lib" }),
                .libraries = try files.join(ctx, &.{ directory, libraries }),
                .bundle_sha256 = c.digest(payload),
            },
        };
    }

    pub fn deinit(self: Bundle, io: std.Io) void {
        Dir.cwd().deleteTree(io, self.directory) catch {};
    }
};
