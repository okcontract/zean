// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Fresh tutorial capture, proof replay and a portable evidence archive.
const std = @import("std");
const c = @import("common.zig");
const z = @import("root.zig");
const files = @import("files.zig");
const tc = @import("toolchain.zig");
const runtime = @import("runtime.zig");
const lean_toolchain = @import("build_options").lean_toolchain;

pub const Kind = @import("tutorial_catalog.zig").Kind;

pub const Options = struct { toolchain: []const u8, output: []const u8, lake: ?[]const u8 = null, check: bool = false };

const Evidence = z.evidence.Bundle;

pub fn run(ctx: *c.Context, io: std.Io, kind: Kind, options: Options, environment: *const std.process.Environ.Map) !c.Value {
    const output = try tc.newOutput(ctx, io, options.output);
    var evidence: Evidence = .{ .ctx = ctx, .io = io, .output = output, .input_root = z.project_root };
    var report = try ctx.parse(try ctx.json(.{
        .schema = try ctx.fmt("zean.{s}-lifecycle.v1", .{@tagName(kind)}),
        .status = "failed",
        .provenance = try z.provenance.identity(ctx),
        .comparisonRequested = options.check,
        .checkedInProgramsCompared = false,
        .modelProofsChecked = false,
        .proofWorkers = 1,
        .libraryWorkers = 2,
        .airCorrespondenceChecked = false,
        .sourceSafetyVerified = false,
        .nativeRefinementVerified = false,
        .wholeCompilerVerified = false,
    }));
    defer files.write(io, files.join(ctx, &.{ output, "report.json" }) catch unreachable, ctx.json(report) catch "{\"status\":\"failed\"}") catch {};
    runInto(&evidence, &report, kind, options, environment) catch |err| {
        tc.set(ctx, &report, "status", "failed") catch {};
        tc.set(ctx, &report, "error", if (err == error.InvalidInput) ctx.diagnostic else @errorName(err)) catch {};
        return err;
    };
    return report;
}

fn runInto(e: *Evidence, report: *c.Value, kind: Kind, options: Options, environment: *const std.process.Environ.Map) !void {
    const ctx = e.ctx;
    const io = e.io;
    try z.provenance.verifyWorkspace(ctx, io);
    var env = try environment.clone(ctx.allocator);
    try env.put("LEAN_NUM_THREADS", "2");
    const runner: runtime.Runner = .{ .ctx = ctx, .io = io, .output = e.output };
    const lean: []const []const u8 = if (options.lake) |lake| &.{ lake, "env", "lean", "-j", "1" } else &.{ "elan", "run", lean_toolchain, "lake", "env", "lean", "-j", "1" };
    try runner.run("lean-version", try std.mem.concat(ctx.allocator, []const u8, &.{ lean, &.{"--version"} }), .{ .cwd = z.project_root, .environ = &env });
    try ctx.require(std.mem.startsWith(u8, try runner.text("lean-version"), "Lean (version 4.35.0,"), "tutorial proof replay requires Lean 4.35.0");
    try e.receipt("lean-version");
    const library: []const []const u8 = if (options.lake) |lake| &.{ lake, "build" } else &.{ "elan", "run", lean_toolchain, "lake", "build" };
    var library_args: std.ArrayList([]const u8) = .empty;
    try library_args.appendSlice(ctx.allocator, library);
    try library_args.appendSlice(ctx.allocator, kind.imports());
    try runner.run("library", library_args.items, .{ .cwd = z.project_root, .environ = &env });
    try e.receipt("library");
    const toolchain = try files.readJson(ctx, io, options.toolchain);
    try e.write("toolchain.json", toolchain.bytes);
    var parts: std.ArrayList([]const u8) = .empty;
    for (kind.imports()) |name| try parts.append(ctx.allocator, try ctx.fmt("import {s}\n", .{name}));
    if (kind == .counter or kind == .buffer) try parts.append(ctx.allocator, try replayBody(ctx, kind, try e.input(try ctx.fmt("lean/Compiler/Tutorial/{s}/Spec.lean", .{kind.module()}))));
    for (kind.versions()) |version| {
        const source_path = if (version.source.len == 0) try ctx.fmt("examples/{s}/{s}.zig", .{ @tagName(kind), kind.sourceName() }) else try ctx.fmt("examples/{s}/{s}/{s}.zig", .{ @tagName(kind), version.source, kind.sourceName() });
        const source = try e.input(source_path);
        const capture_source = try files.join(ctx, &.{ z.project_root, source_path });
        const generated_path = try kind.proofPath(ctx, if (version.module.len == 0) "Generated" else try ctx.fmt("{s}/Generated", .{version.module}));
        const retained = try e.input(generated_path);
        const capture_relative = try ctx.fmt("{s}-capture", .{if (version.source.len == 0) @tagName(kind) else version.source});
        const capture_path = try e.path(capture_relative);
        const captured = try z.capture.run(ctx, io, .{ .toolchain = options.toolchain, .source = capture_source, .roots = kind.roots(), .output = capture_path, .environment = &env });
        try ctx.require(c.tag(captured, "sourceSha256", &c.digest(source)) and c.tag(captured, "toolchainReportSha256", &c.digest(toolchain.bytes)), "tutorial capture input identity changed");
        for ([_][]const u8{ "report.json", "ordinary.o", "captured.o", "ordinary.stdout", "ordinary.stderr", "ordinary.process.json", "capture.stdout", "capture.stderr", "capture.process.json" }) |name| try e.remember(try ctx.fmt("{s}/{s}", .{ capture_relative, name }));
        const captured_sources = try ctx.field(captured, "sourceFiles");
        for (captured_sources.object.keys()) |name| try e.remember(try ctx.fmt("{s}/{s}", .{ capture_relative, name }));
        const functions = try ctx.field(captured, "functions");
        for (functions.object.values()) |entry| try e.remember(try ctx.fmt("{s}/air/{s}", .{ capture_relative, try ctx.str(try ctx.field(entry, "file")) }));
        const translation_relative = try ctx.fmt("{s}-translation", .{if (version.source.len == 0) @tagName(kind) else version.source});
        const specialized_source = if (kind == .stdlib_replace) try files.join(ctx, &.{ try ctx.str(try ctx.field(try ctx.field(toolchain.value, "compiler"), "zigLibDir")), "std", "mem.zig" }) else null;
        _ = try z.translate.run(ctx, io, .{ .capture = try files.join(ctx, &.{ capture_path, "report.json" }), .roots = kind.translationRoots(), .output = try e.path(translation_relative), .namespace = try kind.generatedModule(ctx, version), .specialized_source = specialized_source, .environment = &env, .lake = options.lake, .profile = switch (kind) {
            .counter => .scalar,
            .buffer, .ziglings => .memory,
            .copy, .stdlib_replace => .loops,
            .calls => .calls,
        } });
        for ([_][]const u8{ "Generated.lean", "manifest.json" }) |name| try e.remember(try ctx.fmt("{s}/{s}", .{ translation_relative, name }));
        const generated = try ctx.read(io, try e.path(try ctx.fmt("{s}/Generated.lean", .{translation_relative})), c.max_json_bytes);
        if (kind == .stdlib_replace) {
            const source_bytes = try ctx.read(io, specialized_source.?, c.max_json_bytes);
            try e.write("inputs/std/mem.zig", source_bytes);
            const selected = try ctx.field(functions, kind.translationRoots()[0]);
            const raw = try files.readJson(ctx, io, try files.join(ctx, &.{ capture_path, "air", try ctx.str(try ctx.field(selected, "file")) }));
            try ctx.require(c.tag(selected, "sha256", &c.digest(raw.bytes)), "specialized AIR changed before correspondence check");
            try ctx.require(c.tag(raw.value, "sourceSha256", &c.digest(source_bytes)), "specialized source changed after admission");
            const certificate_module = try ctx.fmt("import Compiler.ZigAir.Captured\n{s}\nnamespace FreshCorrespondence\nabbrev program := {s}.fn_replaceScalar__func_0\n{s}\nend FreshCorrespondence\n", .{ generated, try kind.generatedModule(ctx, version), try z.certificate.declaration(ctx, raw.value, "program", true) });
            try z.certificate.check(ctx, io, try e.path("correspondence"), certificate_module, &env, options.lake, .memory);
            for ([_][]const u8{ "Certificate.lean", "report.json" }) |name| try e.remember(try ctx.fmt("correspondence/{s}", .{name}));
            for ([_][]const u8{ "version", "library", "certificate" }) |label| try e.receipt(try ctx.fmt("correspondence/{s}", .{label}));
            try tc.set(ctx, report, "airCorrespondenceChecked", true);
        }
        if (kind == .ziglings) {
            var declarations: std.ArrayList([]const u8) = .empty;
            try declarations.append(ctx.allocator, try ctx.fmt("import Compiler.ZigAir.Captured\n{s}\n", .{generated}));
            for (kind.roots(), 0..) |root, index| {
                const selected = try ctx.field(functions, root);
                const raw = try files.readJson(ctx, io, try files.join(ctx, &.{ capture_path, "air", try ctx.str(try ctx.field(selected, "file")) }));
                try ctx.require(c.tag(selected, "sha256", &c.digest(raw.bytes)), "tutorial AIR changed before correspondence check");
                const name = root[std.mem.lastIndexOfScalar(u8, root, '.').? + 1 ..];
                try declarations.append(ctx.allocator, try ctx.fmt("namespace Correspondence{d}\nabbrev program := {s}.fn_{s}\n{s}\nend Correspondence{d}\n", .{ index, try kind.generatedModule(ctx, version), name, try z.certificate.declaration(ctx, raw.value, "program", false), index }));
            }
            try z.certificate.check(ctx, io, try e.path("correspondence"), try std.mem.concat(ctx.allocator, u8, declarations.items), &env, options.lake, .memory);
            for ([_][]const u8{ "Certificate.lean", "report.json" }) |name| try e.remember(try ctx.fmt("correspondence/{s}", .{name}));
            for ([_][]const u8{ "version", "library", "certificate" }) |label| try e.receipt(try ctx.fmt("correspondence/{s}", .{label}));
            try tc.set(ctx, report, "airCorrespondenceChecked", true);
        }
        if (options.check) try compareRetained(ctx, kind, retained, generated);
        try parts.append(ctx.allocator, try replayBody(ctx, kind, generated));
    }
    for (kind.proofs()) |proof| try parts.append(ctx.allocator, try replayBody(ctx, kind, try e.input(try kind.proofPath(ctx, proof))));
    const replay = try std.mem.concat(ctx.allocator, u8, parts.items);
    // A content-specific module prevents a negative client from accidentally
    // importing the retained tutorial or another replay's compiled definitions.
    const replay_identity = try ctx.fmt("{s}\n{s}", .{ replay, try ctx.json(try c.ordered(ctx, e.inputs)) });
    const replay_module = try ctx.fmt("ZeanReplay_{s}", .{&c.digest(replay_identity)});
    const replay_source = try ctx.fmt("{s}.lean", .{replay_module});
    const replay_object = try ctx.fmt("{s}.olean", .{replay_module});
    // Replay preserves each client's imports, replacing generated and client
    // dependencies with fresh modules. Retained definitions cannot silently
    // satisfy a freshly captured obligation or change its proof environment.
    try env.put("LEAN_PATH", if (env.get("LEAN_PATH")) |old| try ctx.fmt("{s}{c}{s}", .{ e.output, std.fs.path.delimiter, old }) else e.output);
    const replay_main = replay;
    try e.write("Replay.lean", replay_main);
    try e.write(replay_source, replay_main);
    // Replay processes run sequentially, after the two-worker library build.
    // Each leaves room for the launcher within the aggregate 8 GiB budget.
    _ = try z.proof_replay.check(ctx, io, runner, lean, &env, e.output, "proofs", replay_module, replay_main, 5120);
    try e.remember(replay_object);
    try e.receipt("proofs");
    for (kind.negatives()) |name| {
        const source = try e.input(try ctx.fmt("examples/{s}/{s}.lean", .{ @tagName(kind), name }));
        const relative = try ctx.fmt("{s}.lean", .{name});
        try e.write(relative, try ctx.fmt("import {s}\n{s}", .{ replay_module, try replayBody(ctx, kind, source) }));
        try e.unchanged();
        if (runner.run(name, try std.mem.concat(ctx.allocator, []const u8, &.{ lean, &.{ "-M", "4096", try e.path(relative) } }), .{ .cwd = z.project_root, .environ = &env })) |_| return ctx.fail("tutorial negative proof unexpectedly passed", .{}) else |err| {
            if (err != error.InvalidInput) return err;
            const receipt = try files.readJson(ctx, io, try e.path(try ctx.fmt("{s}.process.json", .{name})));
            try ctx.require(try ctx.integer(try ctx.field(receipt.value, "exitCode")) == 1 and std.mem.indexOf(u8, try runner.text(name), "Tactic `rfl` failed") != null, "tutorial negative control failed for an unexpected reason");
        }
        try e.receipt(name);
    }
    try e.unchanged();
    try z.provenance.verifyWorkspace(ctx, io);
    try ctx.require(std.mem.eql(u8, toolchain.bytes, try ctx.read(io, options.toolchain, c.max_json_bytes)), "tutorial toolchain report changed");
    try tc.set(ctx, report, "modelProofsChecked", true);
    try tc.set(ctx, report, "checkedInProgramsCompared", options.check);
    try tc.set(ctx, report, "nativeObjectComparisonsPassed", true);
    try tc.set(ctx, report, "negativeProofModule", replay_module);
    try tc.set(ctx, report, "files", try c.ordered(ctx, e.hashes));
    try tc.set(ctx, report, "status", "passed");
    const report_bytes = try ctx.json(report.*);
    try files.write(io, try e.path("report.json"), report_bytes);
    // A small release attachment: omit compiler caches, retain every inventoried byte.
    const archive = try std.Io.Dir.cwd().createFile(io, try e.path("evidence.tar"), .{});
    defer archive.close(io);
    var buffer: [64 * 1024]u8 = undefined;
    var writer = archive.writerStreaming(io, &buffer);
    var tar: std.tar.Writer = .{ .underlying_writer = &writer.interface };
    const inventory = try ctx.field(report.*, "files");
    for (inventory.object.keys(), inventory.object.values()) |name, identity| {
        try z.evidence.archiveFile(ctx, io, &tar, try e.path(name), name, try ctx.str(identity));
    }
    try tar.writeFileBytes("report.json", report_bytes, .{});
    try tar.finishPedantically();
    try writer.interface.flush();
    try files.write(io, try e.path("evidence.tar.sha256"), try ctx.fmt("{s}  evidence.tar\n", .{&(try runtime.fileDigest(ctx, io, try e.path("evidence.tar")))}));
}

// Separate definitions from their admitted imports. The replay either combines
// these bodies or redirects their dependencies to freshly checked modules.
pub fn replayBody(ctx: *c.Context, kind: Kind, text: []const u8) ![]const u8 {
    const parsed = try z.proof_replay.header(ctx, text);
    var allowed: std.ArrayList([]const u8) = .empty;
    try allowed.appendSlice(ctx.allocator, kind.imports());
    if (kind == .counter or kind == .buffer)
        try allowed.append(ctx.allocator, try ctx.fmt("Compiler.Tutorial.{s}.Spec", .{kind.module()}));
    for (kind.versions()) |version| try allowed.append(ctx.allocator, try kind.generatedModule(ctx, version));
    for (kind.proofs()) |proof| {
        const name = try ctx.allocator.dupe(u8, proof);
        std.mem.replaceScalar(u8, name, '/', '.');
        try allowed.append(ctx.allocator, try ctx.fmt("{s}.{s}", .{ try kind.package(ctx), name }));
    }
    _ = try z.proof_replay.imports(ctx, parsed.imports, allowed.items, &.{});
    return ctx.fmt("{s}\n", .{parsed.body});
}

pub fn compareRetained(ctx: *c.Context, kind: Kind, retained: []const u8, fresh: []const u8) !void {
    const declaration = switch (kind) {
        .counter => "def fn_advance : Program :=\n",
        .buffer => "def fn_replace : Program :=\n",
        .copy => "def fn_copy : Program true :=\n",
        .calls => "def FunctionId.",
        .stdlib_replace => "def fn_replaceScalar__func_0 : Program true :=\n",
        .ziglings => "def fn_initialize_pair : Program :=\n",
    };
    try z.proof_replay.compareBundle(ctx, retained, fresh, declaration);
}
