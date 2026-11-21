// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Bind the captured declarations of a direct-call closure before emission.
const std = @import("std");
const c = @import("common.zig");
const air = @import("air.zig");
const files = @import("files.zig");
const translation = @import("translate.zig");

pub const Unit = struct {
    root: []const u8,
    name: []const u8,
    record: c.Value,
    path: []const u8,
    sha: []const u8,
    source_path: []const u8,
    source_sha: []const u8,
    called: bool = false,
};

/// Total leaves retain the finite interpreter. A looping body can use finite
/// callees; a body calling a looping or partial callee needs observations.
pub fn interpreter(ctx: *c.Context, record: c.Value, callees: []const air.Callee) !air.Profile {
    var loops = false;
    for (try ctx.array(try ctx.field(record, "instructions"))) |instruction| {
        if (!c.flag(instruction, "payloadVisited", true)) continue;
        const tag = try ctx.str(try ctx.field(instruction, "tag"));
        if (std.mem.eql(u8, tag, "loop")) loops = true;
        if (!c.oneOf(tag, &.{ "call", "call_never_inline", "call_never_tail" })) continue;
        const identity = try ctx.field(try ctx.field(instruction, "callee"), "identity");
        for (callees) |callee| {
            if (c.equal(try ctx.field(identity, "name"), try ctx.field(callee.record, "name")) and callee.profile != .calls) return .nested_calls;
        }
    }
    return if (loops) .call_loops else .calls;
}

pub const Closure = struct {
    const Active = struct { record: c.Value, called: bool };

    ctx: *c.Context,
    io: std.Io,
    capture: []const u8,
    report: c.Value,
    units: std.ArrayList(Unit) = .empty,
    active: std.StringHashMap(Active),
    names: std.StringHashMap(void),
    root_source: ?[]const u8 = null,
    allow_recursion: bool = false,

    pub fn init(ctx: *c.Context, io: std.Io, capture: []const u8, report: c.Value) Closure {
        return .{ .ctx = ctx, .io = io, .capture = capture, .report = report, .active = .init(ctx.allocator), .names = .init(ctx.allocator) };
    }

    pub fn visit(self: *Closure, root: []const u8, identity: ?c.Value, depth: usize) !void {
        const ctx = self.ctx;
        if (self.active.getPtr(root)) |unit| {
            try ctx.require(self.allow_recursion and identity != null, "recursive call graph is unsupported");
            try self.bindIdentity(unit.record, identity.?);
            unit.called = true;
            return;
        }
        for (self.units.items) |*unit| if (std.mem.eql(u8, root, unit.root)) {
            if (identity) |expected| {
                try self.bindIdentity(unit.record, expected);
                unit.called = true;
            } else try self.bindRoot(unit.record, try ctx.field(try ctx.field(self.report, "functions"), root));
            return;
        };
        try ctx.require(depth < 64 and self.active.count() + self.units.items.len < 512, "call closure resource limit");
        const entry = try ctx.field(try ctx.field(self.report, "functions"), root);
        const path = try translation.capturedPath(ctx, self.io, self.capture, entry);
        const captured = try files.readJson(ctx, self.io, path);
        const sha = try ctx.str(try ctx.field(entry, "sha256"));
        try ctx.require(c.isDigest(sha) and std.mem.eql(u8, sha, &c.digest(captured.bytes)), "AIR identity mismatch");
        const record = captured.value;
        try ctx.require(c.tag(record, "name", root), "call body name mismatch");
        if (identity) |expected| try self.bindIdentity(record, expected) else try self.bindRoot(record, entry);
        const source = try ctx.str(try ctx.field(record, "sourceFile"));
        const sources = try ctx.field(self.report, "sourceFiles");
        try ctx.require(c.equal(try ctx.field(sources, source), try ctx.field(record, "sourceSha256")), "callee is outside the explicit captured source closure");
        _ = try @import("declaration_source.zig").ownerPrefix(ctx, source);
        const source_path = if (self.root_source != null and std.mem.eql(u8, source, std.fs.path.basename(self.root_source.?))) self.root_source.? else try files.closureMember(ctx, self.io, std.fs.path.dirname(self.capture) orelse ".", source);
        try files.regular(ctx, self.io, source_path);
        const source_bytes = try ctx.read(self.io, source_path, 64 * 1024 * 1024);
        try @import("declaration_source.zig").select(ctx, record, sources, source, source_bytes);
        const start = if (std.mem.lastIndexOfScalar(u8, root, '.')) |index| index + 1 else 0;
        const component = root[start..];
        try ctx.require(c.identifier(component, false), "invalid generated function name");
        var name = try ctx.fmt("fn_{s}", .{component});
        var suffix: usize = 0;
        // Source identity selects the callee. Generated labels merely need to
        // be unique; separate owners may legitimately share a method name.
        while (self.names.contains(name)) {
            suffix += 1;
            name = try ctx.fmt("fn_{s}_{d}", .{ component, suffix });
        }
        try self.names.put(name, {});
        try self.active.put(root, .{ .record = record, .called = identity != null });
        const instructions = try ctx.array(try ctx.field(record, "instructions"));
        for (instructions) |instruction| {
            if (!c.flag(instruction, "payloadVisited", true)) continue;
            const tag = try ctx.str(try ctx.field(instruction, "tag"));
            if (!c.oneOf(tag, &.{ "call", "call_never_inline", "call_never_tail" })) continue;
            const callee = try ctx.field(instruction, "callee");
            try ctx.fields(callee, "kind identity");
            try ctx.require(c.tag(callee, "kind", "function"), "indirect or unsupported callee");
            const expected = try ctx.field(callee, "identity");
            try ctx.fields(expected, "name sourceFile sourceSha256");
            try self.visit(try ctx.str(try ctx.field(expected, "name")), expected, depth + 1);
        }
        const unit = self.active.fetchRemove(root).?.value;
        try self.units.append(ctx.allocator, .{ .root = root, .name = name, .record = record, .path = path, .sha = sha, .source_path = source_path, .source_sha = try ctx.str(try ctx.field(record, "sourceSha256")), .called = unit.called });
    }

    fn bindIdentity(self: *Closure, record: c.Value, identity: c.Value) !void {
        for ([_][]const u8{ "name", "sourceFile", "sourceSha256" }) |key| try self.ctx.require(c.equal(try self.ctx.field(record, key), try self.ctx.field(identity, key)), "callee declaration/source identity mismatch");
    }

    fn bindRoot(self: *Closure, record: c.Value, entry: c.Value) !void {
        const ctx = self.ctx;
        if (self.root_source) |selected| {
            try ctx.require(c.tag(record, "sourceFile", std.fs.path.basename(selected)), "imported call root has a different source owner");
        } else {
            try ctx.require(c.flag(entry, "requested", true) and c.equal(try ctx.field(record, "sourceSha256"), try ctx.field(self.report, "sourceSha256")), "requested call root identity mismatch");
        }
    }
};
