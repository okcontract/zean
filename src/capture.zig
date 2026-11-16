// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Explicit source closure and provenance-bound native AIR capture.
const std = @import("std");
const c = @import("common.zig");
const files = @import("files.zig");
const source = @import("source.zig");
const runtime = @import("runtime.zig");
const toolchain = @import("toolchain.zig");
const z = @import("root.zig");
pub const Options = struct { toolchain: []const u8, source: []const u8, output: []const u8, roots: []const []const u8, extra_sources: []const []const u8 = &.{}, source_base: []const u8 = ".", modules: []const []const u8 = &.{}, mode: []const u8 = "ReleaseFast", environment: ?*const std.process.Environ.Map = null };
fn relativeZig(path: []const u8) bool {
    return runtime.safeArchiveName(path) and std.mem.endsWith(u8, path, ".zig");
}
fn normalized(ctx: *c.Context, path: []const u8) ![]const u8 {
    try ctx.require(relativeZig(path), "invalid capture source path");
    const result = try std.fs.path.resolvePosix(ctx.allocator, &.{ "/", path });
    return std.mem.trimStart(u8, result, "/");
}
pub fn moduleBindings(ctx: *c.Context, entries: []const []const u8) !c.Value {
    var result: c.Value = .{ .object = .empty };
    for (entries) |entry| {
        const separator = std.mem.indexOfScalar(u8, entry, '=') orelse return ctx.fail("module must be NAME=path.zig", .{});
        const name = entry[0..separator];
        const path = try normalized(ctx, entry[separator + 1 ..]);
        try ctx.require(source.plainIdentifier(name) and !c.oneOf(name, &.{ "root", "std", "builtin" }) and relativeZig(path) and !result.object.contains(name), "invalid or duplicate module binding");
        for (result.object.values()) |value| try ctx.require(!std.mem.eql(u8, path, value.string), "module source has multiple identities");
        try result.object.put(ctx.allocator, name, .{ .string = path });
    }
    return c.ordered(ctx, result);
}
fn isModule(modules: c.Value, path: []const u8) bool {
    for (modules.object.values()) |value| if (std.mem.eql(u8, value.string, path)) return true;
    return false;
}
pub fn sourceFiles(ctx: *c.Context, io: std.Io, root: []const u8, extras: []const []const u8, modules: c.Value) !c.Value {
    return sourceFilesAt(ctx, io, ".", root, extras, modules);
}
pub fn sourceFilesAt(ctx: *c.Context, io: std.Io, base: []const u8, root: []const u8, extras: []const []const u8, modules: c.Value) !c.Value {
    var result: c.Value = .{ .object = .empty };
    const basename = std.fs.path.basename(root);
    try ctx.require(relativeZig(basename), "expected a Zig source");
    try result.object.put(ctx.allocator, basename, .{ .string = try ctx.read(io, if (std.fs.path.isAbsolute(root)) root else try files.join(ctx, &.{ base, root }), 64 * 1024 * 1024) });
    for (extras) |raw_path| {
        const path = try normalized(ctx, raw_path);
        try ctx.require(relativeZig(path) and !result.object.contains(path), "invalid or duplicate explicit source path");
        try result.object.put(ctx.allocator, path, .{ .string = try ctx.read(io, try files.join(ctx, &.{ base, path }), 64 * 1024 * 1024) });
    }
    for (modules.object.values()) |value| try ctx.require(result.object.contains(value.string) and !std.mem.eql(u8, value.string, basename), "module missing from explicit source closure");
    var entries = result.object.iterator();
    while (entries.next()) |entry| {
        const bytes = entry.value_ptr.string;
        const name = entry.key_ptr.*;
        try source.validateAst(ctx, bytes);
        const tokens = try source.tokenize(ctx, bytes);
        for (tokens, 0..) |token, index| {
            if (!std.mem.eql(u8, token.text, "@import")) continue;
            try ctx.require(index + 3 < tokens.len and std.mem.eql(u8, tokens[index + 1].text, "(") and tokens[index + 2].tag == .string_literal and std.mem.eql(u8, tokens[index + 3].text, ")"), "nonstatic capture source import");
            const imported = try source.importName(ctx, tokens[index + 2].text);
            if (c.oneOf(imported, &.{ "std", "builtin" })) continue;
            try ctx.require(!isModule(modules, name), "capture named modules must be self-contained leaves");
            if (modules.object.contains(imported)) continue;
            try ctx.require(!std.fs.path.isAbsolute(imported) and std.mem.indexOfScalar(u8, imported, '\\') == null, "invalid local import");
            const joined = try std.fs.path.resolvePosix(ctx.allocator, &.{ "/", std.fs.path.dirname(name) orelse "", imported });
            const resolved = std.mem.trimStart(u8, joined, "/");
            try ctx.require(result.object.contains(resolved), "capture source import missing from explicit closure");
            try ctx.require(!isModule(modules, resolved), "capture module imported by both name and path");
        }
    }
    return result;
}
pub fn inspectRecords(ctx: *c.Context, io: std.Io, directory: []const u8, roots: []const []const u8, source_sha: []const u8, mode: []const u8) !c.Value {
    try uniqueRoots(ctx, roots);
    var result: c.Value = .{ .object = .empty };
    var dir = try std.Io.Dir.cwd().openDir(io, directory, .{ .iterate = true });
    defer dir.close(io);
    var iterator = dir.iterate();
    while (try iterator.next(io)) |entry| {
        try ctx.require(entry.kind == .file and std.mem.endsWith(u8, entry.name, ".json"), "unexpected capture directory entry");
        const raw = try ctx.read(io, try files.join(ctx, &.{ directory, entry.name }), c.max_json_bytes);
        const record = try ctx.parse(raw);
        try ctx.require(c.tag(record, "schema", "oksolc.fresh-air.v3") and c.tag(record, "capturePoint", "after-sema-before-legalize") and c.flag(record, "sourceValidityConditionsPreserved", false), "unexpected capture schema, phase, or validity claim");
        const name = try ctx.str(try ctx.field(record, "name"));
        try ctx.require(name.len > 0 and !result.object.contains(name), "missing or duplicate captured function");
        const validity = try ctx.field(record, "sourceValidity");
        try ctx.fields(validity, "schema coverage complete slices");
        try ctx.require(c.tag(validity, "schema", "oksolc.source-validity.v1") and c.tag(validity, "coverage", "runtime-slice-results") and c.flag(validity, "complete", false), "unsupported source-validity inventory");
        const slices = try ctx.array(try ctx.field(validity, "slices"));
        const tags = try ctx.array(try ctx.field(record, "sourceOperationTags"));
        try ctx.require(tags.len > 0, "missing source-operation inventory");
        for (tags, 0..) |tag, index| {
            const text = try ctx.str(tag);
            for (tags[0..index]) |old| try ctx.require(!std.mem.eql(u8, text, try ctx.str(old)), "duplicate source-operation tag");
        }
        const instructions = try ctx.array(try ctx.field(record, "instructions"));
        const body = try ctx.array(try ctx.field(record, "body"));
        var unsupported: usize = 0;
        for (instructions, 0..) |instruction, index| {
            try ctx.require(try ctx.nat(try ctx.field(instruction, "index"), 1000000) == index, "malformed AIR instruction index");
            _ = try ctx.str(try ctx.field(instruction, "tag"));
            if (c.flag(instruction, "unsupportedPayload", true)) unsupported += 1;
        }
        for (body) |ref| try ctx.require(try ctx.nat(ref, 1000000) < instructions.len, "out-of-range AIR body reference");
        const requested = c.oneOf(name, roots);
        if (requested) {
            try ctx.require(c.tag(record, "sourceSha256", source_sha), "requested root source hash mismatch");
            const config = try ctx.field(record, "configuration");
            try ctx.require(c.tag(config, "optimize", mode) and c.flag(config, "useLlvm", true) and c.flag(config, "isTest", false), "requested root build configuration mismatch");
        }
        const summary = try ctx.parse(try ctx.json(.{ .file = entry.name, .sha256 = &c.digest(raw), .requested = requested, .instructionCount = instructions.len, .sourceOperationTags = tags, .sourceValiditySliceCount = slices.len, .unsupportedPayloadCount = unsupported }));
        try result.object.put(ctx.allocator, try ctx.allocator.dupe(u8, name), summary);
    }
    for (roots) |name| try ctx.require(result.object.contains(name), "missing requested AIR root");
    return result;
}
pub fn uniqueRoots(ctx: *c.Context, roots: []const []const u8) !void {
    try ctx.require(roots.len > 0, "expected nonempty requested roots");
    for (roots, 0..) |name, index| try ctx.require(name.len > 0 and !c.oneOf(name, roots[0..index]), "empty or duplicate requested root");
}
pub fn run(ctx: *c.Context, io: std.Io, options: Options) !c.Value {
    const output = try toolchain.newOutput(ctx, io, options.output);
    var report = try ctx.parse(try ctx.json(.{ .schema = "oksolc.fresh-air-capture.v1", .status = "failed", .captureComplete = false, .zigVersion = z.version, .zigRevision = z.revision, .inputKind = "native-capture", .compilerVerified = false, .semanticExportImplemented = false, .sourceClosureComplete = false }));
    defer files.write(io, files.join(ctx, &.{ output, "report.json" }) catch unreachable, ctx.json(report) catch "{\"status\":\"failed\"}") catch {};
    return captureInto(ctx, io, options, output, &report) catch |err| {
        toolchain.set(ctx, &report, "status", "failed") catch {};
        toolchain.set(ctx, &report, "error", if (err == error.InvalidInput) ctx.diagnostic else @errorName(err)) catch {};
        return err;
    };
}
fn captureInto(ctx: *c.Context, io: std.Io, options: Options, output: []const u8, report: *c.Value) !c.Value {
    try uniqueRoots(ctx, options.roots);
    try ctx.require(c.oneOf(options.mode, &.{ "Debug", "ReleaseSafe", "ReleaseFast" }), "unsupported build mode");
    const toolchain_bytes = try ctx.read(io, options.toolchain, c.max_json_bytes);
    const provenance = try ctx.parse(toolchain_bytes);
    try ctx.require(c.oneOf(try ctx.str(try ctx.field(provenance, "status")), &.{ "built", "built-with-diagnostics" }) and c.flag(provenance, "freshAirCaptureImplemented", true) and c.tag(provenance, "zigRevision", z.revision), "toolchain has no completed pinned fresh-AIR build");
    const compiler_record = try ctx.field(provenance, "compiler");
    try ctx.require(c.tag(compiler_record, "version", z.version), "toolchain compiler version mismatch");
    const compiler = try ctx.str(try ctx.field(compiler_record, "path"));
    const lib = try ctx.str(try ctx.field(compiler_record, "zigLibDir"));
    const compiler_hash = try runtime.fileDigest(ctx, io, compiler);
    try ctx.require(c.tag(compiler_record, "sha256", &compiler_hash) and c.equal(try runtime.sourceIdentity(ctx, io, std.fs.path.dirname(lib).?), try ctx.field(provenance, "sourceTree")), "toolchain input hash mismatch");
    try toolchain.set(ctx, report, "toolchainReportSha256", &c.digest(toolchain_bytes));
    try toolchain.set(ctx, report, "compilerSha256", &compiler_hash);
    const modules = try moduleBindings(ctx, options.modules);
    const sources = try sourceFilesAt(ctx, io, options.source_base, options.source, options.extra_sources, modules);
    if (modules.object.count() > 0) try toolchain.set(ctx, report, "sourceModules", modules);
    var hashes: c.Value = .{ .object = .empty };
    var source_iter = sources.object.iterator();
    while (source_iter.next()) |entry| {
        const name = entry.key_ptr.*;
        const bytes = entry.value_ptr.string;
        const destination = try files.join(ctx, &.{ output, name });
        try std.Io.Dir.cwd().createDirPath(io, std.fs.path.dirname(destination).?);
        try files.write(io, destination, bytes);
        try hashes.object.put(ctx.allocator, name, .{ .string = try ctx.allocator.dupe(u8, &c.digest(bytes)) });
    }
    try toolchain.set(ctx, report, "sourceFiles", hashes);
    const basename = std.fs.path.basename(options.source);
    const fixture = try files.join(ctx, &.{ output, basename });
    const source_sha = c.digest(sources.object.get(basename).?.string);
    try toolchain.set(ctx, report, "sourceSha256", &source_sha);
    const directory = try files.join(ctx, &.{ output, "air" });
    try std.Io.Dir.cwd().createDir(io, directory, .default_dir);
    var common: std.ArrayList([]const u8) = .empty;
    try common.appendSlice(ctx.allocator, &.{ compiler, "build-obj", "--zig-lib-dir", lib, "-fllvm", "-fno-incremental", "-fstrip", try ctx.fmt("-O{s}", .{options.mode}) });
    if (modules.object.count() == 0) try common.append(ctx.allocator, fixture) else {
        for (modules.object.keys()) |name| try common.appendSlice(ctx.allocator, &.{ "--dep", name });
        try common.append(ctx.allocator, try ctx.fmt("-Mroot={s}", .{fixture}));
        var iter = modules.object.iterator();
        while (iter.next()) |entry| try common.appendSlice(ctx.allocator, &.{ try ctx.fmt("-O{s}", .{options.mode}), "-fstrip", try ctx.fmt("-M{s}={s}", .{ entry.key_ptr.*, try files.join(ctx, &.{ output, entry.value_ptr.string }) }) });
    }
    try common.appendSlice(ctx.allocator, &.{ "--global-cache-dir", try files.join(ctx, &.{ output, "global-cache" }) });
    const runner: runtime.Runner = .{ .ctx = ctx, .io = io, .output = output };
    var captured: std.ArrayList([]const u8) = .empty;
    try captured.appendSlice(ctx.allocator, common.items);
    try captured.appendSlice(ctx.allocator, &.{ "--cache-dir", try files.join(ctx, &.{ output, "capture-cache" }), try ctx.fmt("-femit-bin={s}/captured.o", .{output}), try ctx.fmt("--semantic-export={s}", .{directory}) });
    try runner.run("capture", captured.items, .{ .environ = options.environment });
    const functions = try inspectRecords(ctx, io, directory, options.roots, &source_sha, options.mode);
    try toolchain.set(ctx, report, "functions", functions);
    try @import("capture_stdlib.zig").collect(ctx, io, lib, output, functions, &hashes);
    try toolchain.set(ctx, report, "sourceFiles", hashes);
    var ordinary: std.ArrayList([]const u8) = .empty;
    try ordinary.appendSlice(ctx.allocator, common.items);
    try ordinary.appendSlice(ctx.allocator, &.{ "--cache-dir", try files.join(ctx, &.{ output, "ordinary-cache" }), try ctx.fmt("-femit-bin={s}/ordinary.o", .{output}) });
    try runner.run("ordinary", ordinary.items, .{ .environ = options.environment });
    const ordinary_hash = try runtime.fileDigest(ctx, io, try files.join(ctx, &.{ output, "ordinary.o" }));
    const captured_hash = try runtime.fileDigest(ctx, io, try files.join(ctx, &.{ output, "captured.o" }));
    try toolchain.set(ctx, report, "objects", .{ .ordinary = &ordinary_hash, .captured = &captured_hash });
    try ctx.require(std.mem.eql(u8, &ordinary_hash, &captured_hash), "capture changed native object bytes");
    try ctx.require(c.equal(sources, try sourceFilesAt(ctx, io, options.source_base, options.source, options.extra_sources, modules)) and c.equal(try runtime.sourceIdentity(ctx, io, std.fs.path.dirname(lib).?), try ctx.field(provenance, "sourceTree")) and std.mem.eql(u8, &compiler_hash, &(try runtime.fileDigest(ctx, io, compiler))), "capture inputs changed during compilation");
    source_iter = sources.object.iterator();
    while (source_iter.next()) |entry| try ctx.require(std.mem.eql(u8, entry.value_ptr.string, try ctx.read(io, try files.join(ctx, &.{ output, entry.key_ptr.* }), 64 * 1024 * 1024)), "copied capture input changed during compilation");
    var hash_iter = hashes.object.iterator();
    while (hash_iter.next()) |entry| try ctx.require(std.mem.eql(u8, try ctx.str(entry.value_ptr.*), &(try runtime.fileDigest(ctx, io, try files.join(ctx, &.{ output, entry.key_ptr.* })))), "captured declaration source changed during compilation");
    try toolchain.set(ctx, report, "captureComplete", true);
    try toolchain.set(ctx, report, "status", "captured");
    return report.*;
}
