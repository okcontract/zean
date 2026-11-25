// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Declarative fresh capture, correspondence checking and proof replay.
const std = @import("std");
const c = @import("common.zig");
const z = @import("root.zig");
const files = @import("files.zig");
const runtime = @import("runtime.zig");
const Dir = std.Io.Dir;
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
    try ctx.require(files.validRelativePath(path), "client path must be relative, normalized, and contained");
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
    return parseManifest(ctx, value, false);
}

fn parseManifest(ctx: *c.Context, value: c.Value, allow_empty_proofs: bool) !Manifest {
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
    try ctx.require((entries.len > 0 or allow_empty_proofs) and entries.len <= 128, "client requires 1-128 proof modules");
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
    try ctx.require((theorems.len == 0) == (proofs.len == 0), "client must declare proof modules and theorem obligations together");
    for (theorems) |name| try ctx.require(c.identifier(name, true), "invalid client theorem name");
    return .{ .source = source, .sources = sources, .roots = roots, .profile = profile, .call_machine = profile.hasCalls(), .generated = generated, .libraries = libraries, .proofs = proofs, .theorems = theorems };
}

pub const SourceLocation = struct {
    path: []const u8,
    used: bool = false,
};
pub const SourceMap = std.StringHashMapUnmanaged(SourceLocation);

const InputPath = struct { logical: []const u8, actual: []const u8 };

pub const Plan = struct {
    path: []const u8,
    bytes: []const u8,
    manifest: Manifest,
    inputs: []const InputPath,
};

/// Manifest and input paths are relative to `base`. Logical input paths are
/// kept relative to the manifest when copied into replay evidence.
pub fn load(ctx: *c.Context, io: std.Io, base: Dir, path: []const u8, source_map: ?*SourceMap) !Plan {
    try relative(ctx, path);
    const bytes = try files.readContained(ctx, io, base, path);
    const manifest = try parseManifest(ctx, try ctx.parse(bytes), source_map != null);
    const parent = Dir.path.dirnamePosix(path) orelse "";
    const sources = try std.mem.concat(ctx.allocator, []const u8, &.{ &.{manifest.source}, manifest.sources });
    const inputs = try ctx.allocator.alloc(InputPath, sources.len + manifest.proofs.len);
    for (sources, inputs[0..sources.len]) |logical, *input| {
        const actual = try files.join(ctx, &.{ parent, logical });
        input.* = .{ .logical = logical, .actual = actual };
        if (source_map) |map| if (map.getPtr(actual)) |entry| {
            input.actual = entry.path;
            entry.used = true;
        };
    }
    for (manifest.proofs, inputs[sources.len..]) |proof, *input| {
        input.* = .{ .logical = proof.path, .actual = try files.join(ctx, &.{ parent, proof.path }) };
    }
    return .{ .path = path, .bytes = bytes, .manifest = manifest, .inputs = inputs };
}

pub const Options = struct { manifest: []const u8, toolchain: []const u8, output: []const u8, lake: ?[]const u8 = null };
pub fn run(ctx: *c.Context, io: std.Io, options: Options, environment: *const std.process.Environ.Map) !c.Value {
    const path = try files.absolute(ctx, io, options.manifest);
    const base = try Dir.openDirAbsolute(io, Dir.path.dirname(path) orelse return error.NotRegularFile, .{});
    defer base.close(io);
    const plan = try load(ctx, io, base, Dir.path.basename(path), null);
    const result = try execute(ctx, io, base, plan, .{ .toolchain = options.toolchain, .output = options.output, .lake = options.lake, .verify = true }, environment);
    return result.report;
}

pub const RunOptions = struct {
    toolchain: []const u8,
    output: []const u8,
    compiler: ?z.capture.Compiler = null,
    capture_target: ?z.capture.Target = null,
    verify: bool = false,
    lake: ?[]const u8 = null,
    project_config: ?[]const u8 = null,
};
pub const InputHash = struct { path: []const u8, sha: [64]u8 };
pub const Result = struct { report: c.Value, generated: []const u8, input_hashes: []const InputHash };

pub fn execute(ctx: *c.Context, io: std.Io, base: Dir, plan: Plan, options: RunOptions, environment: *const std.process.Environ.Map) !Result {
    const manifest = plan.manifest;
    if (options.verify) try ctx.require(manifest.proofs.len != 0, "verification requires named proof obligations");
    const output = try z.toolchain.newOutput(ctx, io, options.output);
    const report_path = try files.join(ctx, &.{ output, "report.json" });
    var report = try ctx.parse(try ctx.json(.{ .schema = if (options.verify) "zean.client-replay.v1" else "zean.client-generation.v1", .status = "failed", .manifestSha256 = &c.digest(plan.bytes), .provenance = try z.provenance.identity(ctx), .airCorrespondenceEmitted = false, .airCorrespondenceChecked = false, .modelProofsChecked = false, .nativeObjectComparisons = false, .sourceSafetyVerified = false, .nativeRefinementVerified = false, .wholeApplicationVerified = false, .theoremMeaning = "user-specified contracts; theorem checking alone does not establish a source-safety claim" }));
    errdefer files.write(io, report_path, ctx.json(report) catch "{\"status\":\"failed\"}") catch {};
    if (options.verify) try z.provenance.verifyWorkspace(ctx, io);
    const retained_project = if (options.project_config) |project| path: {
        const path = try files.join(ctx, &.{ output, "zean.json" });
        try files.write(io, path, project);
        try z.toolchain.set(ctx, &report, "projectSha256", &c.digest(project));
        break :path path;
    } else null;
    const retained_manifest = try files.join(ctx, &.{ output, "client.json" });
    try files.write(io, retained_manifest, plan.bytes);
    const retained_inputs = try files.join(ctx, &.{ output, "inputs" });
    const snapshots = try ctx.allocator.alloc([]const u8, plan.inputs.len);
    const input_hashes = try ctx.allocator.alloc(InputHash, plan.inputs.len + 1);
    input_hashes[0] = .{ .path = plan.path, .sha = c.digest(plan.bytes) };
    var inputHashes: c.Value = .{ .object = .empty };
    for (plan.inputs, snapshots, input_hashes[1..]) |input, *snapshot, *hash| {
        snapshot.* = try readInput(ctx, io, base, input.actual);
        hash.* = .{ .path = input.actual, .sha = c.digest(snapshot.*) };
        const path = try files.join(ctx, &.{ retained_inputs, input.logical });
        try Dir.cwd().createDirPath(io, Dir.path.dirname(path).?);
        try files.write(io, path, snapshot.*);
        try inputHashes.object.put(ctx.allocator, input.logical, .{ .string = &hash.sha });
    }
    try z.toolchain.set(ctx, &report, "inputs", inputHashes);
    const captureDir = try files.join(ctx, &.{ output, "capture" });
    const captured = try z.capture.run(ctx, io, .{
        .toolchain = options.toolchain,
        .compiler = options.compiler,
        .target = options.capture_target,
        .source = manifest.source,
        .source_base = retained_inputs,
        .extra_sources = manifest.sources,
        .roots = manifest.roots,
        .output = captureDir,
        .environment = environment,
    });
    try z.toolchain.set(ctx, &report, "nativeObjectComparisons", c.equal(try ctx.field(try ctx.field(captured, "objects"), "ordinary"), try ctx.field(try ctx.field(captured, "objects"), "captured")));
    const capturedSources = try ctx.field(captured, "sourceFiles");
    const source_count = manifest.sources.len + 1;
    try ctx.require(c.tag(capturedSources, Dir.path.basename(manifest.source), &input_hashes[1].sha), "client capture root identity changed");
    for (manifest.sources, input_hashes[2 .. source_count + 1]) |source, hash| {
        try ctx.require(c.tag(capturedSources, source, &hash.sha), "client capture source identity changed");
    }
    const bundle = try files.join(ctx, &.{ output, "translation" });
    const translated = try z.translate.run(ctx, io, .{
        .capture = try files.join(ctx, &.{ captureDir, "report.json" }),
        .roots = manifest.roots,
        .profile = manifest.profile,
        .call_machine = manifest.call_machine,
        .namespace = manifest.generated,
        .output = bundle,
        .emit_correspondence = true,
        .certify = if (options.verify) try files.join(ctx, &.{ output, "correspondence" }) else null,
        .environment = environment,
        .lake = options.lake,
    });
    try z.toolchain.set(ctx, &report, "airCorrespondenceEmitted", true);
    try z.toolchain.set(ctx, &report, "airCorrespondenceChecked", options.verify);
    const generated = try ctx.read(io, try files.join(ctx, &.{ bundle, "Generated.lean" }), c.max_json_bytes);
    try ctx.require(c.tag(translated, "leanSha256", &c.digest(generated)), "generated Lean changed after translation");
    if (options.verify) {
        try checkProofs(ctx, io, options, environment, output, manifest, generated, snapshots[source_count..]);
    }
    if (options.project_config) |project| {
        try revalidate(ctx, io, base, &.{.{ .path = "zean.json", .sha = c.digest(project) }});
        try ctx.require(std.mem.eql(u8, project, try ctx.read(io, retained_project.?, c.max_json_bytes)), "retained project manifest changed during verification");
    }
    try revalidate(ctx, io, base, input_hashes);
    try ctx.require(std.mem.eql(u8, plan.bytes, try ctx.read(io, retained_manifest, c.max_json_bytes)), "retained client manifest changed during verification");
    for (plan.inputs, snapshots) |input, snapshot| {
        const path = try files.join(ctx, &.{ retained_inputs, input.logical });
        try ctx.require(std.mem.eql(u8, snapshot, try ctx.read(io, path, c.max_json_bytes)), "retained client input changed during verification");
    }
    if (options.verify) try z.provenance.verifyWorkspace(ctx, io);
    try z.toolchain.set(ctx, &report, "modelProofsChecked", options.verify);
    try z.toolchain.set(ctx, &report, "theorems", manifest.theorems);
    try z.toolchain.set(ctx, &report, "status", "passed");
    try files.write(io, report_path, try ctx.json(report));
    return .{ .report = report, .generated = generated, .input_hashes = input_hashes };
}

fn checkProofs(ctx: *c.Context, io: std.Io, options: RunOptions, environment: *const std.process.Environ.Map, output: []const u8, manifest: Manifest, generated: []const u8, snapshots: []const []const u8) !void {
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
    for (0..manifest.proofs.len + 1) |index| {
        const name = try ctx.fmt("{s}_{d}", .{ prefix, index });
        const body = if (index == 0) generated else try z.proof_replay.replay(ctx, snapshots[index - 1], manifest.libraries, dependencies.items);
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
    var artifactIter = artifacts.iterator();
    while (artifactIter.next()) |entry| try ctx.require(std.mem.eql(u8, entry.value_ptr.*, &(try runtime.fileDigest(ctx, io, entry.key_ptr.*))), "checked client artifact changed");
}

fn readInput(ctx: *c.Context, io: std.Io, base: Dir, path: []const u8) ![]const u8 {
    return files.readContained(ctx, io, base, path) catch |err|
        return ctx.fail("cannot read client input {s} ({s})", .{ path, @errorName(err) });
}

pub fn revalidate(ctx: *c.Context, io: std.Io, base: Dir, inputs: []const InputHash) !void {
    for (inputs) |input| {
        const bytes = try readInput(ctx, io, base, input.path);
        defer ctx.allocator.free(bytes);
        if (!std.mem.eql(u8, &input.sha, &c.digest(bytes))) return ctx.fail("client input changed during verification: {s}", .{input.path});
    }
}
