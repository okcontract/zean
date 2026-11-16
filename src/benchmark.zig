// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Serial, reproducible re-elaboration measurements; imported modules are warm.
const std = @import("std");
const c = @import("common.zig");
const z = @import("root.zig");
const files = @import("files.zig");
const runtime = @import("runtime.zig");
const toolchain = @import("toolchain.zig");
const lean_toolchain = @import("build_options").lean_toolchain;

pub const defaults: []const []const u8 = &.{
    "lean/Compiler/Tutorial/Buffer/Verification.lean",
    "lean/Compiler/Tutorial/Copy/Verification.lean",
    "lean/Compiler/Tutorial/Calls/Proofs.lean",
    "lean/Compiler/Components/Replace/Proofs.lean",
};
pub const Options = struct { output: []const u8, proofs: []const []const u8 = defaults, repetitions: u64 = 3, lake: ?[]const u8 = null };

pub fn run(ctx: *c.Context, io: std.Io, options: Options, environment: *const std.process.Environ.Map) !c.Value {
    try ctx.require(options.repetitions > 0 and options.repetitions <= 20 and options.proofs.len > 0 and options.proofs.len <= 32, "benchmark limits: 1-20 repetitions, 1-32 proof files");
    const output = try toolchain.newOutput(ctx, io, options.output);
    try z.provenance.verifyWorkspace(ctx, io);
    const provenance = try z.provenance.identity(ctx);
    var env = try environment.clone(ctx.allocator);
    try env.put("LEAN_NUM_THREADS", "2");
    const runner: runtime.Runner = .{ .ctx = ctx, .io = io, .output = output };
    const lean: []const []const u8 = if (options.lake) |lake| &.{ lake, "env", "lean" } else &.{ "elan", "run", lean_toolchain, "lake", "env", "lean" };
    try runner.run("version", try std.mem.concat(ctx.allocator, []const u8, &.{ lean, &.{"--version"} }), .{ .cwd = z.project_root, .environ = &env });
    try ctx.require(std.mem.startsWith(u8, try runner.text("version"), "Lean (version 4.35.0,"), "benchmark requires Lean 4.35.0");
    var samples: c.Value = .{ .array = std.array_list.Managed(c.Value).init(ctx.allocator) };
    var inputs: c.Value = .{ .array = std.array_list.Managed(c.Value).init(ctx.allocator) };
    for (options.proofs, 0..) |proof, index| {
        try ctx.require(std.mem.endsWith(u8, proof, ".lean"), "benchmark input must be a Lean file");
        try files.regular(ctx, io, proof);
        const bytes = try ctx.read(io, proof, c.max_json_bytes);
        const path = try ctx.fmt("{s}/input-{d}.lean", .{ output, index });
        try files.write(io, path, bytes);
        var lines: usize = 0;
        var iterator = std.mem.splitScalar(u8, bytes, '\n');
        while (iterator.next()) |line| if (std.mem.trim(u8, line, " \t\r").len > 0) {
            lines += 1;
        };
        try inputs.array.append(try ctx.parse(try ctx.json(.{ .path = proof, .snapshot = std.fs.path.basename(path), .sha256 = &c.digest(bytes), .nonemptyLines = lines })));
        for (0..options.repetitions) |repetition| {
            const label = try ctx.fmt("proof-{d}-run-{d}", .{ index, repetition });
            // Each main file is elaborated afresh; dependency .oleans are reused.
            // The process limit is separate from the two-worker scheduling limit.
            try runner.run(label, try std.mem.concat(ctx.allocator, []const u8, &.{ lean, &.{ "-j", "1", "-M", "4096", path } }), .{ .cwd = z.project_root, .environ = &env });
            const receipt = try files.readJson(ctx, io, try ctx.fmt("{s}/{s}.process.json", .{ output, label }));
            try samples.array.append(try ctx.parse(try ctx.json(.{ .input = index, .repetition = repetition, .receipt = try ctx.fmt("{s}.process.json", .{label}), .milliseconds = try ctx.field(receipt.value, "milliseconds"), .maxRssBytes = try ctx.field(receipt.value, "maxRssBytes") })));
        }
        try ctx.require(std.mem.eql(u8, bytes, try ctx.read(io, proof, c.max_json_bytes)) and std.mem.eql(u8, bytes, try ctx.read(io, path, c.max_json_bytes)), "benchmark input changed during measurement");
    }
    try z.provenance.verifyWorkspace(ctx, io);
    const report = try ctx.parse(try ctx.json(.{
        .schema = "zean.proof-benchmark.v1",
        .status = "passed",
        .provenance = provenance,
        .leanWorkers = 1,
        .processMemoryLimitMiB = 4096,
        .dependencyCache = "warm",
        .mainModuleCache = "disabled",
        .resourceUsageScope = "waited-child",
        .inputs = inputs,
        .samples = samples,
        .nativeCaptureVerified = false,
        .sourceSafetyVerified = false,
    }));
    try files.write(io, try ctx.fmt("{s}/report.json", .{output}), try ctx.json(report));
    return report;
}
