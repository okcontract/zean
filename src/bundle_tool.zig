// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Build-time producer for the standalone executable's compiler archive.
const std = @import("std");
const z = @import("zean");
const bundle = z.bundled_compiler;
const Dir = std.Io.Dir;

pub fn main(init: std.process.Init) !void {
    var ctx: z.common.Context = .{ .allocator = init.arena.allocator() };
    const args = try init.minimal.args.toSlice(ctx.allocator);
    if (args.len != 3) return error.InvalidArguments;
    pack(&ctx, init.io, args[1], args[2]) catch |err| {
        std.debug.print("zean compiler bundle: {s} ({s})\n", .{ ctx.diagnostic, @errorName(err) });
        std.process.exit(1);
    };
}

fn pack(ctx: *z.common.Context, io: std.Io, report_path: []const u8, output: []const u8) !void {
    const report = try z.files.readJson(ctx, io, report_path);
    const compiler = try z.capture.validateCompiler(ctx, io, report.value, null);
    const dependencies = try z.bundle_dependencies.collect(ctx, io, compiler.executable, z.version);
    try z.bundle_dependencies.checkArchiveNames(ctx, dependencies.keys());

    const file = try Dir.cwd().createFile(io, output, .{});
    defer file.close(io);
    var out_buffer: [64 * 1024]u8 = undefined;
    var writer = file.writer(io, &out_buffer);
    var compression_buffer: [std.compress.flate.max_window_len]u8 = undefined;
    var compressor = try std.compress.flate.Compress.init(&writer.interface, &compression_buffer, .gzip, .level_2);
    var archive: std.tar.Writer = .{ .underlying_writer = &compressor.writer };
    try archive.writeFileBytes(bundle.report, report.bytes, .{});
    try copy(io, &archive, bundle.executable, compiler.executable, 0o755);
    try archive.writeDir(bundle.libraries, .{});
    const names = try ctx.allocator.dupe([]const u8, dependencies.keys());
    std.mem.sort([]const u8, names, {}, less);
    for (names) |name| {
        const member = try z.files.join(ctx, &.{ bundle.libraries, name });
        try copy(io, &archive, member, dependencies.get(name).?, 0o644);
    }

    const source_root = compiler.source().?;
    const source_dir = try Dir.cwd().openDir(io, source_root, .{ .iterate = true });
    defer source_dir.close(io);
    var walk = try source_dir.walk(ctx.allocator);
    defer walk.deinit();
    var sources: std.ArrayList([]const u8) = .empty;
    while (try walk.next(io)) |entry| {
        if (entry.kind == .directory) continue;
        try ctx.require(entry.kind == .file and z.runtime.safeArchiveName(entry.path), "unsupported compiler source entry");
        try sources.append(ctx.allocator, try ctx.allocator.dupe(u8, entry.path));
    }
    std.mem.sort([]const u8, sources.items, {}, less);
    for (sources.items) |path| {
        try copy(io, &archive, try z.files.join(ctx, &.{ bundle.source, path }), try z.files.join(ctx, &.{ source_root, path }), 0o644);
    }
    _ = try z.capture.validateCompiler(ctx, io, report.value, null);
    try archive.finishPedantically();
    try compressor.finish();
    try writer.flush();
}

fn less(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

fn copy(io: std.Io, archive: *std.tar.Writer, member: []const u8, path: []const u8, mode: u32) !void {
    const file = try Dir.cwd().openFile(io, path, .{ .allow_directory = false });
    defer file.close(io);
    const stat = try file.stat(io);
    if (stat.kind != .file) return error.NotRegularFile;
    var buffer: [64 * 1024]u8 = undefined;
    var reader = file.reader(io, &buffer);
    try archive.writeFileStream(member, stat.size, &reader.interface, .{ .mode = mode });
}
