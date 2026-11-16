// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const builtin = @import("builtin");
const c = @import("common.zig");
const files = @import("files.zig");
const signals = @import("process_signals.zig");
pub const RunOptions = struct { cwd: ?[]const u8 = null, environ: ?*const std.process.Environ.Map = null, timeout_ms: u64 = 1_800_000 };
pub const Runner = struct {
    ctx: *c.Context,
    io: std.Io,
    output: []const u8,
    pub fn run(self: Runner, name: []const u8, argv: []const []const u8, options: RunOptions) !void {
        const ctx = self.ctx;
        const io = self.io;
        const stdout_path = try files.join(ctx, &.{ self.output, try ctx.fmt("{s}.stdout", .{name}) });
        const stderr_path = try files.join(ctx, &.{ self.output, try ctx.fmt("{s}.stderr", .{name}) });
        const receipt_path = try files.join(ctx, &.{ self.output, try ctx.fmt("{s}.process.json", .{name}) });
        const started = std.Io.Clock.awake.now(io);
        const cwd = if (options.cwd) |path| try std.fs.path.resolve(ctx.allocator, &.{path}) else try std.process.currentPathAlloc(io, ctx.allocator);
        var status: []const u8 = "failed";
        var terminal: ?i64 = null;
        var max_rss: ?usize = null;
        var failure: ?[]const u8 = null;
        defer {
            const elapsed = started.durationTo(std.Io.Clock.awake.now(io)).toMilliseconds();
            const receipt = ctx.json(.{ .command = argv, .cwd = cwd, .status = status, .exitCode = terminal, .milliseconds = elapsed, .seconds = @as(f64, @floatFromInt(elapsed)) / 1000, .maxRssBytes = max_rss, .resourceUsageScope = "waited-child", .@"error" = failure }) catch "{\"status\":\"failed\"}";
            files.write(io, receipt_path, receipt) catch {};
        }
        const stdout = try std.Io.Dir.cwd().createFile(io, stdout_path, .{});
        defer stdout.close(io);
        const stderr = try std.Io.Dir.cwd().createFile(io, stderr_path, .{});
        defer stderr.close(io);
        const signal_guard = try signals.Guard.start();
        defer signal_guard.restore();
        var child = std.process.spawn(io, .{ .argv = argv, .cwd = if (options.cwd) |path| .{ .path = path } else .inherit, .environ_map = options.environ, .stdin = .ignore, .stdout = .{ .file = stdout }, .stderr = .{ .file = stderr }, .pgid = if (builtin.os.tag == .windows or builtin.os.tag == .wasi) null else 0, .request_resource_usage_statistics = true }) catch |err| {
            failure = @errorName(err);
            return err;
        };
        const pid = child.id.?;
        signal_guard.attach(pid);
        defer child.kill(io);
        const Event = union(enum) { exited: std.process.Child.WaitError!std.process.Child.Term, expired: std.Io.Cancelable!void };
        var events: [2]Event = undefined;
        var selection = std.Io.Select(Event).init(io, &events);
        defer selection.cancelDiscard();
        var wait_completed = false;
        // Kill before canceling a pending wait, which relinquishes the child id.
        errdefer {
            if (!wait_completed and signals.supported) std.posix.kill(-pid, .KILL) catch {};
        }
        // Async dispatch may run inline when its CPU-based worker limit is full.
        // Both waits must remain concurrent for deadlines to stay effective.
        selection.concurrent(.exited, std.process.Child.wait, .{ &child, io }) catch |err| {
            failure = @errorName(err);
            return err;
        };
        selection.concurrent(.expired, std.Io.sleep, .{ io, std.Io.Duration.fromMilliseconds(@intCast(options.timeout_ms)), .awake }) catch |err| {
            failure = @errorName(err);
            return err;
        };
        const event = try selection.await();
        var timed_out = false;
        const term = blk: switch (event) {
            .exited => |result| break :blk try result,
            .expired => |result| {
                try result;
                timed_out = true;
                failure = "Timeout";
                if (builtin.os.tag != .windows and builtin.os.tag != .wasi) std.posix.kill(-pid, .KILL) catch {} else child.kill(io);
                while (true) switch (try selection.await()) {
                    .exited => |result2| break :blk try result2,
                    .expired => {},
                };
            },
        };
        wait_completed = true;
        max_rss = child.resource_usage_statistics.getMaxRss();
        terminal = switch (term) {
            .exited => |code| code,
            .signal => |signal| -@as(i64, @backingInt(signal)),
            else => -1,
        };
        if (signal_guard.wasInterrupted()) {
            failure = "Interrupted";
            return error.Canceled;
        }
        if (timed_out) return error.Timeout;
        status = "completed";
        if (terminal.? != 0) return ctx.fail("{s} failed; inspect retained stdout/stderr", .{name});
    }
    pub fn text(self: Runner, name: []const u8) ![]const u8 {
        return std.mem.trim(u8, try self.ctx.read(self.io, try files.join(self.ctx, &.{ self.output, try self.ctx.fmt("{s}.stdout", .{name}) }), 1024 * 1024), " \t\r\n");
    }
};

pub fn fileDigest(ctx: *c.Context, io: std.Io, path: []const u8) ![64]u8 {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    var reader_buffer: [16 * 1024]u8 = undefined;
    var reader = file.reader(io, &reader_buffer);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    var buffer: [16 * 1024]u8 = undefined;
    while (true) {
        const count = try reader.interface.readSliceShort(&buffer);
        if (count == 0) break;
        hash.update(buffer[0..count]);
    }
    var result: [32]u8 = undefined;
    hash.final(&result);
    _ = ctx;
    return std.fmt.bytesToHex(result, .lower);
}
pub fn sourceIdentity(ctx: *c.Context, io: std.Io, tree: []const u8) !c.Value {
    var directory = try std.Io.Dir.cwd().openDir(io, tree, .{ .iterate = true });
    defer directory.close(io);
    var walker = try directory.walk(ctx.allocator);
    defer walker.deinit();
    var names: std.ArrayList([]const u8) = .empty;
    while (try walker.next(io)) |entry| {
        try ctx.require(entry.kind == .file or entry.kind == .directory, "unexpected link in isolated source tree");
        if (entry.kind == .file) try names.append(ctx.allocator, try ctx.allocator.dupe(u8, entry.path));
    }
    std.mem.sort([]const u8, names.items, {}, struct {
        fn less(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.less);
    var entries: c.Value = .{ .object = .empty };
    for (names.items) |name| {
        const sha = try fileDigest(ctx, io, try files.join(ctx, &.{ tree, name }));
        try entries.object.put(ctx.allocator, name, .{ .string = try ctx.allocator.dupe(u8, &sha) });
    }
    const encoded = try std.json.Stringify.valueAlloc(ctx.allocator, entries, .{ .escape_unicode = true });
    return ctx.parse(try ctx.json(.{ .files = names.items.len, .sha256 = &c.digest(encoded) }));
}

pub fn safeArchiveName(name: []const u8) bool {
    if (name.len == 0 or std.fs.path.isAbsolute(name) or std.mem.indexOfScalar(u8, name, '\\') != null) return false;
    var parts = std.mem.splitScalar(u8, name, '/');
    while (parts.next()) |part| if (std.mem.eql(u8, part, "..")) return false;
    return true;
}
pub fn inspectArchive(ctx: *c.Context, reader: *std.Io.Reader) !void {
    var names: [std.fs.max_path_bytes]u8 = undefined;
    var links: [std.fs.max_path_bytes]u8 = undefined;
    var iterator = std.tar.Iterator.init(reader, .{ .file_name_buffer = &names, .link_name_buffer = &links });
    while (try iterator.next()) |entry| try ctx.require(safeArchiveName(entry.name) and entry.kind != .sym_link, "unsafe or unsupported source archive member");
}
pub fn unpack(ctx: *c.Context, io: std.Io, archive: []const u8, destination: []const u8) !void {
    const bytes = try ctx.read(io, archive, 512 * 1024 * 1024);
    var first = std.Io.Reader.fixed(bytes);
    try inspectArchive(ctx, &first);
    // Validate the complete archive before creating any output.
    try std.Io.Dir.cwd().createDir(io, destination, .default_dir);
    var reader = std.Io.Reader.fixed(bytes);
    var names: [std.fs.max_path_bytes]u8 = undefined;
    var links: [std.fs.max_path_bytes]u8 = undefined;
    var iterator = std.tar.Iterator.init(&reader, .{ .file_name_buffer = &names, .link_name_buffer = &links });
    while (try iterator.next()) |entry| {
        const path = try files.join(ctx, &.{ destination, entry.name });
        if (entry.kind == .directory) {
            try std.Io.Dir.cwd().createDirPath(io, path);
            continue;
        }
        if (std.fs.path.dirname(path)) |parent| try std.Io.Dir.cwd().createDirPath(io, parent);
        const content = try reader.take(@intCast(entry.size));
        iterator.unread_file_bytes = 0;
        const file = try std.Io.Dir.cwd().createFile(io, path, .{ .permissions = @fromBackingInt(@as(std.posix.mode_t, @intCast(entry.mode & 0o777))) });
        defer file.close(io);
        try file.writeStreamingAll(io, content);
    }
}
