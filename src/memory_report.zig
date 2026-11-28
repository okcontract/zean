// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Source candidates and reviewed, replay-bound per-operation obligations.
const std = @import("std");
const c = @import("common.zig");
const files = @import("files.zig");
const z = @import("root.zig");
const Ast = std.zig.Ast;
const Str = []const u8;

pub const Review = struct {
    function: Str,
    operation: Str,
    occurrence: usize = 0,
    declarationSha256: Str,
    obligation: Str,
    detail: Str,
    external: bool = false,
    unsupported: bool = false,
    manifest: ?Str = null,
    theorem: ?Str = null,
};

const Binding = struct { path: Str, sha256: Str };
const Source = struct { path: Str, context: []const Binding = &.{}, calls: []const Str = &.{}, copies: []const Str = &.{}, returns: []const Str = &.{}, reviews: []const Review = &.{} };
const Intent = struct { schema: Str, sources: []const Source };
const Operation = struct { name: Str, token: Ast.TokenIndex, callee: ?Str = null, unexamined: bool = false, obligations: []const Str };
const Obligation = struct {
    kind: Str,
    state: enum { open, proved, external, unsupported, stale, unexamined } = .open,
    detail: ?Str = null,
    manifest: ?Str = null,
    theorem: ?Str = null,
    replaySha256: ?Str = null,
};
pub const Site = struct {
    id: Str = "",
    declarationOrdinal: usize,
    callee: ?Str,
    expressionStart: usize,
    expressionEnd: usize,
    function: Str,
    declarationSha256: Str,
    operation: Str,
    occurrence: usize,
    declarationStart: usize,
    startByte: usize,
    line: usize,
    column: usize,
    obligations: []Obligation,
};

const copy_obligations: []const Str = &.{ "source-bounds", "destination-bounds", "disjoint", "initialized", "live-ranges", "contents", "frame" };

fn operation(tree: Ast, node: Ast.Node.Index, calls: []const Str, copies: []const Str, returns_view: bool) ?Operation {
    const main = tree.nodeMainToken(node);
    const tag = tree.nodeTag(node);
    const builtin_name = tree.tokenSlice(main);
    switch (tag) {
        .array_access => return .{ .name = "index", .token = main, .obligations = &.{ "bounds", "live-ranges", "access-permission" } },
        .deref => return .{ .name = "deref", .token = main, .obligations = &.{ "provenance", "alignment", "live-ranges", "access-permission" } },
        .address_of => return .{ .name = "address-of", .token = main, .obligations = &.{"lifetime"} },
        .field_access => return .{ .name = "member", .token = main, .obligations = &.{"receiver-type"}, .unexamined = true },
        .assign, .assign_mul, .assign_add, .assign_sub, .assign_div, .assign_mod, .assign_bit_and, .assign_bit_or, .assign_bit_xor, .assign_shl, .assign_shr, .assign_add_wrap, .assign_mul_wrap, .assign_sub_wrap, .assign_add_sat, .assign_sub_sat, .assign_mul_sat, .assign_shl_sat => return .{ .name = "write", .token = main, .obligations = &.{"write-target"}, .unexamined = true },
        .add, .sub => return .{ .name = "offset-or-integer", .token = main, .obligations = &.{"operand-type"}, .unexamined = true },
        .for_simple, .@"for" => return .{ .name = "iteration", .token = main, .obligations = &.{"iteration-lifetime"} },
        .asm_simple, .@"asm" => return .{ .name = "assembly", .token = main, .obligations = &.{"foreign-effects"}, .unexamined = true },
        .identifier => if (std.mem.eql(u8, builtin_name, "undefined")) return .{ .name = "undefined", .token = main, .obligations = &.{"initialized-before-read"} },
        else => {},
    }
    if (tree.fullSlice(node) != null) return .{ .name = "slice", .token = main, .obligations = &.{ "bounds", "lifetime" } };
    if (tree.nodeTag(node) == .@"return" and returns_view) {
        const value = tree.nodeData(node).opt_node.unwrap() orelse return null;
        if (tree.nodeTag(value) == .error_value or std.mem.eql(u8, tree.getNodeSource(value), "null")) return null;
        return .{ .name = "return", .token = main, .obligations = &.{ "contents", "ownership", "lifetime" } };
    }
    var builtin: [2]Ast.Node.Index = undefined;
    if (tree.builtinCallParams(&builtin, node) != null) {
        const name = tree.tokenSlice(main);
        if (std.mem.eql(u8, name, "@memcpy")) return .{ .name = name, .token = main, .obligations = copy_obligations };
        if (std.mem.eql(u8, name, "@memmove")) return .{ .name = name, .token = main, .obligations = &.{ "source-bounds", "destination-bounds", "initialized", "live-ranges", "contents", "frame" } };
        const kinds: []const Str = if (c.oneOf(name, &.{ "@ptrCast", "@ptrFromInt", "@fieldParentPtr", "@intFromPtr", "@constCast", "@volatileCast", "@addrSpaceCast" }))
            &.{ "provenance", "live-ranges", "access-permission" }
        else if (std.mem.eql(u8, name, "@alignCast")) &.{ "alignment", "provenance" }
        else if (c.oneOf(name, &.{ "@atomicLoad", "@atomicStore", "@atomicRmw", "@cmpxchgStrong", "@cmpxchgWeak", "@fence" })) &.{ "synchronization", "live-ranges" }
        else if (c.oneOf(name, &.{ "@memset", "@memmove" })) &.{ "destination-bounds", "live-ranges" }
        else if (c.oneOf(name, &.{ "@extern", "@cImport", "@call" })) &.{"foreign-effects"}
        else return .{ .name = name, .token = main, .obligations = &.{"builtin-effects"}, .unexamined = true };
        return .{ .name = name, .token = main, .obligations = kinds };
    }
    var buf: [1]Ast.Node.Index = undefined;
    const call = tree.fullCall(&buf, node) orelse return null;
    const callee = call.ast.fn_expr;
    if (tree.nodeTag(callee) != .field_access and tree.nodeTag(callee) != .identifier) return .{ .name = "indirect-call", .token = main, .obligations = &.{"callee-effects"}, .unexamined = true };
    const token = tree.lastToken(callee);
    const name = tree.tokenSlice(token);
    const spelling = tree.getNodeSource(callee);
    const target = if (spelling.len <= 160) spelling else null;
    const obligations: []const Str = if (c.oneOf(name, copies)) copy_obligations else if (c.oneOf(name, &.{ "alloc", "create", "dupe", "realloc", "resize", "ensureUnusedCapacity", "ensureTotalCapacity", "toOwnedSlice", "concat" }))
        &.{ "ownership", "allocation-failure" }
    else if (c.oneOf(name, &.{ "free", "destroy", "deinit" }))
        &.{ "owns-on-release", "released-once" }
    else if (c.oneOf(name, &.{ "spawn", "join", "lock", "unlock", "wait", "signal", "broadcast" }))
        &.{ "synchronization", "lifetime" }
    else if (c.oneOf(name, calls))
        &.{ "callee-contract", "lifetime" }
    else
        return .{ .name = name, .token = token, .callee = target, .obligations = &.{"callee-effects"}, .unexamined = true };
    return .{ .name = name, .token = token, .callee = target, .obligations = obligations };
}

fn earlier(_: void, a: Site, b: Site) bool {
    return a.startByte < b.startByte;
}

pub fn discover(ctx: *c.Context, bytes: Str, calls: []const Str, copies: []const Str, returns: []const Str) ![]Site {
    var parsed = try z.source.Declarations.init(ctx, bytes);
    defer parsed.deinit();
    const tree = parsed.tree;
    const declarations = try z.component.functionRanges(ctx, tree);
    const file_scope: z.component.FunctionRange = .{ .name = "<file>", .start = 0, .end = bytes.len, .sha = try ctx.allocator.dupe(u8, &c.digest(bytes)), .returns_view = false };
    var ordinals = std.AutoHashMap(usize, usize).init(ctx.allocator);
    var names = std.StringHashMap(usize).init(ctx.allocator);
    for (declarations) |decl| {
        const entry = try names.getOrPut(decl.name);
        if (!entry.found_existing) entry.value_ptr.* = 0;
        try ordinals.put(decl.start, entry.value_ptr.*);
        entry.value_ptr.* += 1;
    }
    var sites: std.ArrayList(Site) = .empty;
    for (0..tree.nodes.len) |index| {
        const node: Ast.Node.Index = @fromBackingInt(@intCast(index));
        const token = tree.nodeMainToken(node);
        const pos = tree.tokenStart(token);
        var owner: ?z.component.FunctionRange = null;
        for (declarations) |decl| {
            if (decl.start <= pos and pos < decl.end and (owner == null or decl.end - decl.start < owner.?.end - owner.?.start)) owner = decl;
        }
        const decl = owner orelse file_scope;
        const op = operation(tree, node, calls, copies, decl.returns_view or c.oneOf(decl.name, returns)) orelse continue;
        const location = tree.tokenLocation(0, op.token);
        const obligations = try ctx.allocator.alloc(Obligation, op.obligations.len);
        for (op.obligations, obligations) |kind, *item| item.* = .{ .kind = kind, .state = if (op.unexamined) .unexamined else .open };
        try sites.append(ctx.allocator, .{
            .function = decl.name,
            .declarationOrdinal = if (owner != null) ordinals.get(decl.start).? else 0,
            .callee = op.callee,
            .expressionStart = tree.tokenStart(tree.firstToken(node)),
            .expressionEnd = tree.tokenStart(tree.lastToken(node)) + tree.tokenSlice(tree.lastToken(node)).len,
            .declarationSha256 = decl.sha,
            .operation = op.name,
            .occurrence = 0,
            .declarationStart = decl.start,
            .startByte = tree.tokenStart(op.token),
            .line = location.line + 1,
            .column = location.column + 1,
            .obligations = obligations,
        });
    }
    std.mem.sort(Site, sites.items, {}, earlier);
    var counts = std.StringHashMap(usize).init(ctx.allocator);
    for (sites.items) |*site| {
        const entry = try counts.getOrPut(try ctx.json(.{ site.function, site.declarationOrdinal, site.operation }));
        if (!entry.found_existing) entry.value_ptr.* = 0;
        site.occurrence = entry.value_ptr.*;
        entry.value_ptr.* += 1;
    }
    return sites.items;
}

const Replay = struct { path: Str, bytes: Str, report: c.Value };
const Evidence = struct { state: @FieldType(Obligation, "state"), sha: ?Str = null };
const Checker = struct {
    ctx: *c.Context,
    io: std.Io,
    repo: std.Io.Dir,
    project: Str,
    replays: []const Replay,
    cache: std.StringHashMap(Evidence),

    fn check(self: *Checker, manifest: Str, theorem: Str) !Evidence {
        const ctx = self.ctx;
        const key = try ctx.fmt("{s}:{s}", .{ manifest, theorem });
        if (self.cache.get(key)) |found| return found;
        const config = try z.project.parseConfig(ctx, self.project);
        if (!c.oneOf(manifest, config.clients)) return .{ .state = .stale };
        var map = config.source_map;
        const plan = try z.client.load(ctx, self.io, self.repo, manifest, &map);
        const named = c.oneOf(theorem, plan.manifest.theorems);
        var evidence: Evidence = .{ .state = if (named) .open else .stale };
        for (self.replays) |replay| {
            if (!c.tag(replay.report, "manifestSha256", &c.digest(plan.bytes))) {
                // An older report naming the reviewed theorem is stale evidence.
                if (c.get(c.get(replay.report, "theoremAxioms") orelse .null, theorem) != null)
                    evidence = .{ .state = .stale, .sha = try ctx.allocator.dupe(u8, &c.digest(replay.bytes)) };
                continue;
            }
            const sha = try ctx.allocator.dupe(u8, &c.digest(replay.bytes));
            const axioms = c.get(replay.report, "theoremAxioms") orelse .null;
            var current = named and c.tag(replay.report, "schema", "zean.client-replay.v1") and
                c.tag(replay.report, "projectSha256", &c.digest(self.project)) and
                c.flag(replay.report, "modelProofsChecked", true) and c.get(axioms, theorem) != null and
                try self.matches(plan, replay.report, replay.path, config.lean_dir);
            var plans: std.ArrayList(z.client.Plan) = .empty;
            var seen = std.StringHashMap(z.project.ReplayVisit).init(ctx.allocator);
            var cfg = config;
            try z.project.collectReplayPlans(ctx, self.io, self.repo, &cfg, manifest, &plans, &seen);
            const deps = c.get(replay.report, "dependencies");
            current = current and (if (deps) |d| d == .object and d.object.count() == plans.items.len - 1 else plans.items.len == 1);
            for (plans.items[0 .. plans.items.len - 1]) |dep| {
                if (!current) break;
                const reference = c.get(deps.?, dep.path) orelse {
                    current = false;
                    break;
                };
                const relative = try ctx.str(try ctx.field(reference, "report"));
                try z.client.relative(ctx, relative);
                const parent = std.fs.path.dirname(replay.path) orelse ".";
                const child_path = try files.closureMember(ctx, self.io, parent, relative);
                const child = try ctx.read(self.io, child_path, c.max_json_bytes);
                current = c.tag(reference, "sha256", &c.digest(child)) and try self.matches(dep, try ctx.parse(child), child_path, config.lean_dir);
            }
            evidence = .{ .state = if (current) .proved else .stale, .sha = sha };
            if (current) break;
        }
        try self.cache.put(key, evidence);
        return evidence;
    }

    fn matches(self: *Checker, plan: z.client.Plan, report: c.Value, path: Str, lean_dir: Str) !bool {
        if (!c.tag(report, "status", "passed") or !c.flag(report, "airCorrespondenceChecked", true) or
            !c.flag(report, "nativeObjectComparisons", true) or !c.tag(report, "manifestSha256", &c.digest(plan.bytes))) return false;
        const inputs = c.get(report, "inputs") orelse return false;
        if (inputs != .object or inputs.object.count() != plan.inputs.len) return false;
        for (plan.inputs) |input| {
            const bytes = try files.readContained(self.ctx, self.io, self.repo, input.actual);
            if (!c.tag(inputs, input.logical, &c.digest(bytes))) return false;
        }
        const module_path = try std.mem.replaceOwned(u8, self.ctx.allocator, plan.manifest.generated, ".", "/");
        const filename = try self.ctx.fmt("{s}.lean", .{module_path});
        const local = if (std.mem.eql(u8, lean_dir, ".")) filename else try files.join(self.ctx, &.{ lean_dir, filename });
        const output = try files.closureMember(self.ctx, self.io, std.fs.path.dirname(path) orelse ".", "translation/Generated.lean");
        if (!z.project.sameModel(try files.readContained(self.ctx, self.io, self.repo, local), try self.ctx.read(self.io, output, c.max_json_bytes))) return false;
        return c.equal(c.get(report, "theorems") orelse return false, try self.ctx.parse(try self.ctx.json(plan.manifest.theorems)));
    }
};

pub fn run(ctx: *c.Context, io: std.Io, directory: Str, intent_path: ?Str, sources: []const Str, reports: []const Str) !c.Value {
    const repo = try std.Io.Dir.cwd().openDir(io, directory, .{});
    defer repo.close(io);
    const intent: Intent = if (intent_path) |p| blk: {
        const bytes = try files.readContained(ctx, io, repo, p);
        break :blk try std.json.parseFromSliceLeaky(Intent, ctx.allocator, bytes, .{});
    } else .{ .schema = "zean.memory-intent.v1", .sources = &.{} };
    try ctx.require(std.mem.eql(u8, intent.schema, "zean.memory-intent.v1"), "invalid memory intent schema");
    var paths: std.ArrayList(Source) = .empty;
    try paths.appendSlice(ctx.allocator, intent.sources);
    for (sources) |p| try paths.append(ctx.allocator, .{ .path = p });
    try ctx.require(paths.items.len > 0, "memory requires --source or --intent");
    const replays = try ctx.allocator.alloc(Replay, reports.len);
    for (reports, replays) |p, *replay| {
        const bytes = try ctx.read(io, p, c.max_json_bytes);
        replay.* = .{ .path = p, .bytes = bytes, .report = try ctx.parse(bytes) };
    }
    const project = if (intent_path != null) try files.readContained(ctx, io, repo, "zean.json") else "{}";
    var checker: Checker = .{ .ctx = ctx, .io = io, .repo = repo, .project = project, .replays = replays, .cache = .init(ctx.allocator) };
    var inventory: c.Value = .{ .object = .empty };
    for (paths.items) |source| {
        try ctx.require(!inventory.object.contains(source.path), "duplicate memory source");
        const bytes = try files.readContained(ctx, io, repo, source.path);
        const sites = try discover(ctx, bytes, source.calls, source.copies, source.returns);
        for (sites) |*site| {
            const identity = try ctx.json(.{ source.path, site.function, site.declarationOrdinal, site.operation, site.occurrence });
            site.id = try ctx.allocator.dupe(u8, &c.digest(identity));
        }
        var stale: std.ArrayList(Review) = .empty;
        var context_current = true;
        for (source.context) |binding| {
            try ctx.require(c.isDigest(binding.sha256), "invalid memory context digest");
            const snapshot = files.readContained(ctx, io, repo, binding.path) catch |err| switch (err) {
                error.FileNotFound => {
                    context_current = false;
                    continue;
                },
                else => return err,
            };
            if (!std.mem.eql(u8, binding.sha256, &c.digest(snapshot))) context_current = false;
        }
        for (source.reviews) |review| {
            try ctx.require(review.detail.len > 0 and (review.theorem == null) == (review.manifest == null) and
                @as(usize, @intFromBool(review.external)) + @intFromBool(review.unsupported) + @intFromBool(review.theorem != null) <= 1, "invalid memory review");
            if (!context_current) {
                try stale.append(ctx.allocator, review);
                continue;
            }
            var matched = false;
            for (sites) |site| {
                if (!std.mem.eql(u8, site.operation, review.operation) or !std.mem.eql(u8, site.function, review.function) or
                    site.occurrence != review.occurrence or !std.mem.eql(u8, site.declarationSha256, review.declarationSha256)) continue;
                for (site.obligations) |*item| {
                    if (!std.mem.eql(u8, item.kind, review.obligation)) continue;
                    try ctx.require(!matched and item.detail == null, "ambiguous or duplicate memory obligation");
                    matched = true;
                    item.detail = review.detail;
                    item.theorem = review.theorem;
                    item.manifest = review.manifest;
                    if (review.external) item.state = .external;
                    if (review.unsupported) item.state = .unsupported;
                    if (review.theorem) |name| {
                        const result = try checker.check(review.manifest.?, name);
                        item.replaySha256 = result.sha;
                        item.state = result.state;
                    }
                }
            }
            if (!matched) try stale.append(ctx.allocator, review);
        }
        // Keep obsolete reviews visible on a surviving, unambiguous source site.
        // Removed or ambiguous sites remain in the file-level list.
        for (stale.items) |review| {
            var candidate: ?*Obligation = null;
            var count: usize = 0;
            for (sites) |site| {
                if (!std.mem.eql(u8, site.operation, review.operation) or !std.mem.eql(u8, site.function, review.function) or
                    site.occurrence != review.occurrence) continue;
                for (site.obligations) |*item| {
                    if (!std.mem.eql(u8, item.kind, review.obligation)) continue;
                    count += 1;
                    candidate = item;
                }
            }
            if (count == 1 and candidate.?.detail == null) {
                candidate.?.state = .stale;
                candidate.?.detail = review.detail;
            }
        }
        try inventory.object.put(ctx.allocator, source.path, try ctx.parse(try ctx.json(.{ .sha256 = &c.digest(bytes), .sites = sites, .stale = stale.items })));
    }
    const target = c.get(try ctx.parse(project), "captureTarget") orelse c.Value.null;
    return ctx.parse(try ctx.json(.{ .schema = "zean.memory-report.v1", .discovery = "zig-ast-v2", .coverageComplete = false, .sourceSafetyVerified = false, .nativeRefinementVerified = false, .target = target, .files = inventory }));
}
