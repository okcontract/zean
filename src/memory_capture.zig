// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Join compiler observations to the source inventory only on an exact span and digest.
const std = @import("std");
const c = @import("common.zig");
const files = @import("files.zig");
const Str = []const u8;

fn locate(ctx: *c.Context, inventory: c.Value, source: c.Value) !?Str {
    const name = try ctx.str(try ctx.field(source, "file"));
    const digest = try ctx.str(try ctx.field(source, "sha256"));
    const span = try ctx.field(source, "span");
    var found: ?Str = null;
    var it = inventory.object.iterator();
    while (it.next()) |entry| {
        if (!std.mem.eql(u8, std.fs.path.basename(entry.key_ptr.*), std.fs.path.basename(name)) or
            !c.tag(entry.value_ptr.*, "sha256", digest)) continue;
        for (try ctx.array(try ctx.field(entry.value_ptr.*, "sites"))) |site| {
            if (!c.tag(site, "operation", "slice")) continue;
            if (!c.equal(try ctx.field(site, "expressionStart"), try ctx.field(span, "start")) or
                !c.equal(try ctx.field(site, "expressionEnd"), try ctx.field(span, "end")) or
                !c.equal(try ctx.field(site, "startByte"), try ctx.field(span, "main"))) continue;
            if (found != null) return null;
            found = try ctx.str(try ctx.field(site, "id"));
        }
    }
    return found;
}

pub fn collect(ctx: *c.Context, io: std.Io, inventory: c.Value, captures: []const Str) !c.Value {
    var observations: std.ArrayList(c.Value) = .empty;
    for (captures) |path| {
        const report = try ctx.parse(try ctx.read(io, path, c.max_json_bytes));
        try ctx.require(c.tag(report, "schema", "oksolc.fresh-air-capture.v1") and c.tag(report, "status", "captured"), "invalid memory capture");
        const roots = try ctx.field(report, "functions");
        try ctx.require(roots == .object, "missing capture roots");
        var it = roots.object.iterator();
        while (it.next()) |entry| {
            const ref = entry.value_ptr.*;
            const name = try ctx.str(try ctx.field(ref, "file"));
            const relative = try files.join(ctx, &.{ "air", name });
            const raw = try ctx.read(io, try files.closureMember(ctx, io, std.fs.path.dirname(path) orelse ".", relative), c.max_json_bytes);
            const digest = c.digest(raw);
            try ctx.require(c.tag(ref, "sha256", &digest), "captured AIR digest mismatch");
            const air = try ctx.parse(raw);
            try ctx.require(c.tag(air, "schema", "oksolc.fresh-air.v3") and c.tag(air, "name", entry.key_ptr.*), "captured root mismatch");
            var spans: std.ArrayList(c.Value) = .empty;
            const validity = try ctx.field(air, "sourceValidity");
            for (try ctx.array(try ctx.field(validity, "slices"))) |slice| {
                const source = try ctx.field(slice, "source");
                try spans.append(ctx.allocator, try ctx.parse(try ctx.json(.{
                    .site = try locate(ctx, inventory, source),
                    .source = source,
                    .anchor = try ctx.field(slice, "anchor"),
                    .unsupported = try ctx.field(slice, "unsupportedReason"),
                })));
            }
            var tags: c.Value = .{ .object = .empty };
            for (try ctx.array(try ctx.field(air, "instructions"))) |instruction| {
                const tag = try ctx.str(try ctx.field(instruction, "tag"));
                const counter = try tags.object.getOrPut(ctx.allocator, tag);
                if (!counter.found_existing) counter.value_ptr.* = .{ .integer = 0 };
                counter.value_ptr.integer += 1;
            }
            try observations.append(ctx.allocator, try ctx.parse(try ctx.json(.{
                .root = entry.key_ptr.*,
                .airSha256 = &digest,
                .target = try ctx.field(report, "captureTarget"),
                .optimize = try ctx.field(try ctx.field(air, "configuration"), "optimize"),
                .spans = spans.items,
                .airTags = tags,
                .coverageComplete = false,
            })));
        }
    }
    return ctx.parse(try ctx.json(observations.items));
}
