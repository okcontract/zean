// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Generate the models declared by a repository's Zean clients.
const std = @import("std");
const c = @import("common.zig");
const client = @import("client.zig");
const Bundle = @import("bundled_compiler.zig").Bundle;
const files = @import("files.zig");
const toolchain = @import("toolchain.zig");
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
};

fn parseConfig(ctx: *c.Context, bytes: []const u8) !Config {
    const value = try ctx.parse(bytes);
    try ctx.require(c.tag(value, "schema", "zean.project.v1"), "zean.json requires schema zean.project.v1");
    for (value.object.keys()) |key| {
        if (!c.oneOf(key, &.{ "schema", "clients", "leanDir", "sourceMap" })) return ctx.fail("unknown zean.json field {s}", .{key});
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
    return config;
}

const Model = struct {
    plan: client.Plan,
    destination: []const u8,
    previous_sha: ?[64]u8 = null,
    bytes: []const u8 = &.{},
    input_hashes: []const client.InputHash = &.{},
    changed: bool = false,
};

pub fn run(ctx: *c.Context, io: std.Io, gpa: std.mem.Allocator, options: Options, environment: *const std.process.Environ.Map, output: *std.Io.Writer) !void {
    const repo = Dir.cwd().openDir(io, options.directory, .{}) catch |err|
        return ctx.fail("cannot open project directory {s} ({s})", .{ options.directory, @errorName(err) });
    defer repo.close(io);

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
    for (models) |*model| {
        const destination = model.destination;
        for (models) |other| {
            if (std.ascii.eqlIgnoreCase(destination, other.plan.path))
                return ctx.fail("generated destination {s} overlaps a client manifest", .{destination});
            for (other.plan.inputs) |input| {
                if (std.ascii.eqlIgnoreCase(destination, input.actual))
                    return ctx.fail("generated destination {s} overlaps a client input", .{destination});
            }
        }
        if (try existingModel(ctx, io, repo, destination)) |bytes| {
            defer ctx.allocator.free(bytes);
            model.previous_sha = c.digest(bytes);
        }
    }
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
    const evidence = try newEvidence(ctx, io, options.evidence, environment);
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
            .output = run_dir,
        }, environment) catch |err| {
            const detail = if (err == error.InvalidInput) replay_ctx.diagnostic else @errorName(err);
            return ctx.fail("{s} failed ({s}). See {s}", .{ model.plan.path, detail, run_dir });
        };
        model.bytes = try ctx.allocator.dupe(u8, result.generated);
        model.input_hashes = try ctx.allocator.dupe(client.InputHash, result.input_hashes);
    }

    try client.revalidate(ctx, io, repo, &.{.{ .path = config_path, .sha = c.digest(config_bytes) }});
    for (models) |*model| {
        try client.revalidate(ctx, io, repo, model.input_hashes);
        const previous = try existingModel(ctx, io, repo, model.destination);
        defer if (previous) |bytes| ctx.allocator.free(bytes);
        try requireUnchanged(ctx, model.*, previous);
        model.changed = if (previous) |bytes| !sameModel(bytes, model.bytes) else true;
        if (options.check and model.changed) return ctx.fail("{s} needs regeneration. Run zean without --check", .{model.destination});
    }
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

fn newEvidence(ctx: *c.Context, io: std.Io, requested: ?[]const u8, environment: *const std.process.Environ.Map) ![]const u8 {
    if (requested) |path| return toolchain.newOutput(ctx, io, path) catch |err|
        return ctx.fail("cannot create a new evidence directory at {s} ({s})", .{ path, @errorName(err) });
    const temp = environment.get("TMPDIR") orelse "/tmp";
    const parent = try files.absolute(ctx, io, if (temp.len == 0) "/tmp" else temp);
    var nonce: [16]u8 = undefined;
    io.random(&nonce);
    const evidence = try ctx.fmt("{s}/zean-{s}", .{ parent, std.fmt.bytesToHex(nonce, .lower) });
    const permissions: Dir.Permissions = if (@hasDecl(Dir.Permissions, "fromMode")) .fromMode(0o700) else .default_dir;
    Dir.cwd().createDir(io, evidence, permissions) catch |err|
        return ctx.fail("cannot create evidence directory {s} ({s})", .{ evidence, @errorName(err) });
    return evidence;
}

fn existingModel(ctx: *c.Context, io: std.Io, repo: Dir, path: []const u8) !?[]const u8 {
    const bytes = files.readContained(ctx, io, repo, path) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return ctx.fail("cannot read generated destination {s} ({s})", .{ path, @errorName(err) }),
    };
    if (!std.mem.startsWith(u8, bytes, files.generated_lean_header)) {
        ctx.allocator.free(bytes);
        return ctx.fail("{s} is not a Zean-generated file. Choose a different leanDir or generatedModule", .{path});
    }
    return bytes;
}

fn requireUnchanged(ctx: *c.Context, model: Model, previous: ?[]const u8) !void {
    const matches = if (model.previous_sha) |sha|
        previous != null and std.mem.eql(u8, &sha, &c.digest(previous.?))
    else
        previous == null;
    if (!matches) return ctx.fail("{s} changed during verification. Run zean again", .{model.destination});
}

fn publishModel(ctx: *c.Context, io: std.Io, repo: Dir, model: Model) !void {
    const parent = try files.openParent(io, repo, model.destination, true);
    defer parent.close(io);
    const name = Dir.path.basenamePosix(model.destination);
    const exists = model.previous_sha != null;
    var file = try parent.createFileAtomic(io, name, .{ .replace = exists });
    defer file.deinit(io);
    try file.file.writeStreamingAll(io, model.bytes);
    const previous = try existingModel(ctx, io, parent, name);
    defer if (previous) |bytes| ctx.allocator.free(bytes);
    try requireUnchanged(ctx, model, previous);
    if (exists) try file.replace(io) else try file.link(io);
}

fn sameModel(previous: []const u8, fresh: []const u8) bool {
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
