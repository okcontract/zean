// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Native child fixture for process, timeout and capture orchestration tests.
const std = @import("std");
pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;
    const args = try init.minimal.args.toSlice(allocator);
    const mode = if (args.len > 1) args[1] else "";
    if (std.mem.eql(u8, mode, "fail")) {
        if (args.len > 2) {
            try std.Io.File.stdout().writeStreamingAll(io, args[2]);
            try std.Io.File.stdout().writeStreamingAll(io, "\n");
        }
        try std.Io.File.stderr().writeStreamingAll(io, "diagnostic\n");
        std.process.exit(7);
    }
    if (std.mem.eql(u8, mode, "large")) {
        const chunk: [8192]u8 = @splat('x');
        for (0..256) |_| {
            try std.Io.File.stdout().writeStreamingAll(io, &chunk);
            try std.Io.File.stderr().writeStreamingAll(io, &chunk);
        }
        return;
    }
    if (std.mem.eql(u8, mode, "marker")) {
        try std.Io.sleep(io, .fromMilliseconds(500), .awake);
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = args[2], .data = "survived" });
        return;
    }
    if (std.mem.eql(u8, mode, "group") or std.mem.eql(u8, mode, "interrupt")) {
        var child = try std.process.spawn(io, .{ .argv = &.{ args[0], "marker", args[2] }, .stdin = .ignore, .stdout = .ignore, .stderr = .ignore });
        defer child.kill(io);
        if (std.mem.eql(u8, mode, "interrupt")) try std.posix.kill(try std.fmt.parseInt(i32, args[3], 10), .INT);
        _ = try child.wait(io);
        try std.Io.sleep(io, .fromSeconds(5), .awake);
        return;
    }
    if (std.mem.eql(u8, mode, "version")) {
        try std.Io.File.stdout().writeStreamingAll(io, "0.17.1\n");
        return;
    }
    if (!std.mem.eql(u8, mode, "build-obj")) return error.UnexpectedFixtureInvocation;
    var output: ?[]const u8 = null;
    var source: ?[]const u8 = null;
    var directory: ?[]const u8 = null;
    for (args[2..]) |arg| {
        if (std.mem.startsWith(u8, arg, "-femit-bin=")) output = arg["-femit-bin=".len..];
        if (std.mem.startsWith(u8, arg, "--semantic-export=")) directory = arg["--semantic-export=".len..];
        if (std.mem.startsWith(u8, arg, "-Mroot=")) source = arg["-Mroot=".len..] else if (std.mem.endsWith(u8, arg, ".zig")) source = arg;
    }
    const behavior = init.environ_map.get("ZEAN_FIXTURE_MODE") orelse "";
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = output orelse return error.MissingOutput, .data = if (directory == null and std.mem.eql(u8, behavior, "object-mismatch")) "ordinary-differs" else "same-object" });
    const filename = source orelse return error.MissingSource;
    if (directory) |air_dir| {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(io, filename, allocator, .limited(1024 * 1024));
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(bytes, &hash, .{});
        const sha = std.fmt.bytesToHex(hash, .lower);
        const record = .{ .schema = "oksolc.fresh-air.v3", .capturePoint = "after-sema-before-legalize", .name = "fixture.add", .sourceFile = std.fs.path.basename(filename), .sourceSha256 = &sha, .sourceValidityConditionsPreserved = false, .sourceValidity = .{ .schema = "oksolc.source-validity.v1", .coverage = "runtime-slice-results", .complete = false, .slices = [_]u64{} }, .sourceOperationTags = .{"ret_node"}, .configuration = .{ .optimize = "ReleaseFast", .useLlvm = true, .isTest = false }, .body = [_]u64{0}, .instructions = .{.{ .index = 0, .tag = "future_opcode", .unsupportedPayload = true }} };
        const path = try std.fs.path.join(allocator, &.{ air_dir, "root.json" });
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = try std.json.Stringify.valueAlloc(allocator, record, .{}) });
    } else if (std.mem.eql(u8, behavior, "source-change")) try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = filename, .data = "// changed during capture\n" });
}
