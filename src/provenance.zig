// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Identities embedded by build.zig, not inferred from a runtime checkout.
const c = @import("common.zig");
const std = @import("std");
const runtime = @import("runtime.zig");
const files = @import("files.zig");
const options = @import("build_options");

pub fn identity(ctx: *c.Context) !c.Value {
    return ctx.parse(try ctx.json(.{
        .producer = .{
            .name = "zean",
            .implementation = "Zig",
            .sourceSha256 = options.producer_sha256,
            .sourceFiles = options.producer_files,
        },
        .library = .{
            .leanToolchain = options.lean_toolchain,
            .sourceSha256 = options.model_sha256,
            .sourceFiles = options.model_files,
        },
        .identityScheme = "sorted-path-nul-sha256-lf-v1",
        .identitiesAuthenticated = false,
    }));
}

/// Check that a replay uses the sources identified when this executable was built.
/// This is a consistency check, not authentication of the compiler or source tree.
pub fn verifyWorkspace(ctx: *c.Context, io: std.Io) !void {
    inline for (.{
        .{ "src", &.{ "build.zig", "build.zig.zon" }, options.producer_sha256 },
        .{ "lean", &.{ "lean-toolchain", "lakefile.lean" }, options.model_sha256 },
    }) |group| {
        var names: std.ArrayList([]const u8) = .empty;
        try names.appendSlice(ctx.allocator, group[1]);
        var dir = try std.Io.Dir.cwd().openDir(io, try files.join(ctx, &.{ options.project_root, group[0] }), .{ .iterate = true });
        defer dir.close(io);
        var walker = try dir.walk(ctx.allocator);
        defer walker.deinit();
        while (try walker.next(io)) |entry| {
            try ctx.require(entry.kind == .file or entry.kind == .directory, "unexpected source identity entry");
            if (entry.kind == .file) {
                const name = try ctx.allocator.dupe(u8, try files.join(ctx, &.{ group[0], entry.path }));
                for (name) |*byte| if (byte.* == '\\') {
                    byte.* = '/';
                };
                try names.append(ctx.allocator, name);
            }
        }
        std.mem.sort([]const u8, names.items, {}, struct {
            fn less(_: void, left: []const u8, right: []const u8) bool {
                return std.mem.lessThan(u8, left, right);
            }
        }.less);
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        for (names.items) |name| {
            hash.update(name);
            hash.update(&.{0});
            hash.update(&(try runtime.fileDigest(ctx, io, try files.join(ctx, &.{ options.project_root, name }))));
            hash.update("\n");
        }
        try ctx.require(std.mem.eql(u8, &std.fmt.bytesToHex(hash.finalResult(), .lower), group[2]), "project sources differ from the built executable");
    }
}
