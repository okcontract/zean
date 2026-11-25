// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Compile actual admitted output, independently of the recorded text oracles.
const std = @import("std");
const z = @import("zean");
const f = @import("fixtures.zig");

pub fn main(init: std.process.Init) !void {
    var ctx: z.common.Context = .{ .allocator = init.arena.allocator() };
    run(&ctx, init) catch |err| {
        std.debug.print("emitted Lean: {s} ({s})\n", .{ ctx.diagnostic, @errorName(err) });
        std.process.exit(1);
    };
}

const Checker = struct {
    ctx: *z.common.Context,
    io: std.Io,
    output: []const u8,
    command: []const []const u8,
    environment: *const std.process.Environ.Map,
    count: usize = 0,

    fn check(self: *Checker, label: []const u8, lean: []const u8) !void {
        return self.run(label, lean, false);
    }
    fn reject(self: *Checker, label: []const u8, lean: []const u8) !void {
        return self.run(label, lean, true);
    }
    fn run(self: *Checker, label: []const u8, lean: []const u8, rejection: bool) !void {
        const ctx = self.ctx;
        const name = try ctx.fmt("control-{d}-{s}", .{ self.count, label });
        const path = try std.fs.path.join(ctx.allocator, &.{ self.output, try ctx.fmt("{s}.lean", .{name}) });
        try std.Io.Dir.cwd().writeFile(self.io, .{ .sub_path = path, .data = lean });
        const argv = try std.mem.concat(ctx.allocator, []const u8, &.{ self.command, &.{path} });
        const runner: z.runtime.Runner = .{ .ctx = ctx, .io = self.io, .output = self.output };
        if (runner.run(name, argv, .{ .environ = self.environment })) |_| {
            try ctx.require(!rejection, "invalid correspondence certificate was accepted");
        } else |err| {
            if (!rejection or err != error.InvalidInput) return err;
            const receipt = try ctx.parse(try ctx.read(self.io, try ctx.fmt("{s}/{s}.process.json", .{ self.output, name }), z.common.max_json_bytes));
            const diagnostic = try runner.text(name);
            const failed = std.mem.indexOf(u8, diagnostic, "Tactic `decide` failed") != null or std.mem.indexOf(u8, diagnostic, "Tactic `decide` proved that the proposition") != null;
            try ctx.require(try ctx.integer(try ctx.field(receipt, "exitCode")) == 1 and failed, "certificate rejection failed for an unexpected reason");
        }
        self.count += 1;
    }
};

fn run(ctx: *z.common.Context, init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(ctx.allocator);
    // The build interface supplies the pinned Lake/elan command. Development
    // checks may select one emitter; the aggregate release check still runs all.
    try ctx.require(args.len > 1, "missing Lean command");
    const selected = std.mem.eql(u8, args[1], "--only");
    if (selected) try ctx.require(args.len > 3, "missing emitted control or Lean command");
    var nonce: [16]u8 = undefined;
    init.io.random(&nonce);
    const output = try std.fs.path.join(ctx.allocator, &.{ init.environ_map.get("TMPDIR") orelse "/tmp", try ctx.fmt("zean-emitted-{s}", .{std.fmt.bytesToHex(nonce, .lower)}) });
    try std.Io.Dir.cwd().createDir(init.io, output, .default_dir);
    std.debug.print("Emitted Lean evidence: {s}\n", .{output});
    var environment = try init.environ_map.clone(ctx.allocator);
    try environment.put("LEAN_NUM_THREADS", "2");
    var checker: Checker = .{ .ctx = ctx, .io = init.io, .output = output, .command = args[if (selected) 3 else 1..], .environment = &environment };
    if (selected) {
        const label = args[2];
        if (std.mem.eql(u8, label, "copy-lengths")) {
            try checker.check(label, try @import("bulk_copy.zig").lengthsEmitted(ctx));
            std.debug.print("Compiled emitted control: {s}.\n", .{label});
            return;
        }
        if (std.mem.eql(u8, label, "unsigned-division")) {
            try checker.check(label, try @import("bulk_copy.zig").divisionEmitted(ctx));
            std.debug.print("Compiled emitted control: {s}.\n", .{label});
            return;
        }
        if (std.mem.eql(u8, label, "integer-switch")) {
            try checker.check(label, try @import("integer_switch.zig").emitted(ctx));
            std.debug.print("Compiled emitted control: {s}.\n", .{label});
            return;
        }
        if (std.mem.eql(u8, label, "byte-move")) {
            try checker.check(label, try @import("bulk_copy.zig").moveEmitted(ctx));
            std.debug.print("Compiled emitted control: {s}.\n", .{label});
            return;
        }
        if (std.mem.eql(u8, label, "slice-invalidation")) {
            try checker.check(label, try @import("bulk_copy.zig").invalidationEmitted(ctx));
            std.debug.print("Compiled emitted control: {s}.\n", .{label});
            return;
        }
        if (std.mem.eql(u8, label, "singleton-arguments")) {
            try checker.check(label, try @import("call_admission.zig").singletonEmitted(ctx));
            std.debug.print("Compiled emitted control: {s}.\n", .{label});
            return;
        }
        if (std.mem.eql(u8, label, "scalar-certificate")) {
            try checker.check(label, try @import("certificate.zig").scalarEmitted(ctx, null));
            for (0..@import("certificate.zig").scalar_mutations.len) |index| try checker.reject("scalar-certificate-mutation", try @import("certificate.zig").scalarEmitted(ctx, index));
            std.debug.print("Checked scalar certificate and {d} rejection controls.\n", .{@import("certificate.zig").scalar_mutations.len});
            return;
        }
        const lean = if (std.mem.eql(u8, label, "certificate")) try @import("certificate.zig").emitted(ctx, null) else if (std.mem.eql(u8, label, "byte-element-reads")) try @import("byte_reads.zig").emitted(ctx) else if (std.mem.eql(u8, label, "record-fields")) try @import("record_fields.zig").emitted(ctx) else if (std.mem.eql(u8, label, "bounded-length-slices")) try @import("bounded_slices.zig").emitted(ctx) else if (std.mem.eql(u8, label, "specialization-certificate")) try @import("specialized_source.zig").emitted(ctx) else if (std.mem.eql(u8, label, "calls")) try @import("call_admission.zig").emitted(ctx) else return ctx.fail("unknown emitted control: {s}", .{label});
        try checker.check(label, lean);
        std.debug.print("Compiled emitted control: {s}.\n", .{label});
        return;
    }
    try checker.check("certificate", try @import("certificate.zig").emitted(ctx, null));
    try checker.check("scalar-certificate", try @import("certificate.zig").scalarEmitted(ctx, null));
    for (0..@import("certificate.zig").scalar_mutations.len) |index| try checker.reject("scalar-certificate-mutation", try @import("certificate.zig").scalarEmitted(ctx, index));
    try checker.check("specialization-certificate", try @import("specialized_source.zig").emitted(ctx));
    try checker.check("integer-extrema", try @import("bulk_copy.zig").emitted(ctx));
    try checker.check("unsigned-division", try @import("bulk_copy.zig").divisionEmitted(ctx));
    try checker.check("copy-lengths", try @import("bulk_copy.zig").lengthsEmitted(ctx));
    try checker.check("integer-switch", try @import("integer_switch.zig").emitted(ctx));
    try checker.check("byte-move", try @import("bulk_copy.zig").moveEmitted(ctx));
    try checker.check("slice-invalidation", try @import("bulk_copy.zig").invalidationEmitted(ctx));
    try checker.check("byte-element-reads", try @import("byte_reads.zig").emitted(ctx));
    try checker.check("record-fields", try @import("record_fields.zig").emitted(ctx));
    try checker.check("bounded-length-slices", try @import("bounded_slices.zig").emitted(ctx));
    for (0..@import("certificate.zig").mutations.len) |index| try checker.reject("certificate-mutation", try @import("certificate.zig").emitted(ctx, index));

    var programs: std.ArrayList([]const u8) = .empty;
    try programs.append(ctx.allocator, "import Compiler.ZigAir.Captured\nimport Compiler.ZigAir.CapturedScalar\n");
    for (std.meta.tags(z.air.Profile)) |profile| {
        try programs.append(ctx.allocator, try ctx.fmt("import Compiler.ZigAir.{s}\n", .{profile.module()}));
    }
    var covered: std.EnumSet(z.air.Profile) = .empty;
    for (@import("cases/air.zig").cases, 0..) |fixture, index| {
        const case = try f.load(ctx.allocator, fixture);
        if (z.common.flag(case, "reject", true) or !z.common.tag(case, "kind", "program")) continue;
        const profile = z.air.Profile.parse(try ctx.str(try ctx.field(case, "profile"))) orelse return error.InvalidProfile;
        const program = try z.air.decode(ctx, try ctx.field(case, "input"), profile);
        const vocabulary = if (profile.hasLoops()) "MemoryAir" else profile.module();
        const certificate = if (profile == .scalar) try z.certificate.scalarDeclaration(ctx, try ctx.field(case, "input"), "program") else if (profile == .memory or profile == .loops) try z.certificate.declaration(ctx, try ctx.field(case, "input"), "program", profile.hasLoops()) else "";
        try programs.append(ctx.allocator, try ctx.fmt("\nnamespace Control{d}\nopen Compiler.ZigAir.{s}\ndef program : Program{s} :=\n{s}\n{s}\nend Control{d}\n", .{ index, vocabulary, if (profile.hasLoops()) " true" else "", program, certificate, index }));
        covered.insert(profile);
    }
    try checker.check("calls", try @import("call_admission.zig").emitted(ctx));
    try checker.check("singleton-arguments", try @import("call_admission.zig").singletonEmitted(ctx));
    covered.insert(.calls);
    covered.insert(.call_loops);
    covered.insert(.nested_calls);
    covered.insert(.recursive_calls);
    try ctx.require(covered.count() == std.meta.tags(z.air.Profile).len, "missing AIR profile compile control");
    try checker.check("air", try std.mem.concat(ctx.allocator, u8, programs.items));

    for (@import("cases/word.zig").cases) |fixture| {
        const case = try f.load(ctx.allocator, fixture);
        if (z.common.flag(case, "reject", true)) continue;
        const decoded = try z.word_swap.decode(ctx, try ctx.field(case, "record"), try ctx.field(case, "sources"));
        try checker.check("word-swap", try ctx.fmt("import Compiler.ZigAir.MemoryWordPair\nopen Compiler.ZigAir Compiler.ZigAir.MemoryAir\ndef program : WordPairProgram :=\n{s}\n", .{decoded.program}));
    }
    std.debug.print("Compiled {d} freshly emitted Lean controls ({d} AIR profiles).\n", .{ checker.count, covered.count() });
}
