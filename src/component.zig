// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Complete declaration inventories and fresh admission measurements. Rejected
//! code is retained as evidence, never silently replaced by a model summary.
const std = @import("std");
const z = @import("root.zig");
const c = z.common;
const files = @import("files.zig");

pub const FunctionRange = struct { name: []const u8, start: usize, end: usize, sha: []const u8, returns_view: bool };

pub fn functionRanges(ctx: *c.Context, tree: std.zig.Ast) ![]FunctionRange {
    var ranges: std.ArrayList(FunctionRange) = .empty;
    for (0..tree.nodes.len) |raw_index| {
        const node: std.zig.Ast.Node.Index = @fromBackingInt(@intCast(raw_index));
        if (tree.nodeTag(node) != .fn_decl) continue;
        var buffer: [1]std.zig.Ast.Node.Index = undefined;
        const function = tree.fullFnProto(&buffer, node) orelse continue;
        const name = function.name_token orelse continue;
        const first = tree.tokenStart(tree.firstToken(node));
        const last = tree.lastToken(node);
        const end = tree.tokenStart(last) + tree.tokenSlice(last).len;
        var view = false;
        if (function.ast.return_type.unwrap()) |ty| {
            var token = tree.firstToken(ty);
            while (token <= tree.lastToken(ty)) : (token += 1) {
                if (tree.tokenTag(token) == .asterisk or
                    (tree.tokenTag(token) == .l_bracket and tree.tokenTag(token + 1) == .r_bracket)) view = true;
            }
        }
        try ranges.append(ctx.allocator, .{ .name = tree.tokenSlice(name), .start = first, .end = end, .sha = try ctx.allocator.dupe(u8, &c.digest(tree.source[first..end])), .returns_view = view });
    }
    return ranges.items;
}

pub fn declarations(ctx: *c.Context, bytes: []const u8) !c.Value {
    var parsed = try z.source.Declarations.init(ctx, bytes);
    defer parsed.deinit();
    var entries: c.Value = .{ .array = std.array_list.Managed(c.Value).init(ctx.allocator) };
    for (try functionRanges(ctx, parsed.tree)) |range|
        try entries.array.append(try ctx.parse(try ctx.json(.{ .name = range.name, .startByte = range.start, .endByte = range.end, .declarationSha256 = range.sha })));
    return entries;
}

pub const Options = struct { toolchain: []const u8, output: []const u8 };
pub const roots: []const []const u8 = &.{ "client.append", "client.append_slice", "client.append_reserved", "client.clear", "client.release", "client.reset" };

pub fn run(ctx: *c.Context, io: std.Io, options: Options, environment: *const std.process.Environ.Map) !c.Value {
    const output = try z.toolchain.newOutput(ctx, io, options.output);
    var report = try ctx.parse(try ctx.json(.{ .schema = "zean.component-evaluation.v1", .status = "failed", .component = "std.ArrayList(u8) backed by std.heap.FixedBufferAllocator", .scope = "six driver entry points; complete source declaration inventories; uninstantiated methods remain untested", .sourceSafetyVerified = false, .nativeRefinementVerified = false, .wholeComponentVerified = false, .provenance = try z.provenance.identity(ctx) }));
    defer files.write(io, files.join(ctx, &.{ output, "report.json" }) catch unreachable, ctx.json(report) catch "{\"status\":\"failed\"}") catch {};
    const toolchain = try files.readJson(ctx, io, options.toolchain);
    const lib = try ctx.str(try ctx.field(try ctx.field(toolchain.value, "compiler"), "zigLibDir"));
    var inventory: c.Value = .{ .object = .empty };
    for ([_][]const u8{ "std/array_list.zig", "std/heap/FixedBufferAllocator.zig" }) |path| {
        const bytes = try ctx.read(io, try files.join(ctx, &.{ lib, path }), c.max_json_bytes);
        const snapshot = try files.join(ctx, &.{ output, path });
        try std.Io.Dir.cwd().createDirPath(io, std.fs.path.dirname(snapshot).?);
        try files.write(io, snapshot, bytes);
        try inventory.object.put(ctx.allocator, path, try ctx.parse(try ctx.json(.{ .sha256 = &c.digest(bytes), .declarations = try declarations(ctx, bytes) })));
    }
    try z.toolchain.set(ctx, &report, "sourceInventory", inventory);
    const captureDirectory = try files.join(ctx, &.{ output, "capture" });
    const driver = try files.join(ctx, &.{ z.project_root, "examples/allocator/client.zig" });
    const captured = try z.capture.run(ctx, io, .{ .toolchain = options.toolchain, .source = driver, .roots = roots, .output = captureDirectory, .environment = environment });
    const capturedSources = try ctx.field(captured, "sourceFiles");
    var inventoryEntries = inventory.object.iterator();
    while (inventoryEntries.next()) |entry| {
        const sha = try ctx.str(try ctx.field(entry.value_ptr.*, "sha256"));
        try ctx.require(c.tag(capturedSources, entry.key_ptr.*["std/".len..], sha), "component inventory differs from captured source");
        const snapshot = try ctx.read(io, try files.join(ctx, &.{ output, entry.key_ptr.* }), c.max_json_bytes);
        try ctx.require(std.mem.eql(u8, sha, &c.digest(snapshot)), "retained component inventory source changed");
    }
    try z.toolchain.set(ctx, &report, "capture", .{ .report = "capture/report.json", .nativeObjectComparisons = true, .sourceSha256 = try ctx.field(captured, "sourceSha256"), .toolchainReportSha256 = &c.digest(toolchain.bytes) });
    var results: c.Value = .{ .object = .empty };
    for (roots) |root| {
        const name = root["client.".len..];
        const destination = try files.join(ctx, &.{ output, name });
        const options2: z.translate.Options = .{ .capture = try files.join(ctx, &.{ captureDirectory, "report.json" }), .roots = &.{root}, .profile = .nested_calls, .call_machine = true, .output = destination, .certify = try ctx.fmt("{s}-certificate", .{destination}), .environment = environment };
        const translation = z.translate.run(ctx, io, options2) catch |err| {
            // Once certificate checking has started, a failure is not evidence
            // of unsupported source admission (it may be a checker/tool error).
            if (err != error.InvalidInput or try files.exists(io, options2.certify.?)) return err;
            try results.object.put(ctx.allocator, root, try ctx.parse(try ctx.json(.{ .status = "rejected", .diagnostic = ctx.diagnostic, .safetyProved = false })));
            continue;
        };
        try results.object.put(ctx.allocator, root, try ctx.parse(try ctx.json(.{ .status = "certified", .translation = translation, .safetyProved = false })));
    }
    try z.toolchain.set(ctx, &report, "entryPoints", results);
    try z.provenance.verifyWorkspace(ctx, io);
    try z.toolchain.set(ctx, &report, "status", "measured");
    return report;
}
