// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Preserve source evidence for standard-library declarations reached by AIR.
//! This is a manifest of captured declarations, not a complete import closure.
const std = @import("std");
const c = @import("common.zig");
const files = @import("files.zig");
const runtime = @import("runtime.zig");

pub fn collect(ctx: *c.Context, io: std.Io, lib: []const u8, output: []const u8, functions: c.Value, hashes: *c.Value) !void {
    for (functions.object.values()) |entry| {
        const filename = try ctx.str(try ctx.field(entry, "file"));
        try ctx.require(std.mem.eql(u8, filename, std.fs.path.basename(filename)) and std.mem.endsWith(u8, filename, ".json"), "unsafe captured AIR filename");
        const path = try files.join(ctx, &.{ output, "air", filename });
        const captured = try files.readJson(ctx, io, path);
        try ctx.require(c.tag(entry, "sha256", &c.digest(captured.bytes)), "captured AIR changed before source collection");
        const record = captured.value;
        const source = try ctx.str(try ctx.field(record, "sourceFile"));
        const sha = try ctx.str(try ctx.field(record, "sourceSha256"));
        try ctx.require(runtime.safeArchiveName(source) and std.mem.endsWith(u8, source, ".zig") and c.isDigest(sha), "unsafe captured declaration source identity");
        if (hashes.object.get(source)) |prior| {
            try ctx.require(c.tag(record, "sourceSha256", try ctx.str(prior)), "conflicting captured source identities");
            continue;
        }
        const original = try files.join(ctx, &.{ lib, "std", source });
        try files.regular(ctx, io, original);
        const bytes = try ctx.read(io, original, 64 * 1024 * 1024);
        try ctx.require(std.mem.eql(u8, sha, &c.digest(bytes)), "captured declaration is outside the supplied source and standard-library trees");
        const destination = try files.join(ctx, &.{ output, source });
        try std.Io.Dir.cwd().createDirPath(io, std.fs.path.dirname(destination).?);
        try files.write(io, destination, bytes);
        try hashes.object.put(ctx.allocator, source, .{ .string = sha });
    }
}
