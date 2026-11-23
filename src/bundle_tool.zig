// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Build-time producer for the standalone executable's compiler archive.
const std = @import("std");
const builtin = @import("builtin");
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
    const dependencies = switch (builtin.target.os.tag) {
        .macos => try macLibraries(ctx, io, compiler.executable, report.value),
        .linux => try linuxLibraries(ctx, io, compiler.executable),
        else => return ctx.fail("standalone packaging supports macOS and Linux", .{}),
    };

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

const Libraries = std.StringArrayHashMapUnmanaged([]const u8);

fn addLibrary(ctx: *z.common.Context, io: std.Io, result: *Libraries, name: []const u8, path: []const u8) !void {
    try ctx.require(Dir.path.isAbsolute(path) and std.mem.eql(u8, name, Dir.path.basename(name)), "invalid native library path");
    const real = try Dir.cwd().realPathFileAlloc(io, path, ctx.allocator);
    const entry = try result.getOrPut(ctx.allocator, name);
    if (entry.found_existing) {
        try ctx.require(std.mem.eql(u8, entry.value_ptr.*, real), "native libraries use the same filename for different dependencies");
    } else {
        entry.value_ptr.* = real;
    }
}

fn macLibraries(ctx: *z.common.Context, io: std.Io, executable: []const u8, report: z.common.Value) !Libraries {
    var result: Libraries = .empty;
    const llvm = try ctx.field(report, "llvm");
    const prefixes = [2][]const u8{ try ctx.str(try ctx.field(llvm, "prefix")), try ctx.str(try ctx.field(llvm, "lldPrefix")) };
    try addMacDependencies(ctx, io, &result, executable, &prefixes);
    var index: usize = 0;
    while (index < result.count()) : (index += 1) {
        try addMacDependencies(ctx, io, &result, result.values()[index], &prefixes);
    }
    return result;
}

fn addMacDependencies(ctx: *z.common.Context, io: std.Io, result: *Libraries, path: []const u8, prefixes: []const []const u8) !void {
    const listing = try dependencyList(ctx, io, &.{ "/usr/bin/otool", "-L", path });
    var lines = std.mem.splitScalar(u8, listing, '\n');
    _ = lines.next(); // image name
    while (lines.next()) |line| {
        const dependency = nameBeforeVersion(line) orelse continue;
        if (std.mem.startsWith(u8, dependency, "/usr/lib/") or std.mem.startsWith(u8, dependency, "/System/Library/")) continue;
        const name = Dir.path.basename(dependency);
        if (Dir.path.isAbsolute(dependency)) {
            try addLibrary(ctx, io, result, name, dependency);
        } else if (std.mem.startsWith(u8, dependency, "@rpath/")) {
            if (result.contains(name)) continue;
            for (prefixes) |prefix| {
                const candidate = try z.files.join(ctx, &.{ prefix, "lib", name });
                if (!try z.files.exists(io, candidate)) continue;
                try addLibrary(ctx, io, result, name, candidate);
                break;
            } else return ctx.fail("could not resolve native library {s}", .{dependency});
        } else return ctx.fail("unsupported native library reference {s}", .{dependency});
    }
}

fn nameBeforeVersion(line: []const u8) ?[]const u8 {
    const trimmed = std.mem.trim(u8, line, " \t\r");
    const end = std.mem.lastIndexOf(u8, trimmed, " (") orelse return null;
    return trimmed[0..end];
}

fn linuxLibraries(ctx: *z.common.Context, io: std.Io, executable: []const u8) !Libraries {
    var result: Libraries = .empty;
    const listing = try dependencyList(ctx, io, &.{ "ldd", executable });
    var lines = std.mem.splitScalar(u8, listing, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        const separator = std.mem.indexOf(u8, trimmed, " => ") orelse {
            if (trimmed.len == 0 or std.mem.startsWith(u8, trimmed, "linux-vdso") or
                std.mem.startsWith(u8, Dir.path.basename(trimmed), "ld-linux") or
                std.mem.eql(u8, trimmed, "statically linked")) continue;
            return ctx.fail("unsupported ldd entry {s}", .{trimmed});
        };
        const name = trimmed[0..separator];
        const dependency = nameBeforeVersion(trimmed[separator + " => ".len ..]) orelse
            return ctx.fail("could not resolve native library {s}", .{name});
        if (z.common.oneOf(name, &.{ "libc.so.6", "libm.so.6", "libpthread.so.0", "librt.so.1", "libdl.so.2" })) continue;
        try addLibrary(ctx, io, &result, name, dependency);
    }
    return result;
}

fn dependencyList(ctx: *z.common.Context, io: std.Io, argv: []const []const u8) ![]const u8 {
    const result = try std.process.run(ctx.allocator, io, .{
        .argv = argv,
        .stdout_limit = .limited(1024 * 1024),
        .stderr_limit = .limited(1024 * 1024),
    });
    if (result.term != .exited or result.term.exited != 0) {
        if (std.mem.eql(u8, argv[0], "ldd") and std.mem.indexOf(u8, result.stderr, "not a dynamic executable") != null)
            return "statically linked";
        return ctx.fail("{s} failed for {s} ({s})", .{ argv[0], argv[argv.len - 1], result.stderr });
    }
    return result.stdout;
}
