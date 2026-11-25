// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Shared, fail-closed import resolution and sequential Lean module checking.
const std = @import("std");
const c = @import("common.zig");
const files = @import("files.zig");
const runtime = @import("runtime.zig");

pub const Import = struct { original: []const u8, fresh: []const u8 };

// The supported header grammar deliberately excludes module modifiers and
// multi-module import lines. Comments may nest; imports cannot hide in them.
fn skipTrivia(ctx: *c.Context, source: []const u8, cursor: *usize) !void {
    while (cursor.* < source.len) {
        if (std.ascii.isWhitespace(source[cursor.*])) {
            cursor.* += 1;
            continue;
        }
        if (std.mem.startsWith(u8, source[cursor.*..], "--")) {
            while (cursor.* < source.len and source[cursor.*] != '\n') cursor.* += 1;
        } else if (std.mem.startsWith(u8, source[cursor.*..], "/-")) {
            cursor.* += 2;
            var depth: usize = 1;
            while (depth > 0) {
                try ctx.require(cursor.* < source.len, "unterminated Lean header comment");
                if (std.mem.startsWith(u8, source[cursor.*..], "/-")) {
                    depth += 1;
                    cursor.* += 2;
                } else if (std.mem.startsWith(u8, source[cursor.*..], "-/")) {
                    depth -= 1;
                    cursor.* += 2;
                } else cursor.* += 1;
            }
        } else break;
    }
}

pub const Header = struct { imports: []const []const u8, body: []const u8 };
pub fn header(ctx: *c.Context, source: []const u8) !Header {
    var cursor: usize = 0;
    var names: std.ArrayList([]const u8) = .empty;
    while (true) {
        try skipTrivia(ctx, source, &cursor);
        const start = cursor;
        while (cursor < source.len and !std.ascii.isWhitespace(source[cursor])) cursor += 1;
        const word = source[start..cursor];
        try ctx.require(!c.oneOf(word, &.{ "module", "prelude", "public", "private", "meta" }), "unsupported Lean client header modifier");
        if (!std.mem.eql(u8, word, "import")) return .{ .imports = names.items, .body = source[start..] };
        try skipTrivia(ctx, source, &cursor);
        const first = cursor;
        while (cursor < source.len and !std.ascii.isWhitespace(source[cursor])) cursor += 1;
        const name = source[first..cursor];
        try ctx.require(c.identifier(name, true), "invalid client import");
        try names.append(ctx.allocator, name);
        while (cursor < source.len and (source[cursor] == ' ' or source[cursor] == '\t' or source[cursor] == '\r')) cursor += 1;
        try ctx.require(cursor == source.len or source[cursor] == '\n' or std.mem.startsWith(u8, source[cursor..], "--"), "client imports require one module per line");
    }
}

pub fn replay(ctx: *c.Context, source: []const u8, libraries: []const []const u8, dependencies: []const Import) ![]const u8 {
    const parsed = try header(ctx, source);
    return ctx.fmt("{s}{s}", .{ try imports(ctx, parsed.imports, libraries, dependencies), parsed.body });
}

pub fn imports(ctx: *c.Context, names: []const []const u8, libraries: []const []const u8, dependencies: []const Import) ![]const u8 {
    var parts: std.ArrayList([]const u8) = .empty;
    for (names) |name| {
        var resolved: ?[]const u8 = null;
        for (dependencies) |dependency| if (std.mem.eql(u8, name, dependency.original)) {
            resolved = dependency.fresh;
            break;
        };
        if (resolved == null and c.oneOf(name, libraries)) resolved = name;
        const module = resolved orelse return ctx.fail("proof import {s} is undeclared or has not been checked yet", .{name});
        try parts.append(ctx.allocator, try ctx.fmt("import {s}\n", .{module}));
    }
    return std.mem.concat(ctx.allocator, u8, parts.items);
}

pub const Checked = struct { source: []const u8, object: []const u8 };

/// The caller retains input snapshots, receipts and artifact hashes. Every
/// module is checked with one worker after the two-worker library build.
pub fn check(ctx: *c.Context, io: std.Io, runner: runtime.Runner, lean: []const []const u8, environment: *const std.process.Environ.Map, output: []const u8, label: []const u8, name: []const u8, body: []const u8, memory_mib: usize) !Checked {
    try ctx.require(c.identifier(name, false), "invalid replay module name");
    const source = try files.join(ctx, &.{ output, try ctx.fmt("{s}.lean", .{name}) });
    const object = try files.join(ctx, &.{ output, try ctx.fmt("{s}.olean", .{name}) });
    try files.write(io, source, body);
    try runner.run(label, try std.mem.concat(ctx.allocator, []const u8, &.{ lean, &.{
        "-j", "1", "-M", try ctx.fmt("{d}", .{memory_mib}), try ctx.fmt("--root={s}", .{output}), "-o", object, source,
    } }), .{ .cwd = @import("build_options").project_root, .environ = environment });
    try ctx.require(std.mem.eql(u8, body, try ctx.read(io, source, c.max_json_bytes)), "proof replay input changed while checking");
    return .{ .source = source, .object = object };
}

pub fn compareBundle(ctx: *c.Context, retained: []const u8, fresh: []const u8, declaration: []const u8) !void {
    // Capture report/AIR hashes can change across runs; compare source identity
    // and the whole program instead of rewriting historical capture provenance.
    const marker = "-- Source SHA-256: ";
    const previous = std.mem.indexOf(u8, retained, marker) orelse return ctx.fail("retained program has no source identity", .{});
    const current = std.mem.indexOf(u8, fresh, marker) orelse return ctx.fail("fresh program has no source identity", .{});
    try ctx.require(previous + marker.len + 64 <= retained.len and current + marker.len + 64 <= fresh.len and std.mem.eql(u8, retained[previous .. previous + marker.len + 64], fresh[current .. current + marker.len + 64]), "checked-in program source identity is stale; review regeneration");
    const old_body = std.mem.indexOf(u8, retained, declaration) orelse return ctx.fail("retained bundle has no program declaration", .{});
    const new_body = std.mem.indexOf(u8, fresh, declaration) orelse return ctx.fail("fresh bundle has no program declaration", .{});
    try ctx.require(std.mem.eql(u8, try programText(ctx, retained[old_body..]), try programText(ctx, fresh[new_body..])), "checked-in program is stale; review regeneration");
}

// A multi-root bundle has per-function AIR provenance between declarations.
// Exclude only those producer-owned comment lines, keeping every declaration.
fn programText(ctx: *c.Context, text: []const u8) ![]const u8 {
    var lines = std.mem.splitScalar(u8, text, '\n');
    var result: std.ArrayList([]const u8) = .empty;
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "-- AIR SHA-256: ")) continue;
        try result.append(ctx.allocator, line);
    }
    return std.mem.join(ctx.allocator, "\n", result.items);
}
