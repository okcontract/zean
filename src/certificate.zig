// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Inert JSON lifting and kernel-checked AIR correspondence. Opcode interpretation
//! lives independently in Lean's Captured module, not in this producer.
const std = @import("std");
const c = @import("common.zig");
const z = @import("root.zig");
const files = @import("files.zig");
const runtime = @import("runtime.zig");
const lean_toolchain = @import("build_options").lean_toolchain;

pub fn string(ctx: *c.Context, value: []const u8) ![]const u8 {
    try ctx.require(std.unicode.utf8ValidateSlice(value), "certificate string is not UTF-8");
    var bytes: std.ArrayList(u8) = .empty;
    try bytes.append(ctx.allocator, '"');
    for (value) |byte| switch (byte) {
        '\\' => try bytes.appendSlice(ctx.allocator, "\\\\"),
        '"' => try bytes.appendSlice(ctx.allocator, "\\\""),
        '\n' => try bytes.appendSlice(ctx.allocator, "\\n"),
        '\r' => try bytes.appendSlice(ctx.allocator, "\\r"),
        '\t' => try bytes.appendSlice(ctx.allocator, "\\t"),
        else => {
            try ctx.require(byte >= 32 and byte != 127, "unsupported certificate string control character");
            try bytes.append(ctx.allocator, byte);
        },
    };
    try bytes.append(ctx.allocator, '"');
    return bytes.toOwnedSlice(ctx.allocator);
}

pub fn lift(ctx: *c.Context, value: c.Value, depth: usize) ![]const u8 {
    try ctx.require(depth <= 128, "certificate data nesting limit");
    switch (value) {
        .null => return ".null",
        .bool => |flag| return ctx.fmt("(.boolean {s})", .{c.boolText(flag)}),
        .integer, .number_string => return ctx.fmt("(.number ({d}))", .{try ctx.integer(value)}),
        .string => |text| return ctx.fmt("(.string {s})", .{try string(ctx, text)}),
        .array => |items| {
            var entries: std.ArrayList([]const u8) = .empty;
            for (items.items) |item| try entries.append(ctx.allocator, try lift(ctx, item, depth + 1));
            return ctx.fmt("(.array [{s}])", .{try std.mem.join(ctx.allocator, ", ", entries.items)});
        },
        .object => |fields| {
            var entries: std.ArrayList([]const u8) = .empty;
            for (fields.keys(), fields.values()) |key, item| try entries.append(ctx.allocator, try ctx.fmt("({s}, {s})", .{ try string(ctx, key), try lift(ctx, item, depth + 1) }));
            return ctx.fmt("(.object [{s}])", .{try std.mem.join(ctx.allocator, ",\n", entries.items)});
        },
        else => return ctx.fail("certificate numbers must be exact integers", .{}),
    }
}

pub fn declaration(ctx: *c.Context, record: c.Value, name: []const u8, loops: bool) ![]const u8 {
    try ctx.require(c.identifier(name, false), "invalid certificate declaration name");
    return ctx.fmt(
        \\def {s}_captured : Compiler.ZigAir.Captured.Raw :=
        \\{s}
        \\set_option maxRecDepth 8192 in
        \\set_option maxHeartbeats 2000000 in
        \\theorem {s}_correspondence :
        \\    Compiler.ZigAir.Captured.decode {s} {s}_captured = some {s} := by decide +kernel
        \\
    , .{ name, try lift(ctx, record, 0), name, c.boolText(loops), name, name });
}

pub fn scalarDeclaration(ctx: *c.Context, record: c.Value, name: []const u8) ![]const u8 {
    try ctx.require(c.identifier(name, false), "invalid certificate declaration name");
    return ctx.fmt(
        \\def {s}_captured : Compiler.ZigAir.Captured.Raw :=
        \\{s}
        \\set_option maxRecDepth 8192 in
        \\set_option maxHeartbeats 2000000 in
        \\theorem {s}_correspondence :
        \\    Compiler.ZigAir.CapturedScalar.decode {s}_captured = some {s} := by decide +kernel
        \\
    , .{ name, try lift(ctx, record, 0), name, name, name });
}

pub fn callDeclaration(ctx: *c.Context, record: c.Value, name: []const u8, loops: bool, callees: []const z.air.Callee) ![]const u8 {
    try ctx.require(c.identifier(name, false), "invalid certificate declaration name");
    var dependencies: std.ArrayList([]const u8) = .empty;
    for (callees) |callee| try dependencies.append(ctx.allocator, try ctx.fmt("{s}_captured", .{callee.declaration}));
    return ctx.fmt(
        \\def {s}_captured : Compiler.ZigAir.Captured.Raw :=
        \\{s}
        \\set_option maxRecDepth 8192 in
        \\set_option maxHeartbeats 4000000 in
        \\theorem {s}_correspondence :
        \\    Compiler.ZigAir.CapturedCalls.decode 64 {s} [{s}] {s}_captured = some {s} := rfl
        \\
    , .{ name, try lift(ctx, record, 0), name, c.boolText(loops), try std.mem.join(ctx.allocator, ", ", dependencies.items), name, name });
}

pub fn nestedDeclaration(ctx: *c.Context, record: c.Value, name: []const u8, callees: []const z.air.Callee) ![]const u8 {
    try ctx.require(c.identifier(name, false), "invalid certificate declaration name");
    var dependencies: std.ArrayList([]const u8) = .empty;
    for (callees) |callee| try dependencies.append(ctx.allocator, try ctx.fmt("{s}_captured", .{callee.declaration}));
    return ctx.fmt(
        \\def {s}_captured : Compiler.ZigAir.Captured.Raw :=
        \\{s}
        \\set_option maxRecDepth 16384 in
        \\set_option maxHeartbeats 8000000 in
        \\theorem {s}_correspondence :
        \\    Compiler.ZigAir.CapturedNestedCalls.decode 64 [{s}] {s}_captured = some {s} := rfl
        \\
    , .{ name, try lift(ctx, record, 0), name, try std.mem.join(ctx.allocator, ", ", dependencies.items), name, name });
}

pub fn check(ctx: *c.Context, io: std.Io, output: []const u8, lean: []const u8, environment: *const std.process.Environ.Map, lake: ?[]const u8, profile: z.air.Profile) !void {
    return checkWith(ctx, io, output, lean, environment, lake, profile, false);
}

pub fn checkWith(ctx: *c.Context, io: std.Io, output: []const u8, lean: []const u8, environment: *const std.process.Environ.Map, lake: ?[]const u8, profile: z.air.Profile, call_machine: bool) !void {
    const decoder = if (profile == .scalar) "Compiler.ZigAir.CapturedScalar" else if (call_machine) "Compiler.ZigAir.CapturedCallMachine" else if (profile == .nested_calls) "Compiler.ZigAir.CapturedNestedCalls" else if (profile.hasCalls()) "Compiler.ZigAir.CapturedCalls" else "Compiler.ZigAir.Captured";
    return checkModule(ctx, io, output, lean, environment, lake, decoder);
}

pub fn checkModule(ctx: *c.Context, io: std.Io, output: []const u8, lean: []const u8, environment: *const std.process.Environ.Map, lake: ?[]const u8, decoder: []const u8) !void {
    const evidence = try z.toolchain.newOutput(ctx, io, output);
    try z.provenance.verifyWorkspace(ctx, io);
    var env = try environment.clone(ctx.allocator);
    try env.put("LEAN_NUM_THREADS", "2");
    const runner: runtime.Runner = .{ .ctx = ctx, .io = io, .output = evidence };
    const prefix: []const []const u8 = if (lake) |path| &.{path} else &.{ "elan", "run", lean_toolchain, "lake" };
    try runner.run("version", try std.mem.concat(ctx.allocator, []const u8, &.{ prefix, &.{ "env", "lean", "--version" } }), .{ .cwd = z.project_root, .environ = &env });
    try ctx.require(std.mem.startsWith(u8, try runner.text("version"), "Lean (version 4.35.0,"), "certificate requires Lean 4.35.0");
    try runner.run("library", try std.mem.concat(ctx.allocator, []const u8, &.{ prefix, &.{ "build", decoder } }), .{ .cwd = z.project_root, .environ = &env });
    const path = try files.join(ctx, &.{ evidence, "Certificate.lean" });
    try files.write(io, path, lean);
    try runner.run("certificate", try std.mem.concat(ctx.allocator, []const u8, &.{ prefix, &.{ "env", "lean", "-j", "1", "-M", "4096", path } }), .{ .cwd = z.project_root, .environ = &env });
    try ctx.require(std.mem.eql(u8, lean, try ctx.read(io, path, c.max_json_bytes)), "certificate changed during checking");
    try z.provenance.verifyWorkspace(ctx, io);
    try files.write(io, try files.join(ctx, &.{ evidence, "report.json" }), try ctx.json(.{ .schema = "zean.air-certificate.v1", .status = "passed", .leanSha256 = &c.digest(lean), .interpretation = try ctx.fmt("{s}.decode", .{decoder}), .provenance = try z.provenance.identity(ctx), .leanWorkers = 1, .libraryWorkers = 2, .sourceSafetyVerified = false, .nativeRefinementVerified = false, .jsonLiftingVerified = false }));
}
