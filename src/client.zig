// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Declarative fresh capture, correspondence checking and proof replay.
const std = @import("std");
const c = @import("common.zig");
const z = @import("root.zig");
const files = @import("files.zig");
const runtime = @import("runtime.zig");
const pin = @import("build_options").lean_toolchain;

pub const Proof = struct { module: []const u8, path: []const u8 };
pub const Manifest = struct {
    source: []const u8,
    sources: []const []const u8,
    roots: []const []const u8,
    profile: z.air.Profile,
    call_machine: bool,
    generated: []const u8,
    libraries: []const []const u8,
    proofs: []const Proof,
    theorems: []const []const u8,
};

pub fn relative(ctx: *c.Context, path: []const u8) !void {
    try ctx.require(runtime.safeArchiveName(path), "client path must be relative and contained");
    var parts = std.mem.splitScalar(u8, path, '/');
    while (parts.next()) |part| try ctx.require(part.len > 0 and !std.mem.eql(u8, part, "."), "client path must be normalized");
}

fn strings(ctx: *c.Context, value: c.Value) ![]const []const u8 {
    const entries = try ctx.array(value);
    try ctx.require(entries.len <= 256, "client inventory limit");
    const result = try ctx.allocator.alloc([]const u8, entries.len);
    var seen: std.StringHashMap(void) = .init(ctx.allocator);
    for (entries, result) |entry, *item| {
        item.* = try ctx.str(entry);
        try ctx.require(!(try seen.getOrPut(item.*)).found_existing, "duplicate client inventory entry");
    }
    return result;
}

pub fn parse(ctx: *c.Context, value: c.Value) !Manifest {
    const explicit_model = c.get(value, "executionModel") != null;
    try ctx.fields(value, if (explicit_model) "schema source sources roots profile executionModel generatedModule libraries proofs theorems" else "schema source sources roots profile generatedModule libraries proofs theorems");
    try ctx.require(c.tag(value, "schema", "zean.client.v1"), "unsupported client manifest");
    const source = try ctx.str(try ctx.field(value, "source"));
    try relative(ctx, source);
    try ctx.require(std.mem.endsWith(u8, source, ".zig"), "client source must be Zig");
    const sources = try strings(ctx, try ctx.field(value, "sources"));
    for (sources) |path| {
        try relative(ctx, path);
        try ctx.require(std.mem.endsWith(u8, path, ".zig") and !std.mem.eql(u8, path, source), "invalid extra client source");
    }
    const roots = try strings(ctx, try ctx.field(value, "roots"));
    try z.capture.uniqueRoots(ctx, roots);
    const profile = z.air.Profile.parse(try ctx.str(try ctx.field(value, "profile"))) orelse return ctx.fail("unsupported client profile", .{});
    try ctx.require(profile.capabilities().correspondence, "client workflow requires a certifiable profile");
    if (explicit_model) try ctx.require(c.tag(value, "executionModel", "call-machine") and profile.hasCalls(), "call-machine client requires a call profile and the supported execution model");
    const generated = try ctx.str(try ctx.field(value, "generatedModule"));
    try ctx.require(c.identifier(generated, true) and !std.mem.startsWith(u8, generated, "Compiler.ZigAir."), "invalid client generated module");
    const libraries = try strings(ctx, try ctx.field(value, "libraries"));
    for (libraries) |name| try ctx.require(c.identifier(name, true) and std.mem.startsWith(u8, name, "Compiler.ZigAir."), "client library must belong to the generic framework");
    const entries = try ctx.array(try ctx.field(value, "proofs"));
    try ctx.require(entries.len > 0 and entries.len <= 128, "client requires 1-128 proof modules");
    const proofs = try ctx.allocator.alloc(Proof, entries.len);
    var modules: std.StringHashMap(void) = .init(ctx.allocator);
    try modules.put(generated, {});
    var paths: std.StringHashMap(void) = .init(ctx.allocator);
    for (entries, proofs) |entry, *proof| {
        try ctx.fields(entry, "module path");
        proof.* = .{ .module = try ctx.str(try ctx.field(entry, "module")), .path = try ctx.str(try ctx.field(entry, "path")) };
        try relative(ctx, proof.path);
        try ctx.require(c.identifier(proof.module, true) and !std.mem.startsWith(u8, proof.module, "Compiler.ZigAir.") and std.mem.endsWith(u8, proof.path, ".lean"), "invalid client proof module");
        try ctx.require(!(try modules.getOrPut(proof.module)).found_existing and !(try paths.getOrPut(proof.path)).found_existing, "duplicate client proof identity");
    }
    const theorems = try strings(ctx, try ctx.field(value, "theorems"));
    try ctx.require(theorems.len > 0, "client requires named theorem obligations");
    for (theorems) |name| try ctx.require(c.identifier(name, true), "invalid client theorem name");
    return .{ .source = source, .sources = sources, .roots = roots, .profile = profile, .call_machine = profile.hasCalls(), .generated = generated, .libraries = libraries, .proofs = proofs, .theorems = theorems };
}

pub const Options = struct { manifest: []const u8, toolchain: []const u8, output: []const u8, lake: ?[]const u8 = null };
pub fn run(ctx: *c.Context, io: std.Io, options: Options, environment: *const std.process.Environ.Map) !c.Value {
    const manifestPath = try std.fs.path.resolve(ctx.allocator, &.{options.manifest});
    try files.regular(ctx, io, manifestPath);
    const input = try files.readJson(ctx, io, manifestPath);
    const manifest = try parse(ctx, input.value);
    const base = std.fs.path.dirname(manifestPath).?;
    const output = try z.toolchain.newOutput(ctx, io, options.output);
    var report = try ctx.parse(try ctx.json(.{ .schema = "zean.client-replay.v1", .status = "failed", .manifestSha256 = &c.digest(input.bytes), .provenance = try z.provenance.identity(ctx), .airCorrespondenceChecked = false, .modelProofsChecked = false, .nativeObjectComparisons = false, .sourceSafetyVerified = false, .nativeRefinementVerified = false, .wholeApplicationVerified = false, .theoremMeaning = "user-specified contracts; theorem checking alone does not establish a source-safety claim" }));
    defer files.write(io, files.join(ctx, &.{ output, "report.json" }) catch unreachable, ctx.json(report) catch "{\"status\":\"failed\"}") catch {};
    try z.provenance.verifyWorkspace(ctx, io);
    try files.write(io, try files.join(ctx, &.{ output, "client.json" }), input.bytes);
    var snapshots: std.StringHashMap([]const u8) = .init(ctx.allocator);
    const sources = try z.capture.sourceFilesAt(ctx, io, base, manifest.source, manifest.sources, .{ .object = .empty });
    for (manifest.sources) |path| try rememberInput(ctx, io, base, path, &snapshots);
    try rememberInput(ctx, io, base, manifest.source, &snapshots);
    var initialSources = sources.object.iterator();
    while (initialSources.next()) |entry| {
        const path = if (std.mem.eql(u8, entry.key_ptr.*, std.fs.path.basename(manifest.source))) manifest.source else entry.key_ptr.*;
        try ctx.require(std.mem.eql(u8, entry.value_ptr.string, snapshots.get(path).?), "client source changed while retaining inputs");
    }
    for (manifest.proofs) |proof| try rememberInput(ctx, io, base, proof.path, &snapshots);
    var retained = snapshots.iterator();
    var inputHashes: c.Value = .{ .object = .empty };
    while (retained.next()) |entry| {
        const path = try files.join(ctx, &.{ output, "inputs", entry.key_ptr.* });
        try std.Io.Dir.cwd().createDirPath(io, std.fs.path.dirname(path).?);
        try files.write(io, path, entry.value_ptr.*);
        try inputHashes.object.put(ctx.allocator, entry.key_ptr.*, .{ .string = try ctx.allocator.dupe(u8, &c.digest(entry.value_ptr.*)) });
    }
    try z.toolchain.set(ctx, &report, "inputs", inputHashes);
    const captureDir = try files.join(ctx, &.{ output, "capture" });
    const captured = try z.capture.run(ctx, io, .{ .toolchain = options.toolchain, .source = manifest.source, .source_base = base, .extra_sources = manifest.sources, .roots = manifest.roots, .output = captureDir, .environment = environment });
    try z.toolchain.set(ctx, &report, "nativeObjectComparisons", c.equal(try ctx.field(try ctx.field(captured, "objects"), "ordinary"), try ctx.field(try ctx.field(captured, "objects"), "captured")));
    const capturedSources = try ctx.field(captured, "sourceFiles");
    var sourceIter = sources.object.iterator();
    while (sourceIter.next()) |entry| try ctx.require(c.tag(capturedSources, entry.key_ptr.*, &c.digest(entry.value_ptr.string)), "client capture source identity changed");
    const bundle = try files.join(ctx, &.{ output, "translation" });
    _ = try z.translate.run(ctx, io, .{ .capture = try files.join(ctx, &.{ captureDir, "report.json" }), .roots = manifest.roots, .profile = manifest.profile, .call_machine = manifest.call_machine, .namespace = manifest.generated, .output = bundle, .certify = try files.join(ctx, &.{ output, "correspondence" }), .environment = environment, .lake = options.lake });
    try z.toolchain.set(ctx, &report, "airCorrespondenceChecked", true);
    var env = try environment.clone(ctx.allocator);
    try env.put("LEAN_NUM_THREADS", "2");
    const runner: runtime.Runner = .{ .ctx = ctx, .io = io, .output = output };
    const lake: []const []const u8 = if (options.lake) |path| &.{path} else &.{ "elan", "run", pin, "lake" };
    try runner.run("library", try std.mem.concat(ctx.allocator, []const u8, &.{ lake, &.{ "build", "Compiler.ZigAir.ProofAudit" }, manifest.libraries }), .{ .cwd = z.project_root, .environ = &env });
    // Fresh module names prevent a retained generated module satisfying imports.
    var nonce: [16]u8 = undefined;
    io.random(&nonce);
    const prefix = try ctx.fmt("Client_{s}", .{std.fmt.bytesToHex(nonce, .lower)});
    var dependencies: std.ArrayList(z.proof_replay.Import) = .empty;
    var artifacts: std.StringHashMap([]const u8) = .init(ctx.allocator);
    for ([_][]const u8{ "client.json", "capture/report.json", "translation/Generated.lean", "translation/manifest.json", "correspondence/Certificate.lean", "correspondence/report.json" }) |relativePath| {
        const path = try files.join(ctx, &.{ output, relativePath });
        try artifacts.put(path, try ctx.allocator.dupe(u8, &(try runtime.fileDigest(ctx, io, path))));
    }
    try env.put("LEAN_PATH", try ctx.fmt("{s}:{s}", .{ output, try files.join(ctx, &.{ z.project_root, ".lake/build/lib/lean" }) }));
    const generated = try ctx.read(io, try files.join(ctx, &.{ bundle, "Generated.lean" }), c.max_json_bytes);
    for (0..manifest.proofs.len + 1) |index| {
        const name = try ctx.fmt("{s}_{d}", .{ prefix, index });
        const body = if (index == 0) generated else try z.proof_replay.replay(ctx, snapshots.get(manifest.proofs[index - 1].path).?, manifest.libraries, dependencies.items);
        const checked = try z.proof_replay.check(ctx, io, runner, try std.mem.concat(ctx.allocator, []const u8, &.{ lake, &.{ "env", "lean" } }), &env, output, try ctx.fmt("proof-{d}", .{index}), name, body, 4096);
        const path = checked.source;
        const object = checked.object;
        try artifacts.put(path, try ctx.allocator.dupe(u8, &c.digest(body)));
        try artifacts.put(object, try ctx.allocator.dupe(u8, &(try runtime.fileDigest(ctx, io, object))));
        try dependencies.append(ctx.allocator, .{ .original = if (index == 0) manifest.generated else manifest.proofs[index - 1].module, .fresh = name });
    }
    var audit: std.ArrayList([]const u8) = .empty;
    try audit.append(ctx.allocator, "import Compiler.ZigAir.ProofAudit\n");
    for (dependencies.items) |dependency| try audit.append(ctx.allocator, try ctx.fmt("import {s}\n", .{dependency.fresh}));
    var checked_modules: std.ArrayList([]const u8) = .empty;
    for (dependencies.items[1..]) |dependency| try checked_modules.append(ctx.allocator, try z.certificate.string(ctx, dependency.fresh));
    const owners = try std.mem.join(ctx.allocator, ", ", checked_modules.items);
    for (manifest.theorems) |name| try audit.append(ctx.allocator, try ctx.fmt("#audit_proof {s} from [{s}]\n", .{ try z.certificate.string(ctx, name), owners }));
    const auditPath = try files.join(ctx, &.{ output, "Audit.lean" });
    const auditBytes = try std.mem.concat(ctx.allocator, u8, audit.items);
    try files.write(io, auditPath, auditBytes);
    try runner.run("axioms", try std.mem.concat(ctx.allocator, []const u8, &.{ lake, &.{ "env", "lean", "-j", "1", "-M", "4096", auditPath } }), .{ .cwd = z.project_root, .environ = &env });
    try ctx.require(std.mem.eql(u8, auditBytes, try ctx.read(io, auditPath, c.max_json_bytes)), "client audit changed during checking");
    var iter = snapshots.iterator();
    while (iter.next()) |entry| {
        try ctx.require(std.mem.eql(u8, entry.value_ptr.*, try ctx.read(io, try files.join(ctx, &.{ base, entry.key_ptr.* }), c.max_json_bytes)), "client input changed during verification");
        try ctx.require(std.mem.eql(u8, entry.value_ptr.*, try ctx.read(io, try files.join(ctx, &.{ output, "inputs", entry.key_ptr.* }), c.max_json_bytes)), "retained client input changed during verification");
    }
    var artifactIter = artifacts.iterator();
    while (artifactIter.next()) |entry| try ctx.require(std.mem.eql(u8, entry.value_ptr.*, &(try runtime.fileDigest(ctx, io, entry.key_ptr.*))), "checked client artifact changed");
    try ctx.require(std.mem.eql(u8, input.bytes, try ctx.read(io, manifestPath, c.max_json_bytes)), "client manifest changed during verification");
    try z.provenance.verifyWorkspace(ctx, io);
    try z.toolchain.set(ctx, &report, "modelProofsChecked", true);
    try z.toolchain.set(ctx, &report, "theorems", manifest.theorems);
    try z.toolchain.set(ctx, &report, "status", "passed");
    return report;
}

fn rememberInput(ctx: *c.Context, io: std.Io, base: []const u8, path: []const u8, snapshots: *std.StringHashMap([]const u8)) !void {
    // Check every component: rejecting only a final symlink does not bind the
    // source closure when a parent directory is redirected.
    var parts = std.mem.splitScalar(u8, path, '/');
    var current = base;
    while (parts.next()) |part| {
        current = try files.join(ctx, &.{ current, part });
        const stat = try std.Io.Dir.cwd().statFile(io, current, .{ .follow_symlinks = false });
        try ctx.require(stat.kind == .file or stat.kind == .directory, "client input contains a link or special file");
    }
    try files.regular(ctx, io, current);
    try snapshots.put(path, try ctx.read(io, current, c.max_json_bytes));
}
