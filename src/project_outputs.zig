// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Keep the project's output paths even when its client manifests change.
const std = @import("std");
const c = @import("common.zig");
const files = @import("files.zig");
const Dir = std.Io.Dir;

pub const name = "zean.outputs.json";
const schema = "zean.outputs.v1";

pub const Ownership = struct {
    repo: Dir,
    enclosing: std.ArrayList(Dir) = .empty,

    /// Keep enclosing projects from publishing new claims while this run is active.
    pub fn init(ctx: *c.Context, io: std.Io, repo: Dir) !Ownership {
        var ownership: Ownership = .{ .repo = repo };
        errdefer ownership.deinit(ctx.allocator, io);
        var ancestor = try repo.openDir(io, ".", .{});
        defer ancestor.close(io);
        var previous = try files.Identity.of(files.directoryFile(ancestor), io);
        while (true) {
            const parent = try ancestor.openDir(io, "..", .{});
            ancestor.close(io);
            ancestor = parent;
            const identity = try files.Identity.of(files.directoryFile(parent), io);
            if (std.meta.eql(previous, identity)) break;
            previous = identity;
            if (!try isProject(io, parent)) continue;
            const owner = try parent.openDir(io, ".", .{ .iterate = true });
            errdefer owner.close(io);
            if (!try files.directoryFile(owner).tryLock(io, .shared))
                return ctx.fail("another Zean run is using an enclosing project", .{});
            try ownership.enclosing.append(ctx.allocator, owner);
        }
        return ownership;
    }

    pub fn deinit(self: *Ownership, allocator: std.mem.Allocator, io: std.Io) void {
        for (self.enclosing.items) |dir| dir.close(io);
        self.enclosing.deinit(allocator);
    }

    fn isProject(io: std.Io, dir: Dir) !bool {
        for ([_][]const u8{ "zean.json", "client.json", name }) |entry| {
            _ = dir.statFile(io, entry, .{ .follow_symlinks = false }) catch |err| switch (err) {
                error.FileNotFound => continue,
                else => return err,
            };
            return true;
        }
        return false;
    }

    fn check(self: Ownership, ctx: *c.Context, io: std.Io, destinations: []const OutputLocation) !void {
        for (self.enclosing.items) |owner| {
            const claims = try readClaims(ctx, io, owner);
            for (destinations) |destination| {
                if (try destination.conflictingPath(io, self.repo, claims, .other_project) != null)
                    return ctx.fail("generated destination {s} belongs to an enclosing Zean project", .{destination.path});
            }
        }
        try checkNestedOwnership(ctx, io, self.repo, destinations);
    }
};

pub const Inventory = struct {
    previous: ?[]const u8 = null,
    paths: []const []const u8 = &.{},

    pub fn load(ctx: *c.Context, io: std.Io, repo: Dir) !Inventory {
        const previous = try read(ctx, io, repo) orelse return .{};
        const value = try ctx.parse(previous);
        try ctx.fields(value, "schema outputs retired");
        try ctx.require(c.tag(value, "schema", schema), "invalid Zean output inventory");
        const active = try ctx.array(try ctx.field(value, "outputs"));
        try ctx.require(active.len > 0 and active.len <= 256, "invalid Zean output inventory size");
        const retired = try ctx.array(try ctx.field(value, "retired"));
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
        return .{ .previous = previous, .paths = paths };
    }

    pub fn check(self: Inventory, ctx: *c.Context, io: std.Io, ownership: Ownership, wanted: []const []const u8) !void {
        const repo = ownership.repo;
        const destinations = try ctx.allocator.alloc(OutputLocation, wanted.len);
        defer ctx.allocator.free(destinations);
        for (wanted, destinations) |path, *destination| {
            try ctx.require(files.validRelativePath(path), "invalid Zean output path");
            destination.* = try OutputLocation.resolve(io, repo, path, .destination);
        }
        try ownership.check(ctx, io, destinations);
        const retiring = try self.resolveClaims(ctx, io, repo, wanted);
        defer ctx.allocator.free(retiring);
        for (destinations) |destination| {
            if (try destination.conflictingPath(io, repo, retiring, .retiring)) |path|
                return ctx.fail("generated destination {s} conflicts with recorded output {s}. One path needs the other as a directory", .{ destination.path, path });
        }
        for (retiring) |claim| {
            if (claim.entry != .file) continue;
            const file = try files.openContained(io, repo, claim.path);
            defer file.close(io);
            if (try hasHeader(io, file) and !try aliasesActiveOutput(io, repo, file, wanted))
                return obsolete(ctx, claim.path);
        }
    }

    fn resolveClaims(self: Inventory, ctx: *c.Context, io: std.Io, repo: Dir, exclude: []const []const u8) ![]OutputLocation {
        var claims: std.ArrayList(OutputLocation) = .empty;
        defer claims.deinit(ctx.allocator);
        for (self.paths) |path| {
            if (c.oneOf(path, exclude)) continue;
            const claim = OutputLocation.resolve(io, repo, path, .claim) catch |err| switch (err) {
                error.NotDir => continue,
                else => return ctx.fail("cannot inspect recorded Zean output {s} ({s})", .{ path, @errorName(err) }),
            };
            try claims.append(ctx.allocator, claim);
        }
        return claims.toOwnedSlice(ctx.allocator);
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
    return containsIdentity(io, repo, wanted, try files.Identity.of(file, io));
}

fn containsIdentity(io: std.Io, repo: Dir, paths: []const []const u8, identity: files.Identity) !bool {
    for (paths) |path| {
        const file = files.openContained(io, repo, path) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        defer file.close(io);
        if (std.meta.eql(identity, try files.Identity.of(file, io))) return true;
    }
    return false;
}

const OutputLocation = struct {
    const Entry = union(enum) { missing, file: files.Identity, blocking_inode: u64, directory: files.Identity };
    const ClaimKind = enum { other_project, retiring };

    // The last reachable parent and the remaining components of the output path.
    parent_id: files.Identity,
    path: []const u8,
    suffix: []const u8,
    entry: Entry,

    fn resolve(io: std.Io, repo: Dir, path: []const u8, role: enum { destination, claim }) !OutputLocation {
        var parent = repo;
        defer if (parent.handle != repo.handle) parent.close(io);
        var components = std.mem.splitScalar(u8, path, '/');
        while (true) {
            const suffix = components.rest();
            const component = components.next() orelse return error.InvalidOutputPath;
            const last = components.peek() == null;
            const entry: Entry = found: {
                const stat = parent.statFile(io, component, .{ .follow_symlinks = false }) catch |err| switch (err) {
                    error.FileNotFound => break :found .missing,
                    else => return err,
                };
                switch (stat.kind) {
                    .directory => {
                        if (last and role == .destination) return error.NotRegularFile;
                        const child = try files.openChildDir(io, parent, component);
                        if (last) {
                            defer child.close(io);
                            break :found .{ .directory = try files.Identity.of(files.directoryFile(child), io) };
                        }
                        if (parent.handle != repo.handle) parent.close(io);
                        parent = child;
                        continue;
                    },
                    .file => {
                        if (!last) {
                            if (role == .destination) return error.NotDir;
                            break :found .{ .blocking_inode = stat.inode };
                        }
                        const file = try files.openRegular(io, parent, component, .none);
                        defer file.close(io);
                        break :found .{ .file = try files.Identity.of(file, io) };
                    },
                    .sym_link => return error.SymLinkLoop,
                    else => return if (last) error.NotRegularFile else error.NotDir,
                }
            };
            return .{
                .parent_id = try files.Identity.of(files.directoryFile(parent), io),
                .path = path,
                .suffix = suffix,
                .entry = entry,
            };
        }
    }

    fn needsNameComparison(self: OutputLocation, claim: OutputLocation, kind: ClaimKind) bool {
        if (!std.meta.eql(self.parent_id, claim.parent_id)) return false;
        return switch (self.entry) {
            // At the same depth below the shared parent, two spellings can name
            // the same file. Only a different depth can require it as a directory.
            .missing => claim.entry == .missing and (kind == .other_project or
                std.mem.countScalar(u8, self.suffix, '/') != std.mem.countScalar(u8, claim.suffix, '/')),
            .file => |id| claim.entry == .blocking_inode and id.inode == claim.entry.blocking_inode,
            else => unreachable, // Only a destination calls this method.
        };
    }

    fn conflictingPath(self: OutputLocation, io: std.Io, repo: Dir, claims: []const OutputLocation, kind: ClaimKind) !?[]const u8 {
        var needs_lookup = false;
        var has_directory_claim = false;
        for (claims) |claim| {
            if (kind == .other_project and self.entry == .file and claim.entry == .file and std.meta.eql(self.entry.file, claim.entry.file)) return claim.path;
            if (claim.entry == .directory) has_directory_claim = true;
            if (!self.needsNameComparison(claim, kind)) continue;
            if (files.within(self.suffix, claim.suffix) or files.within(claim.suffix, self.suffix)) return claim.path;
            needs_lookup = true;
        }
        if (!needs_lookup and !has_directory_claim) return null;
        const entry_path = self.path[0 .. self.path.len - self.suffix.len + std.mem.sliceTo(self.suffix, '/').len];
        const parent = try files.openParent(io, repo, entry_path, false);
        defer parent.close(io);
        if (!std.meta.eql(self.parent_id, try files.Identity.of(files.directoryFile(parent), io)))
            return error.OutputDirectoryChanged;
        if (has_directory_claim) {
            if (try claimedDirectory(io, parent, claims)) |path| return path;
        }
        if (!needs_lookup) return null;

        // A private child inherits the parent's filename lookup rules, including ext4 case folding.
        var nonce: [16]u8 = undefined;
        io.random(&nonce);
        const probe_name = ".zean-lookup-" ++ std.fmt.bytesToHex(nonce, .lower);
        const permissions: Dir.Permissions = if (@hasDecl(Dir.Permissions, "fromMode")) .fromMode(0o700) else .default_dir;
        try parent.createDir(io, probe_name, permissions);
        errdefer parent.deleteTree(io, probe_name) catch {};
        const probe = try files.openChildDir(io, parent, probe_name);
        defer probe.close(io);
        const conflict = try self.lookup(io, probe, claims, kind);
        try parent.deleteTree(io, probe_name);
        return conflict;
    }

    fn claimedDirectory(io: std.Io, parent: Dir, claims: []const OutputLocation) !?[]const u8 {
        var dir = try parent.openDir(io, ".", .{});
        defer dir.close(io);
        var previous: ?files.Identity = null;
        while (true) {
            const id = try files.Identity.of(files.directoryFile(dir), io);
            if (previous) |last| if (std.meta.eql(id, last)) return null;
            for (claims) |claim| {
                if (claim.entry == .directory and std.meta.eql(claim.entry.directory, id)) return claim.path;
            }
            const next = try dir.openDir(io, "..", .{});
            dir.close(io);
            dir = next;
            previous = id;
        }
    }

    fn lookup(self: OutputLocation, io: std.Io, probe: Dir, claims: []const OutputLocation, kind: ClaimKind) !?[]const u8 {
        const leaf = try files.openParent(io, probe, self.suffix, true);
        defer leaf.close(io);
        const marker = try leaf.createFile(io, Dir.path.basenamePosix(self.suffix), .{ .exclusive = true });
        marker.close(io);
        for (claims) |claim| {
            if (!self.needsNameComparison(claim, kind)) continue;
            // The probe contains only the requested path. A lookup can reach its
            // file, stop at one of its directories, or try to descend through its file.
            const file = files.openContained(io, probe, claim.suffix) catch |err| switch (err) {
                error.FileNotFound => continue,
                error.NotDir, error.NotRegularFile => return claim.path,
                else => return err,
            };
            file.close(io);
            return claim.path;
        }
        return null;
    }
};

fn readClaims(ctx: *c.Context, io: std.Io, dir: Dir) ![]const OutputLocation {
    const inventory = Inventory.load(ctx, io, dir) catch |err| {
        const detail = if (err == error.InvalidInput) ctx.diagnostic else @errorName(err);
        var buffer: [Dir.max_path_bytes]u8 = undefined;
        const directory = if (dir.realPath(io, &buffer)) |length| buffer[0..length] else |_| "project directory";
        return ctx.fail("cannot read Zean output inventory in {s} ({s})", .{ directory, detail });
    };
    return inventory.resolveClaims(ctx, io, dir, &.{});
}

fn checkNestedOwnership(ctx: *c.Context, io: std.Io, repo: Dir, destinations: []const OutputLocation) !void {
    var claims_by_directory: std.StringHashMapUnmanaged([]const OutputLocation) = .empty;
    defer claims_by_directory.deinit(ctx.allocator);
    for (destinations) |destination| {
        const path = destination.path;
        var ancestor: ?Dir = null;
        defer if (ancestor) |dir| dir.close(io);
        var components = std.mem.splitScalar(u8, path, '/');
        while (components.next()) |component| {
            const relative = components.rest();
            if (relative.len == 0) break;
            const dir = (ancestor orelse repo).openDir(io, component, .{ .follow_symlinks = false }) catch |err| switch (err) {
                error.FileNotFound => break,
                else => return err,
            };
            if (ancestor) |previous| previous.close(io);
            ancestor = dir;

            const prefix = path[0 .. path.len - relative.len - 1];
            const entry = try claims_by_directory.getOrPut(ctx.allocator, prefix);
            if (!entry.found_existing) entry.value_ptr.* = try readClaims(ctx, io, dir);
            if (try destination.conflictingPath(io, repo, entry.value_ptr.*, .other_project) != null)
                return ctx.fail("generated destination {s} belongs to a nested Zean project", .{path});
        }
    }
}
