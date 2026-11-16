// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");

const Graph = std.StringHashMap([]const []const u8);
const core = "Compiler.ZigAir.Verify.Core";
const pure = "Compiler.ZigAir.MemoryInitializedWords";

fn prefix(name: []const u8, namespace: []const u8) bool {
    return std.mem.eql(u8, name, namespace) or (std.mem.startsWith(u8, name, namespace) and name.len > namespace.len and name[namespace.len] == '.');
}

fn allowed(from: []const u8, to: []const u8) bool {
    if (!prefix(from, "Compiler.Tests") and prefix(to, "Compiler.Tests")) return false;
    if (!prefix(from, "Compiler.Tests") and !prefix(from, "Compiler.Baselines") and prefix(to, "Compiler.Baselines")) return false;
    if (prefix(from, "Compiler.ZigAir") and prefix(to, "Compiler") and !prefix(to, "Compiler.ZigAir")) return false;
    return true;
}

fn optional(name: []const u8) bool {
    return std.mem.endsWith(u8, name, "Automation") and !std.mem.eql(u8, name, "Compiler.ZigAir.MemoryAutomation") or
        prefix(name, "Compiler.ZigAir.Verify.Machine") or prefix(name, "Compiler.ZigAir.Verify.Words") or prefix(name, "Compiler.ZigAir.Verify.Slices") or prefix(name, "Compiler.ZigAir.Verify.Bytes") or
        std.mem.eql(u8, name, "Compiler.ZigAir.Verify") or
        std.mem.eql(u8, name, "Compiler.ZigAir.MemoryCallWP") or std.mem.eql(u8, name, "Compiler.ZigAir.MemorySliceWP") or
        std.mem.eql(u8, name, "Compiler.ZigAir.MemoryWordCopyFrame");
}

fn verification(name: []const u8) bool {
    return prefix(name, "Compiler.ZigAir.Verify") or std.mem.endsWith(u8, name, "WP") or
        std.mem.endsWith(u8, name, "Automation") or std.mem.endsWith(u8, name, "Bindings") or
        std.mem.eql(u8, name, "Compiler.ZigAir.MemoryVerification") or std.mem.eql(u8, name, "Compiler.ZigAir.ControlVerification");
}

fn checkClosure(a: std.mem.Allocator, graph: Graph, root: []const u8, forbidden: *const fn ([]const u8) bool) !void {
    var seen = std.StringHashMap(void).init(a);
    defer seen.deinit();
    var pending: std.ArrayList([]const u8) = .empty;
    defer pending.deinit(a);
    try pending.append(a, root);
    while (pending.pop()) |name| {
        if (forbidden(name)) return error.InvalidLayer;
        if ((try seen.getOrPut(name)).found_existing) continue;
        if (graph.get(name)) |imports| try pending.appendSlice(a, imports);
    }
}

fn validate(a: std.mem.Allocator, graph: Graph) !void {
    var entries = graph.iterator();
    while (entries.next()) |entry| for (entry.value_ptr.*) |name| {
        if (!allowed(entry.key_ptr.*, name)) return error.InvalidLayer;
        if ((prefix(name, "Compiler") or prefix(name, "Contract")) and !graph.contains(name)) return error.MissingModule;
    };
    try checkClosure(a, graph, core, optional);
    try checkClosure(a, graph, pure, verification);
}

pub fn controls() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    // Independently specified layering examples; each mutation changes one edge.
    const baseline = [_]struct { name: []const u8, imports: []const []const u8 }{
        .{ .name = core, .imports = &.{"Compiler.ZigAir.MemoryAutomation"} },
        .{ .name = "Compiler.ZigAir.MemoryAutomation", .imports = &.{"Compiler.ZigAir.MemoryAir"} },
        .{ .name = "Compiler.ZigAir.MemoryAir", .imports = &.{} },
        .{ .name = pure, .imports = &.{"Compiler.ZigAir.MemorySliceLaws"} },
        .{ .name = "Compiler.ZigAir.MemorySliceLaws", .imports = &.{"Compiler.ZigAir.MemoryAir"} },
        .{ .name = "Compiler.ZigAir.MemorySliceWP", .imports = &.{"Compiler.ZigAir.MemorySliceLaws"} },
        .{ .name = "Compiler.ZigAir.MemoryWordAutomation", .imports = &.{} },
        .{ .name = "Compiler.Tests.Control", .imports = &.{core} },
        .{ .name = "Compiler.Captures.Example", .imports = &.{"Compiler.ZigAir.MemoryAir"} },
        .{ .name = "Compiler.Baselines.Example", .imports = &.{core} },
        .{ .name = "Compiler.Tutorial.Example", .imports = &.{core} },
    };
    var fixture = Graph.init(a);
    for (baseline) |entry| try fixture.put(entry.name, entry.imports);
    try validate(a, fixture);
    for ([_]struct { from: []const u8, to: []const u8, expected: anyerror }{
        .{ .from = core, .to = "Compiler.Tests.Control", .expected = error.InvalidLayer },
        .{ .from = "Compiler.ZigAir.MemoryAir", .to = "Compiler.Captures.Example", .expected = error.InvalidLayer },
        .{ .from = "Compiler.Tutorial.Example", .to = "Compiler.Baselines.Example", .expected = error.InvalidLayer },
        .{ .from = "Compiler.ZigAir.MemoryAutomation", .to = "Compiler.ZigAir.MemoryWordAutomation", .expected = error.InvalidLayer },
        .{ .from = "Compiler.ZigAir.MemorySliceLaws", .to = "Compiler.ZigAir.MemorySliceWP", .expected = error.InvalidLayer },
        .{ .from = core, .to = "Compiler.ZigAir.Missing", .expected = error.MissingModule },
    }) |mutation| {
        const original = fixture.get(mutation.from).?;
        try fixture.put(mutation.from, &.{mutation.to});
        try std.testing.expectError(mutation.expected, validate(a, fixture));
        try fixture.put(mutation.from, original);
    }

    var ctx: z.common.Context = .{ .allocator = a };
    var graph = Graph.init(a);
    var dir = try std.Io.Dir.cwd().openDir(std.testing.io, try ctx.fmt("{s}/lean", .{z.project_root}), .{ .iterate = true });
    defer dir.close(std.testing.io);
    var walker = try dir.walk(a);
    defer walker.deinit();
    while (try walker.next(std.testing.io)) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.path, ".lean")) continue;
        const name = try a.dupe(u8, entry.path[0 .. entry.path.len - 5]);
        std.mem.replaceScalar(u8, name, '/', '.');
        const source = try dir.readFileAlloc(std.testing.io, entry.path, a, .limited(4 * 1024 * 1024));
        var imports: std.ArrayList([]const u8) = .empty;
        var lines = std.mem.splitScalar(u8, source, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (!std.mem.startsWith(u8, trimmed, "import ")) continue;
            var names = std.mem.tokenizeAny(u8, trimmed[7..], " \t\r");
            while (names.next()) |dependency| {
                if (std.mem.startsWith(u8, dependency, "--")) break;
                try imports.append(a, dependency);
            }
        }
        try graph.put(name, imports.items);
    }
    try std.testing.expect(graph.contains(core) and graph.contains(pure));
    try validate(a, graph);
}
