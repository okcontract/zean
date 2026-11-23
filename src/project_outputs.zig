// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Keep the project's output paths even when its client manifests change.
const std = @import("std");
const c = @import("common.zig");
const files = @import("files.zig");
const Dir = std.Io.Dir;

pub const name = "zean.outputs.json";
const schema = "zean.outputs.v1";

pub const Inventory = struct {
    previous: ?[]const u8 = null,
    paths: []const []const u8 = &.{},
    legacy: bool = true,

    pub fn load(ctx: *c.Context, io: std.Io, repo: Dir) !Inventory {
        const previous = try read(ctx, io, repo) orelse return .{};
        const value = try ctx.parse(previous);
        const retired_field = c.get(value, "retired");
        try ctx.fields(value, if (retired_field != null) "schema outputs retired" else "schema outputs");
        try ctx.require(c.tag(value, "schema", schema), "invalid Zean output inventory");
        const active = try ctx.array(try ctx.field(value, "outputs"));
        try ctx.require(active.len > 0 and active.len <= 256, "invalid Zean output inventory size");
        const retired = if (retired_field) |field| try ctx.array(field) else &.{};
        const paths = try ctx.allocator.alloc([]const u8, active.len + retired.len);
        var seen: std.StringHashMapUnmanaged(void) = .empty;
        defer seen.deinit(ctx.allocator);
        for ([_][]const c.Value{ active, retired }, [_][][]const u8{ paths[0..active.len], paths[active.len..] }) |entries, names| {
            for (entries, names) |entry, *path| {
                path.* = try ctx.str(entry);
                try ctx.require(files.validRelativePath(path.*) and std.mem.endsWith(u8, path.*, ".lean"), "invalid Zean output path");
                if ((try seen.getOrPut(ctx.allocator, path.*)).found_existing)
                    return ctx.fail("duplicate Zean output path {s}", .{path.*});
            }
        }
        return .{ .previous = previous, .paths = paths, .legacy = retired_field == null };
    }

    pub fn checkObsolete(self: Inventory, ctx: *c.Context, io: std.Io, repo: Dir, lean_dir: []const u8, wanted: []const []const u8) !void {
        for (self.paths) |path| {
            if (c.oneOf(path, wanted)) continue;
            const file = files.openContained(io, repo, path) catch |err| switch (err) {
                error.FileNotFound => continue,
                else => return ctx.fail("cannot inspect old Zean output {s} ({s})", .{ path, @errorName(err) }),
            };
            defer file.close(io);
            if (try hasHeader(io, file) and !try aliasesActiveOutput(io, repo, file, wanted))
                return obsolete(ctx, path);
        }
        if (self.legacy) {
            var scan: LegacyScan = .{ .ctx = ctx, .io = io, .repo = repo, .wanted = wanted };
            defer scan.nested.deinit(ctx.allocator);
            try scan.directory(repo, "", if (std.mem.eql(u8, lean_dir, ".")) "" else lean_dir);
        }
    }

    pub fn verify(self: Inventory, ctx: *c.Context, io: std.Io, repo: Dir) !void {
        const current = try read(ctx, io, repo);
        defer if (current) |bytes| ctx.allocator.free(bytes);
        if (!matches(self.previous, current))
            return ctx.fail(name ++ " changed during generation. Run zean again", .{});
    }

    pub fn publish(self: Inventory, ctx: *c.Context, io: std.Io, repo: Dir, bytes: []const u8) !void {
        const replace = self.previous != null;
        var file = try repo.createFileAtomic(io, name, .{ .replace = replace });
        defer file.deinit(io);
        try file.file.writeStreamingAll(io, bytes);
        try self.verify(ctx, io, repo);
        if (replace) try file.replace(io) else try file.link(io);
    }

    pub fn encode(self: Inventory, ctx: *c.Context, active: [][]const u8) ![]const u8 {
        var retired: std.ArrayList([]const u8) = .empty;
        defer retired.deinit(ctx.allocator);
        for (self.paths) |path| {
            if (!c.oneOf(path, active)) try retired.append(ctx.allocator, path);
        }
        std.mem.sort([]const u8, active, {}, less);
        std.mem.sort([]const u8, retired.items, {}, less);
        const bytes = try std.json.Stringify.valueAlloc(ctx.allocator, .{
            .schema = schema,
            .outputs = active,
            .retired = retired.items,
        }, .{ .whitespace = .indent_2 });
        defer ctx.allocator.free(bytes);
        try ctx.require(bytes.len + 1 < c.max_json_bytes, "Zean output inventory exceeds the size limit");
        return ctx.fmt("{s}\n", .{bytes});
    }
};

fn less(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

pub fn matches(expected: ?[]const u8, actual: ?[]const u8) bool {
    if (expected) |bytes| return if (actual) |other| std.mem.eql(u8, bytes, other) else false;
    return actual == null;
}

fn read(ctx: *c.Context, io: std.Io, repo: Dir) !?[]const u8 {
    return files.readContained(ctx, io, repo, name) catch |err| switch (err) {
        error.FileNotFound => null,
        else => ctx.fail("cannot read " ++ name ++ " ({s})", .{@errorName(err)}),
    };
}

fn hasHeader(io: std.Io, file: std.Io.File) !bool {
    var bytes: [files.generated_lean_header.len]u8 = undefined;
    return try file.readPositionalAll(io, &bytes, 0) == bytes.len and std.mem.eql(u8, &bytes, files.generated_lean_header);
}

fn obsolete(ctx: *c.Context, path: []const u8) c.Error {
    return ctx.fail("obsolete Zean output {s}. Remove it or restore its client", .{path});
}

fn aliasesActiveOutput(io: std.Io, repo: Dir, file: std.Io.File, wanted: []const []const u8) !bool {
    // A spelling alias can name the same entry after a rename. Distinct hard
    // links must still be checked because replacing one leaves the other in place.
    if ((try file.stat(io)).nlink != 1) return false;
    const identity = try files.Identity.of(file, io);
    for (wanted) |path| {
        const active = files.openContained(io, repo, path) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        defer active.close(io);
        if (std.meta.eql(identity, try files.Identity.of(active, io))) return true;
    }
    return false;
}

const LegacyScan = struct {
    ctx: *c.Context,
    io: std.Io,
    repo: Dir,
    wanted: []const []const u8,
    nested: std.StringHashMapUnmanaged(void) = .empty,

    fn directory(self: *LegacyScan, dir: Dir, prefix: []const u8, remaining: []const u8) anyerror!void {
        if (prefix.len != 0) try self.recordNested(dir, prefix);
        // Reach leanDir directly so alternate spellings resolve as they do when
        // opening outputs. Along the way, record ownership in its ancestors.
        if (remaining.len != 0) {
            const slash = std.mem.indexOfScalar(u8, remaining, '/') orelse
                return self.child(dir, prefix, remaining, "");
            return self.child(dir, prefix, remaining[0..slash], remaining[slash + 1 ..]);
        }
        var iterator = dir.iterate();
        while (try iterator.next(self.io)) |entry| {
            if (entry.kind == .directory) {
                if (!c.oneOf(entry.name, &.{ ".git", ".lake", ".zig-cache", ".codex-tmp", "zig-out" }))
                    try self.child(dir, prefix, entry.name, "");
                continue;
            }
            if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".lean")) continue;
            const path = try files.join(self.ctx, &.{ prefix, entry.name });
            defer self.ctx.allocator.free(path);
            if (c.oneOf(path, self.wanted) or self.nested.contains(path)) continue;
            const file = try files.openRegular(self.io, dir, entry.name, .none);
            defer file.close(self.io);
            if (try hasHeader(self.io, file) and !try aliasesActiveOutput(self.io, self.repo, file, self.wanted))
                return obsolete(self.ctx, path);
        }
    }

    fn child(self: *LegacyScan, parent: Dir, prefix: []const u8, component: []const u8, remaining: []const u8) !void {
        const dir = parent.openDir(self.io, component, .{ .iterate = true, .follow_symlinks = false }) catch |err| switch (err) {
            error.FileNotFound => return,
            else => return err,
        };
        defer dir.close(self.io);
        const path = try files.join(self.ctx, &.{ prefix, component });
        defer self.ctx.allocator.free(path);
        try self.directory(dir, path, remaining);
    }

    fn recordNested(self: *LegacyScan, dir: Dir, prefix: []const u8) !void {
        const inventory = Inventory.load(self.ctx, self.io, dir) catch |err| {
            const detail = if (err == error.InvalidInput) self.ctx.diagnostic else @errorName(err);
            return self.ctx.fail("{s}/" ++ name ++ " ({s})", .{ prefix, detail });
        };
        for (inventory.paths) |relative| {
            const path = try files.join(self.ctx, &.{ prefix, relative });
            if (c.oneOf(path, self.wanted))
                return self.ctx.fail("generated destination {s} belongs to a nested Zean project", .{path});
            try self.nested.put(self.ctx.allocator, path, {});
        }
    }
};
