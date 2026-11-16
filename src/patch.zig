// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const c = @import("common.zig");
const files = @import("files.zig");
const data = @import("patch_data.zig");
pub fn apply(ctx: *c.Context, io: std.Io, source: []const u8, project: []const u8) !c.Value {
    const Change = struct { name: []const u8, before: []const u8, after: []const u8 };
    var changes: std.ArrayList(Change) = .empty;
    for (data.patches) |entry| {
        var selected: ?usize = null;
        for (changes.items, 0..) |change, index| if (std.mem.eql(u8, change.name, entry.file)) {
            selected = index;
            break;
        };
        const original = if (selected) |index| changes.items[index].after else try ctx.read(io, try files.join(ctx, &.{ source, entry.file }), 64 * 1024 * 1024);
        try ctx.require(std.mem.count(u8, original, entry.before) == 1, "fresh-AIR patch anchor is not unique");
        const offset = std.mem.indexOf(u8, original, entry.before).?;
        const replacement = try std.mem.concat(ctx.allocator, u8, &.{ original[0..offset], entry.after, original[offset + entry.before.len ..] });
        if (selected) |index| changes.items[index].after = replacement else try changes.append(ctx.allocator, .{ .name = entry.file, .before = original, .after = replacement });
    }
    for ([_][]const u8{ "SemanticExport.zig", "SemanticValidity.zig" }) |name| try ctx.require(!try files.exists(io, try files.join(ctx, &.{ source, "src", name })), "semantic capture module already present");
    var manifest: c.Value = .{ .array = std.json.Array.init(ctx.allocator) };
    for (changes.items) |change| {
        try files.write(io, try files.join(ctx, &.{ source, change.name }), change.after);
        try manifest.array.append(try ctx.parse(try ctx.json(.{ .file = change.name, .beforeSha256 = &c.digest(change.before), .afterSha256 = &c.digest(change.after) })));
    }
    for ([_][]const u8{ "SemanticExport.zig", "SemanticValidity.zig" }) |name| {
        const body = try ctx.read(io, try files.join(ctx, &.{ project, "lean/zig_air", name }), 16 * 1024 * 1024);
        const relative = try files.join(ctx, &.{ "src", name });
        try files.write(io, try files.join(ctx, &.{ source, relative }), body);
        try manifest.array.append(try ctx.parse(try ctx.json(.{ .file = relative, .beforeSha256 = @as(?[]const u8, null), .afterSha256 = &c.digest(body) })));
    }
    return manifest;
}
