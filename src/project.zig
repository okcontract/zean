// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Generate the models declared by a repository's Zean clients.
const std = @import("std");
const c = @import("common.zig");
const client = @import("client.zig");
const Bundle = @import("bundled_compiler.zig").Bundle;
const capture = @import("capture.zig");
const files = @import("files.zig");
const project_outputs = @import("project_outputs.zig");
const checkout = @import("root.zig").project_root;
const Dir = std.Io.Dir;

pub const Options = struct {
    directory: []const u8 = ".",
    toolchain: ?[]const u8 = null,
    evidence: ?[]const u8 = null,
    check: bool = false,
    compiler_payload: []const u8 = &.{},
};

const Config = struct {
    clients: []const []const u8,
    lean_dir: []const u8 = "lean",
    source_map: client.SourceMap = .empty,
    capture_target: ?capture.Target = null,
};

pub fn parseConfig(ctx: *c.Context, bytes: []const u8) !Config {
    const value = try ctx.parse(bytes);
    try ctx.require(c.tag(value, "schema", "zean.project.v1"), "zean.json requires schema zean.project.v1");
    for (value.object.keys()) |key| {
        if (!c.oneOf(key, &.{ "schema", "clients", "leanDir", "sourceMap", "captureTarget" })) return ctx.fail("unknown zean.json field {s}", .{key});
    }
    const entries = try ctx.array(try ctx.field(value, "clients"));
    try ctx.require(entries.len > 0 and entries.len <= 256, "zean.json requires 1-256 client manifests");
    const manifests = try ctx.allocator.alloc([]const u8, entries.len);
    for (entries, 0..) |entry, index| {
        const path = try ctx.str(entry);
        try client.relative(ctx, path);
        try ctx.require(!c.oneOf(path, manifests[0..index]), "duplicate project client manifest");
        manifests[index] = path;
    }
    var config: Config = .{ .clients = manifests };
    if (c.get(value, "leanDir")) |dir| {
        config.lean_dir = try ctx.str(dir);
        if (!std.mem.eql(u8, config.lean_dir, ".")) try client.relative(ctx, config.lean_dir);
        var parts = std.mem.splitScalar(u8, config.lean_dir, '/');
        while (parts.next()) |part| try ctx.require(!std.ascii.eqlIgnoreCase(part, ".git"), "Lean output must be in the working tree");
    }
    if (c.get(value, "sourceMap")) |mappings| {
        try ctx.require(mappings == .object, "sourceMap must map logical Zig paths to repository Zig paths");
        for (mappings.object.keys(), mappings.object.values()) |logical, entry| {
            const actual = try ctx.str(entry);
            try client.relative(ctx, logical);
            try client.relative(ctx, actual);
            try ctx.require(std.mem.endsWith(u8, logical, ".zig") and std.mem.endsWith(u8, actual, ".zig"), "sourceMap requires Zig paths");
            try config.source_map.put(ctx.allocator, logical, .{ .path = actual });
        }
    }
    if (c.get(value, "captureTarget")) |entry| {
        try ctx.fields(entry, "triple cpu");
        const target: capture.Target = .{
            .triple = try ctx.str(try ctx.field(entry, "triple")),
            .cpu = try ctx.str(try ctx.field(entry, "cpu")),
        };
        try target.validate(ctx);
        config.capture_target = target;
    }
    return config;
}

pub const ReplayVisit = enum { visiting, done };

pub fn collectReplayPlans(ctx: *c.Context, io: std.Io, repo: Dir, config: *Config, path: []const u8, ordered: *std.ArrayList(client.Plan), seen: *std.StringHashMap(ReplayVisit)) anyerror!void {
    if (seen.get(path)) |mark| {
        if (mark == .visiting) return ctx.fail("cyclic client dependency at {s}", .{path});
        return;
    }
    try seen.put(path, .visiting);
    const plan = try client.load(ctx, io, repo, path, &config.source_map);
    for (plan.manifest.dependencies) |dependency| {
        if (!c.oneOf(dependency, config.clients)) return ctx.fail("dependency {s} of {s} is not declared in zean.json", .{ dependency, path });
        try collectReplayPlans(ctx, io, repo, config, dependency, ordered, seen);
    }
    try seen.put(path, .done);
    try ordered.append(ctx.allocator, plan);
}

/// Replay a declared client with the same source mapping and capture target
/// used for project generation. Dependencies are captured in dependency order.
/// All replay artifacts go to the evidence path.
pub fn replayClient(ctx: *c.Context, io: std.Io, directory: []const u8, options: client.Options, environment: *const std.process.Environ.Map) !c.Value {
    const repo = Dir.cwd().openDir(io, directory, .{}) catch |err|
        return ctx.fail("cannot open project directory {s} ({s})", .{ directory, @errorName(err) });
    defer repo.close(io);
    const bytes = files.readContained(ctx, io, repo, "zean.json") catch |err| return configError(ctx, "zean.json", err);
    var config = try parseConfig(ctx, bytes);
    defer config.source_map.deinit(ctx.allocator);
    try client.relative(ctx, options.manifest);
    try ctx.require(c.oneOf(options.manifest, config.clients), "client is not declared in zean.json");
    var ordered: std.ArrayList(client.Plan) = .empty;
    var seen: std.StringHashMap(ReplayVisit) = .init(ctx.allocator);
    try collectReplayPlans(ctx, io, repo, &config, options.manifest, &ordered, &seen);
    const result = try client.execute(ctx, io, repo, ordered.items[ordered.items.len - 1], .{
        .toolchain = options.toolchain,
        .output = options.output,
        .capture_target = config.capture_target,
        .verify = true,
        .prerequisites = ordered.items[0 .. ordered.items.len - 1],
        .lake = options.lake,
        .project_config = bytes,
    }, environment);
    return result.report;
}

const Snapshot = struct { identity: files.Identity, sha: [64]u8 };

const Model = struct {
    plan: client.Plan,
    destination: []const u8,
    previous: ?Snapshot = null,
    bytes: []const u8 = &.{},
    input_hashes: []const client.InputHash = &.{},
    changed: bool = false,
};

pub fn run(ctx: *c.Context, io: std.Io, gpa: std.mem.Allocator, options: Options, environment: *const std.process.Environ.Map, output: *std.Io.Writer) !void {
    // Linux opens path-only descriptors unless directory iteration is enabled.
    const repo = Dir.cwd().openDir(io, options.directory, .{ .iterate = true }) catch |err|
        return ctx.fail("cannot open project directory {s} ({s})", .{ options.directory, @errorName(err) });
    defer repo.close(io);
    // Keep the lock stable even when clients switch between client.json and zean.json.
    const lock = files.directoryFile(repo);
    if (!try lock.tryLock(io, .exclusive))
        return ctx.fail("another Zean run is using {s}", .{options.directory});
    defer lock.unlock(io);
    var ownership = try project_outputs.Ownership.init(ctx, io, repo);
    defer ownership.deinit(ctx.allocator, io);

    var config_path: []const u8 = "zean.json";
    const config_file = files.openRegular(io, repo, config_path, .exclusive) catch |err| fallback: {
        if (err != error.FileNotFound) return configError(ctx, config_path, err);
        config_path = "client.json";
        break :fallback files.openRegular(io, repo, config_path, .exclusive) catch |fallback_err| switch (fallback_err) {
            error.FileNotFound => return ctx.fail("no zean.json or client.json in {s}; see zean --help", .{options.directory}),
            else => return configError(ctx, config_path, fallback_err),
        };
    };
    defer config_file.close(io);
    const config_bytes = files.readFile(ctx, io, config_file) catch |err| return configError(ctx, config_path, err);
    var config = if (std.mem.eql(u8, config_path, "zean.json")) try parseConfig(ctx, config_bytes) else Config{ .clients = &.{"client.json"} };

    const models = try ctx.allocator.alloc(Model, config.clients.len);
    for (config.clients, models, 0..) |path, *model, index| {
        const plan = client.load(ctx, io, repo, path, &config.source_map) catch |err| {
            const detail = if (err == error.InvalidInput) ctx.diagnostic else @errorName(err);
            return ctx.fail("{s} ({s})", .{ path, detail });
        };
        const module_path = try ctx.allocator.dupe(u8, plan.manifest.generated);
        std.mem.replaceScalar(u8, module_path, '.', '/');
        const relative = if (std.mem.eql(u8, config.lean_dir, "."))
            try ctx.fmt("{s}.lean", .{module_path})
        else
            try ctx.fmt("{s}/{s}.lean", .{ config.lean_dir, module_path });
        for (models[0..index]) |previous| {
            if (std.ascii.eqlIgnoreCase(previous.destination, relative)) return ctx.fail("multiple clients generate {s}", .{relative});
        }
        model.* = .{ .plan = plan, .destination = relative };
    }
    const paths = try ctx.allocator.alloc([]const u8, models.len);
    for (models, paths) |*model, *path| {
        path.* = model.destination;
        if (try existingModel(ctx, io, repo, model.destination)) |previous| {
            defer ctx.allocator.free(previous.bytes);
            model.previous = previous.snapshot;
        }
    }
    try protectClientInputs(ctx, io, repo, models);
    const inventory = try project_outputs.Inventory.load(ctx, io, repo);
    try inventory.check(ctx, io, ownership, paths);
    const inventory_bytes = try inventory.encode(ctx, paths);
    const inventory_changed = !project_outputs.matches(inventory.previous, inventory_bytes);
    if (options.check and inventory_changed)
        return ctx.fail(project_outputs.name ++ " needs regeneration. Run zean without --check", .{});

    var mappings = config.source_map.iterator();
    while (mappings.next()) |entry| {
        if (!entry.value_ptr.used) return ctx.fail("sourceMap entry {s} is absent from the client source lists", .{entry.key_ptr.*});
    }

    const report = options.toolchain orelse if (options.compiler_payload.len == 0) environment.get("ZEAN_TOOLCHAIN") else null;
    try ctx.require(report != null or options.compiler_payload.len != 0, "use a standalone Zean executable or set ZEAN_TOOLCHAIN to an instrumented Zig report.json");
    const external_report = if (report) |path| try files.absolute(ctx, io, path) else null;
    if (external_report) |path| {
        files.regular(ctx, io, path) catch |err|
            return ctx.fail("cannot open toolchain report {s} ({s})", .{ path, @errorName(err) });
    }
    const evidence = try newEvidence(ctx, io, repo, options.evidence, environment);
    try output.print("Evidence in {s}\n", .{evidence});
    try output.flush();
    try files.write(io, try files.join(ctx, &.{ evidence, config_path }), config_bytes);
    const bundle = if (external_report == null) try Bundle.extract(ctx, io, options.compiler_payload, evidence) else null;
    defer if (bundle) |compiler| compiler.deinit(io);

    for (models, 1..) |*model, number| {
        const run_dir = try ctx.fmt("{s}/client-{d}", .{ evidence, number });
        try output.print("Capturing {s}\n", .{model.plan.path});
        try output.flush();
        var arena: std.heap.ArenaAllocator = .init(gpa);
        defer arena.deinit();
        var replay_ctx: c.Context = .{ .allocator = arena.allocator() };
        const result = client.execute(&replay_ctx, io, repo, model.plan, .{
            .toolchain = external_report orelse bundle.?.report_path,
            .compiler = if (bundle) |compiler| compiler.compiler else null,
            .capture_target = config.capture_target,
            .output = run_dir,
        }, environment) catch |err| {
            const detail = if (err == error.InvalidInput) replay_ctx.diagnostic else @errorName(err);
            return ctx.fail("{s} failed ({s}). See {s}", .{ model.plan.path, detail, run_dir });
        };
        model.bytes = try ctx.allocator.dupe(u8, result.generated);
        model.input_hashes = try ctx.allocator.dupe(client.InputHash, result.input_hashes);
    }

    try client.revalidate(ctx, io, repo, &.{.{ .path = config_path, .sha = c.digest(config_bytes) }});
    if (std.mem.eql(u8, config_path, "client.json")) {
        const new_config = repo.statFile(io, "zean.json", .{ .follow_symlinks = false });
        if (new_config) |_| {
            return ctx.fail("zean.json appeared during generation. Run zean again", .{});
        } else |err| if (err != error.FileNotFound) return err;
    }
    for (models) |*model| {
        try client.revalidate(ctx, io, repo, model.input_hashes);
        const previous = try existingModel(ctx, io, repo, model.destination);
        defer if (previous) |file| ctx.allocator.free(file.bytes);
        try requireUnchanged(ctx, model.*, if (previous) |file| file.snapshot else null);
        model.changed = if (previous) |file| !sameModel(file.bytes, model.bytes) else true;
        if (options.check and model.changed) return ctx.fail("{s} needs regeneration. Run zean without --check", .{model.destination});
    }
    try protectClientInputs(ctx, io, repo, models);
    try inventory.verify(ctx, io, repo);
    try inventory.check(ctx, io, ownership, paths);
    // Record all destinations before publishing any of them so a partial run can be retried.
    if (inventory_changed) try inventory.publish(ctx, io, repo, inventory_bytes);
    for (models) |model| {
        if (model.changed) try publishModel(ctx, io, repo, model);
        try output.print("{s} {s}\n", .{ if (model.changed) "Updated" else "Up to date", model.destination });
    }
    try output.flush();
}

fn configError(ctx: *c.Context, path: []const u8, err: anyerror) c.Error {
    if (err == error.WouldBlock) return ctx.fail("another Zean run is using {s}", .{path});
    return ctx.fail("cannot read {s} ({s})", .{ path, @errorName(err) });
}

const Destinations = std.AutoHashMapUnmanaged(files.Identity, []const u8);

fn protectClientInputs(ctx: *c.Context, io: std.Io, repo: Dir, models: []const Model) !void {
    var destinations: Destinations = .empty;
    defer destinations.deinit(ctx.allocator);
    for (models) |model| {
        if (model.previous) |previous| {
            const entry = try destinations.getOrPut(ctx.allocator, previous.identity);
            if (entry.found_existing) return ctx.fail("multiple clients generate {s}", .{model.destination});
            entry.value_ptr.* = model.destination;
        }
    }
    for (models) |model| {
        try protectPath(ctx, io, repo, models, destinations, model.plan.path, "manifest");
        for (model.plan.inputs) |input| try protectPath(ctx, io, repo, models, destinations, input.actual, "input");
    }
}

fn protectPath(ctx: *c.Context, io: std.Io, repo: Dir, models: []const Model, destinations: Destinations, path: []const u8, kind: []const u8) !void {
    for (models) |model| {
        if (std.ascii.eqlIgnoreCase(model.destination, path))
            return ctx.fail("generated destination {s} overlaps a client {s}", .{ model.destination, kind });
    }
    if (destinations.count() == 0) return;
    const file = files.openContained(io, repo, path) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return ctx.fail("cannot inspect client {s} {s} ({s})", .{ kind, path, @errorName(err) }),
    };
    defer file.close(io);
    if (destinations.get(try files.Identity.of(file, io))) |destination|
        return ctx.fail("generated destination {s} overlaps a client {s}", .{ destination, kind });
}

fn insideCheckout(ctx: *c.Context, io: std.Io, repo: []const u8, path: []const u8) !bool {
    if (files.within(repo, path) or files.within(checkout, path)) return true;
    var directory = path;
    while (true) {
        const marker = try files.join(ctx, &.{ directory, ".git" });
        defer ctx.allocator.free(marker);
        if (try files.exists(io, marker)) return true;
        directory = Dir.path.dirname(directory) orelse return false;
    }
}

/// Resolve aliases through the last existing directory, leaving fresh components to create later.
fn canonicalParent(ctx: *c.Context, io: std.Io, path: []const u8) ![]const u8 {
    const absolute = try files.absolute(ctx, io, path);
    var ancestor = absolute;
    while (true) {
        const real = Dir.realPathFileAbsoluteAlloc(io, ancestor, ctx.allocator) catch |err| switch (err) {
            error.FileNotFound => {
                ancestor = Dir.path.dirname(ancestor) orelse return err;
                continue;
            },
            else => return err,
        };
        if (ancestor.len == absolute.len) return real;
        defer ctx.allocator.free(real);
        return files.join(ctx, &.{ real, std.mem.trimStart(u8, absolute[ancestor.len..], "/") });
    }
}

fn newEvidence(ctx: *c.Context, io: std.Io, repo: Dir, requested: ?[]const u8, environment: *const std.process.Environ.Map) ![]const u8 {
    var root_buffer: [Dir.max_path_bytes]u8 = undefined;
    const repo_path = root_buffer[0..try repo.realPath(io, &root_buffer)];
    const evidence = if (requested) |path| named: {
        const absolute = try files.absolute(ctx, io, path);
        const parent = try canonicalParent(ctx, io, Dir.path.dirname(absolute) orelse
            return ctx.fail("choose a new external evidence directory", .{}));
        break :named try files.join(ctx, &.{ parent, Dir.path.basename(absolute) });
    } else temporary: {
        const temp = environment.get("TMPDIR") orelse "";
        var parent = try canonicalParent(ctx, io, if (temp.len == 0) "/tmp" else temp);
        if (try insideCheckout(ctx, io, repo_path, parent)) parent = try canonicalParent(ctx, io, "/tmp");
        var nonce: [16]u8 = undefined;
        io.random(&nonce);
        break :temporary try files.join(ctx, &.{ parent, try ctx.fmt("zean-{s}", .{std.fmt.bytesToHex(nonce, .lower)}) });
    };
    try ctx.require(!try insideCheckout(ctx, io, repo_path, evidence), "choose an --evidence directory outside the project and Zean checkout");
    const root = try Dir.openDirAbsolute(io, "/", .{});
    defer root.close(io);
    // Walk the canonical path without following links that might have appeared since the check.
    const parent = try files.openParent(io, root, std.mem.trimStart(u8, evidence, "/"), true);
    defer parent.close(io);
    const permissions: Dir.Permissions = if (@hasDecl(Dir.Permissions, "fromMode")) .fromMode(0o700) else .default_dir;
    parent.createDir(io, Dir.path.basename(evidence), permissions) catch |err|
        return ctx.fail("cannot create evidence directory {s} ({s})", .{ evidence, @errorName(err) });
    return evidence;
}

fn existingModel(ctx: *c.Context, io: std.Io, repo: Dir, path: []const u8) !?struct { bytes: []const u8, snapshot: Snapshot } {
    const file = files.openContained(io, repo, path) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return ctx.fail("cannot read generated destination {s} ({s})", .{ path, @errorName(err) }),
    };
    defer file.close(io);
    const bytes = try files.readFile(ctx, io, file);
    errdefer ctx.allocator.free(bytes);
    if (!std.mem.startsWith(u8, bytes, files.generated_lean_header)) {
        return ctx.fail("{s} is not a Zean-generated file. Choose a different leanDir or generatedModule", .{path});
    }
    return .{ .bytes = bytes, .snapshot = .{ .identity = try files.Identity.of(file, io), .sha = c.digest(bytes) } };
}

fn requireUnchanged(ctx: *c.Context, model: Model, previous: ?Snapshot) !void {
    if (!std.meta.eql(model.previous, previous))
        return ctx.fail("{s} changed during generation. Run zean again", .{model.destination});
}

fn publishModel(ctx: *c.Context, io: std.Io, repo: Dir, model: Model) !void {
    const parent = try files.openParent(io, repo, model.destination, true);
    defer parent.close(io);
    const name = Dir.path.basenamePosix(model.destination);
    const exists = model.previous != null;
    var file = try parent.createFileAtomic(io, name, .{ .replace = exists });
    defer file.deinit(io);
    try file.file.writeStreamingAll(io, model.bytes);
    const previous = try existingModel(ctx, io, parent, name);
    defer if (previous) |file_state| ctx.allocator.free(file_state.bytes);
    try requireUnchanged(ctx, model, if (previous) |file_state| file_state.snapshot else null);
    if (exists) try file.replace(io) else try file.link(io);
}

pub fn sameModel(previous: []const u8, fresh: []const u8) bool {
    var old_lines = std.mem.splitScalar(u8, previous, '\n');
    var new_lines = std.mem.splitScalar(u8, fresh, '\n');
    while (old_lines.next()) |old| {
        const new = new_lines.next() orelse return false;
        if (std.mem.eql(u8, old, new)) continue;
        // Keep the hashes of the capture that actually produced a checked-in file.
        for ([_][]const u8{ "-- Capture report SHA-256: ", "-- AIR SHA-256: " }) |marker| {
            if (std.mem.startsWith(u8, old, marker) and std.mem.startsWith(u8, new, marker) and
                c.isDigest(old[marker.len..]) and c.isDigest(new[marker.len..])) break;
        } else return false;
    }
    return new_lines.next() == null;
}
