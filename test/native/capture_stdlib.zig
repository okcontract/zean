// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");

pub fn controls() !void {
    const definition = "pub fn check(value: bool) bool { return value; }";
    const Case = struct {
        source: []const u8 = "checks.zig",
        changed: bool = false,
        collision: bool = false,
        air_changed: bool = false,
        accepted: bool = false,
    };
    for ([_]Case{
        .{ .accepted = true },    .{ .changed = true },           .{ .collision = true },
        .{ .air_changed = true }, .{ .source = "../checks.zig" }, .{ .source = "/checks.zig" },
    }) |case| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var ctx: z.common.Context = .{ .allocator = arena.allocator() };
        var tmp = std.testing.tmpDir(.{});
        defer tmp.cleanup();
        const path = try std.fs.path.resolve(ctx.allocator, &.{ ".zig-cache", "tmp", &tmp.sub_path });
        try tmp.dir.createDirPath(std.testing.io, "lib/std");
        try tmp.dir.createDirPath(std.testing.io, "capture/air");
        try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "lib/std/checks.zig", .data = if (case.changed) definition ++ "// changed" else definition });
        const record = try ctx.json(.{ .name = "checks.check", .sourceFile = case.source, .sourceSha256 = &z.common.digest(definition) });
        try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "capture/air/check.json", .data = record });
        var hashes: z.common.Value = .{ .object = .empty };
        if (case.collision) try hashes.object.put(ctx.allocator, "checks.zig", .{ .string = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" });
        const functions = try ctx.parse(try ctx.json(.{ .@"checks.check" = .{ .file = "check.json", .sha256 = &z.common.digest(if (case.air_changed) "different AIR" else record) } }));
        const lib = try std.fs.path.join(ctx.allocator, &.{ path, "lib" });
        const output = try std.fs.path.join(ctx.allocator, &.{ path, "capture" });
        if (z.capture_stdlib.collect(&ctx, std.testing.io, lib, output, functions, &hashes)) |_| {
            try std.testing.expect(case.accepted);
            try std.testing.expect(z.common.tag(hashes, "checks.zig", &z.common.digest(definition)));
            const copy = try ctx.read(std.testing.io, try std.fs.path.join(ctx.allocator, &.{ output, "checks.zig" }), 1024);
            try std.testing.expectEqualStrings(definition, copy);
        } else |err| {
            if (err != error.InvalidInput) return err;
            try std.testing.expect(!case.accepted);
        }
    }
}
