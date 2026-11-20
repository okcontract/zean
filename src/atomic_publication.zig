// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Replay the closed two-function publication example against a capture report.
const std = @import("std");
const z = @import("root.zig");
const c = z.common;
const source_name = "publication.zig";
// Reviewed source for this closed protocol, including its pointer interface.
pub const source_sha = "af5514f3afe035f38200f8039da66083100fc8016d9473e8149dfc8e320540e1";
const roots = [_][]const u8{ "publication.publish", "publication.readEntry" };

// Mutate independent copies of the actual capture. Each example in the replay
// must lose the positive correspondence, even if the affected result is unused.
fn rejectionControls(ctx: *c.Context, records: [2][]const u8) ![]const u8 {
    const Mutation = struct { reader: bool, index: usize, field: []const u8, replacement: []const u8 };
    var checks: std.ArrayList([]const u8) = .empty;
    for ([_]Mutation{
        .{ .reader = false, .index = 7, .field = "ordering", .replacement = "\"monotonic\"" },
        .{ .reader = false, .index = 6, .field = "lhs", .replacement = "{\"kind\":\"instruction\",\"index\":0}" },
        .{ .reader = true, .index = 3, .field = "ordering", .replacement = "\"monotonic\"" },
        .{ .reader = true, .index = 3, .field = "operand", .replacement = "{\"kind\":\"instruction\",\"index\":0}" },
        .{ .reader = true, .index = 8, .field = "elseBody", .replacement = "[5,6]" },
        .{ .reader = true, .index = 5, .field = "tag", .replacement = "\"atomic_rmw\"" },
    }) |mutation| {
        const changed = try ctx.parse(records[@intFromBool(mutation.reader)]);
        const table = try ctx.field(changed, "instructions");
        const entries = try ctx.array(table);
        try ctx.require(mutation.index < entries.len and c.get(entries[mutation.index], mutation.field) != null, "unexpected publication control input");
        try table.array.items[mutation.index].object.put(ctx.allocator, mutation.field, try ctx.parse(mutation.replacement));
        const raw = try z.certificate.lift(ctx, changed, 0);
        try checks.append(ctx.allocator, try ctx.fmt("example : CapturedPublication.decode {s} {s} ≠ some publication := by decide +kernel\n", .{
            if (mutation.reader) "writer" else raw, if (mutation.reader) raw else "reader",
        }));
    }
    return std.mem.join(ctx.allocator, "\n", checks.items);
}

pub fn check(ctx: *c.Context, io: std.Io, report_path: []const u8, output: []const u8, environment: *const std.process.Environ.Map, lake: ?[]const u8) !c.Value {
    const captured = try z.files.readJson(ctx, io, report_path);
    const report = captured.value;
    try ctx.require(c.tag(report, "schema", "oksolc.fresh-air-capture.v1") and c.flag(report, "captureComplete", true) and
        c.tag(report, "status", "captured") and c.tag(report, "inputKind", "native-capture") and
        c.tag(report, "zigVersion", z.version) and c.tag(report, "zigRevision", z.revision), "expected completed pinned AIR capture");
    for ([_][]const u8{ "toolchainReportSha256", "compilerSha256" }) |key|
        try ctx.require(c.isDigest(try ctx.str(try ctx.field(report, key))), "missing toolchain identity");
    try ctx.require(c.tag(report, "sourceSha256", source_sha) and c.tag(try ctx.field(report, "sourceFiles"), source_name, source_sha), "publication source identity mismatch");
    const directory = std.fs.path.dirname(report_path) orelse ".";
    const objects = try ctx.field(report, "objects");
    const object_sha = try ctx.str(try ctx.field(objects, "ordinary"));
    try ctx.require(c.isDigest(object_sha) and c.tag(objects, "captured", object_sha), "ordinary and instrumented object identities differ");
    for ([_][]const u8{ "ordinary.o", "captured.o" }) |name| {
        const path = try z.files.closureMember(ctx, io, directory, name);
        try ctx.require(std.mem.eql(u8, &(try z.runtime.fileDigest(ctx, io, path)), object_sha), "publication object identity mismatch");
    }
    const source_path = try z.files.closureMember(ctx, io, directory, source_name);
    try ctx.require(std.mem.eql(u8, &(try z.runtime.fileDigest(ctx, io, source_path)), source_sha), "archived publication source changed");
    const functions = try ctx.field(report, "functions");
    var records: [roots.len][]const u8 = undefined;
    var lifted: [roots.len][]const u8 = undefined;
    var identities: [roots.len][64]u8 = undefined;
    var paths: [roots.len][]const u8 = undefined;
    for (roots, 0..) |root, i| {
        const entry = try ctx.field(functions, root);
        try ctx.require(c.flag(entry, "requested", true), "missing requested publication root");
        paths[i] = try z.translate.capturedPath(ctx, io, report_path, entry);
        const record = try z.files.readJson(ctx, io, paths[i]);
        records[i] = record.bytes;
        identities[i] = c.digest(record.bytes);
        try ctx.require(c.tag(entry, "sha256", &identities[i]) and c.tag(record.value, "sourceSha256", source_sha) and
            c.tag(record.value, "sourceFile", source_name) and c.tag(record.value, "name", root), "publication AIR identity mismatch");
        try ctx.require(c.equal(try ctx.field(entry, "sourceOperationTags"), try ctx.field(record.value, "sourceOperationTags")), "source operation inventory mismatch");
        // Validate the ordinary capture envelope, parameter types, target and source conditions.
        // Only the protocol-specific Lean decoder below interprets the instruction bodies.
        _ = try z.air.Decoder.init(ctx, record.value, .memory);
        lifted[i] = try z.certificate.lift(ctx, record.value, 0);
    }
    const module = try ctx.fmt(
        \\import Compiler.ZigAir.CapturedPublication
        \\open Compiler.ZigAir Compiler.ZigAir.AtomicPublication
        \\-- Source SHA-256: {s}
        \\-- Capture report SHA-256: {s}
        \\-- Writer AIR SHA-256: {s}
        \\def writer : Captured.Raw := {s}
        \\-- Reader AIR SHA-256: {s}
        \\def reader : Captured.Raw := {s}
        \\set_option maxRecDepth 8192 in
        \\theorem correspondence : CapturedPublication.decode writer reader = some publication := rfl
        \\theorem captured_publication_safe :
        \\    ∀ p, CapturedPublication.decode writer reader = some p → Safe p := by
        \\  intro p h
        \\  rw [correspondence] at h
        \\  cases h
        \\  exact publication_safe
        \\
        \\-- Admission controls over mutated copies of the two records above.
        \\{s}
    , .{ source_sha, &c.digest(captured.bytes), &identities[0], lifted[0], &identities[1], lifted[1], try rejectionControls(ctx, records) });
    const evidence = try z.toolchain.newOutput(ctx, io, output);
    const proof_dir = try z.files.join(ctx, &.{ evidence, "certificate" });
    try z.certificate.checkModule(ctx, io, proof_dir, module, environment, lake, "Compiler.ZigAir.CapturedPublication");
    for (paths, identities) |path, identity| try ctx.require(std.mem.eql(u8, &(try z.runtime.fileDigest(ctx, io, path)), &identity), "publication AIR changed during checking");
    try ctx.require(std.mem.eql(u8, &(try z.runtime.fileDigest(ctx, io, report_path)), &c.digest(captured.bytes)) and
        std.mem.eql(u8, &(try z.runtime.fileDigest(ctx, io, source_path)), source_sha), "publication capture changed during checking");
    const result = try ctx.parse(try ctx.json(.{
        .schema = "zean.atomic-publication.v1",
        .status = "passed",
        .certificate = "certificate/Certificate.lean",
        .certificateSha256 = &c.digest(module),
        .sourceSha256 = source_sha,
        .objectSha256 = object_sha,
        .captureSha256 = &c.digest(captured.bytes),
        .writerAirSha256 = &identities[0],
        .readerAirSha256 = &identities[1],
        .sourceSafetyVerified = false,
        .nativeRefinementVerified = false,
    }));
    try z.files.write(io, try z.files.join(ctx, &.{ evidence, "report.json" }), try ctx.json(result));
    return result;
}
