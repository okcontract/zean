// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");
const Arguments = z.Arguments;
const compiler_payload = @embedFile("capture_payload");
const help =
    \\Zean generates Lean models from Zig 0.17.1 AIR.
    \\Usage: zean [DIRECTORY] [--check] [--toolchain REPORT] [--evidence NEW_DIRECTORY]
    \\  Read zean.json or client.json in DIRECTORY (default .).
    \\  Generate Lean modules under lean/ and record them in zean.outputs.json.
    \\  --check                  Capture and check for stale or obsolete generated files
    \\  --toolchain REPORT       Override the bundled compiler or $ZEAN_TOOLCHAIN
    \\  --evidence NEW_DIRECTORY Retain logs and captures in a private external directory
    \\  Use zig build run -- [DIRECTORY] to run from the Zean checkout.
    \\
    \\Translate a retained capture:
    \\  zean translate --capture REPORT --root FUNCTION --output NEW_DIRECTORY
    \\  --profile scalar|memory|loops|aggregate|word-bytes|word-byte-loops|calls|call-loops|nested-calls|recursive-calls
    \\  --namespace NAME            Generated Lean namespace (default Zean.Generated)
    \\  --certify NEW_DIRECTORY     Check AIR correspondence with a development build from the Zean checkout
    \\  --specialized-source FILE  Bind a standalone captured type specialization to its source owner
    \\  --declaration-source FILE  Bind an ordinary captured function from the explicit source closure
    \\  --call-machine             Emit data-based functions for the resumable call machine
    \\Commands: translate, decode, capture, toolchain, check-patch, audit, admission, verify-client, allocator-evaluate, counter-regenerate, buffer-regenerate, copy-regenerate, calls-regenerate, stdlib-replace-regenerate, ziglings-regenerate, benchmark
    \\  zig build capture -- --toolchain REPORT --source FILE --root NAME --output DIRECTORY
    \\  zig build atomic-publication-check -- --capture REPORT --output DIRECTORY
    \\  zig build admission         Report operation obligations and coverage limits
    \\  zig build verify-client -- --manifest FILE --toolchain REPORT --output DIRECTORY
    \\  zig build allocator-evaluate -- --toolchain REPORT --output DIRECTORY
    \\  zig build toolchain -- --zig-tree TREE --bootstrap-zig ZIG --llvm-prefix LLVM --lld-prefix LLD --output DIRECTORY [--fresh-air-capture]
    \\  zig build check-patch -- --zig-tree TREE --output DIRECTORY
    \\
;
pub fn main(init: std.process.Init) !void {
    var ctx: z.common.Context = .{ .allocator = init.arena.allocator() };
    execute(&ctx, init) catch |err| {
        std.debug.print("zean: {s} ({s})\n", .{ ctx.diagnostic, @errorName(err) });
        std.process.exit(1);
    };
}
fn execute(ctx: *z.common.Context, init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(ctx.allocator);
    var output = std.Io.File.stdout().writerStreaming(init.io, &.{});
    if (args.len == 1) return runProject(ctx, init, &.{}, &output.interface);
    if (z.common.oneOf(args[1], &.{ "--help", "-h" })) return output.interface.writeAll(help);
    if (std.mem.eql(u8, args[1], "--version")) {
        return output.interface.print("Zean (Zig {s}{s})\n", .{ z.version, if (compiler_payload.len == 0) "" else ", standalone" });
    }
    const command = args[1];
    const tail = args[2..];
    if (tail.len == 1 and z.common.oneOf(tail[0], &.{ "--help", "-h" })) return output.interface.writeAll(help);
    if (std.mem.eql(u8, command, "admission")) {
        _ = try Arguments.parse(ctx, tail, &.{}, &.{});
        return output.interface.print("{s}\n", .{try ctx.json(try z.admission.report(ctx))});
    }
    if (std.mem.eql(u8, command, "atomic-publication-check")) {
        const a = try Arguments.parse(ctx, tail, &.{ "--capture", "--output", "--lake" }, &.{});
        const result = try z.atomic_publication.check(ctx, init.io, try a.one("--capture"), try a.one("--output"), init.environ_map, try a.optional("--lake"));
        return output.interface.print("{s}\n", .{try ctx.json(result)});
    }
    if (std.mem.eql(u8, command, "verify-client")) {
        const a = try Arguments.parse(ctx, tail, &.{ "--manifest", "--toolchain", "--output", "--lake" }, &.{});
        const result = try z.client.run(ctx, init.io, .{ .manifest = try a.one("--manifest"), .toolchain = try a.one("--toolchain"), .output = try a.one("--output"), .lake = try a.optional("--lake") }, init.environ_map);
        return output.interface.print("{s}\n", .{try ctx.json(result)});
    }
    if (std.mem.eql(u8, command, "allocator-evaluate")) {
        const a = try Arguments.parse(ctx, tail, &.{ "--toolchain", "--output" }, &.{});
        const result = try z.component.run(ctx, init.io, .{ .toolchain = try a.one("--toolchain"), .output = try a.one("--output") }, init.environ_map);
        return output.interface.print("{s}\n", .{try ctx.json(result)});
    }
    if (std.mem.eql(u8, command, "benchmark")) {
        const a = try Arguments.parse(ctx, tail, &.{ "--output", "--proof", "--repeat", "--lake" }, &.{});
        const repetitions = std.fmt.parseInt(u64, try a.default("--repeat", "3"), 10) catch return ctx.fail("invalid repetition count", .{});
        const result = try z.benchmark.run(ctx, init.io, .{ .output = try a.one("--output"), .proofs = if (a.many("--proof").len == 0) z.benchmark.defaults else a.many("--proof"), .repetitions = repetitions, .lake = try a.optional("--lake") }, init.environ_map);
        return output.interface.print("{s}\n", .{try ctx.json(result)});
    }
    if (z.common.oneOf(command, &.{ "counter-regenerate", "buffer-regenerate", "copy-regenerate", "calls-regenerate", "stdlib-replace-regenerate", "ziglings-regenerate" })) {
        const a = try Arguments.parse(ctx, tail, &.{ "--toolchain", "--output", "--lake" }, &.{"--check"});
        const options: z.tutorial.Options = .{ .toolchain = try a.one("--toolchain"), .output = try a.one("--output"), .lake = try a.optional("--lake"), .check = a.flag("--check") };
        const kind: z.tutorial.Kind = if (std.mem.eql(u8, command, "counter-regenerate")) .counter else if (std.mem.eql(u8, command, "buffer-regenerate")) .buffer else if (std.mem.eql(u8, command, "copy-regenerate")) .copy else if (std.mem.eql(u8, command, "calls-regenerate")) .calls else if (std.mem.eql(u8, command, "ziglings-regenerate")) .ziglings else .stdlib_replace;
        const result = try z.tutorial.run(ctx, init.io, kind, options, init.environ_map);
        try output.interface.print("{s}\n", .{try ctx.json(result)});
        return;
    }
    if (std.mem.eql(u8, command, "audit")) {
        const a = try Arguments.parse(ctx, tail, &.{ "--profile", "--toolchain", "--output" }, &.{});
        const profile = std.meta.stringToEnum(@FieldType(z.audit.Options, "profile"), try a.one("--profile")) orelse return ctx.fail("audit profile must be memory or validity", .{});
        const result = try z.audit.run(ctx, init.io, z.project_root, .{ .profile = profile, .toolchain = try a.one("--toolchain"), .output = try a.one("--output") });
        try output.interface.print("{s}\n", .{try ctx.json(result)});
        return;
    }
    if (std.mem.eql(u8, command, "decode")) {
        try ctx.require(tail.len == 1 or tail.len == 2, "decode needs RECORD [PROFILE]");
        const record = try ctx.parse(try ctx.read(init.io, tail[0], z.common.max_json_bytes));
        const profile = z.air.Profile.parse(if (tail.len == 2) tail[1] else "scalar") orelse return ctx.fail("unknown profile", .{});
        var decoder = try z.air.Decoder.initWith(ctx, record, profile, .{ .call_machine = profile.hasCalls() });
        return output.interface.print("{s}\n", .{try decoder.program()});
    }
    const result = if (std.mem.eql(u8, command, "capture")) blk: {
        const a = try Arguments.parse(ctx, tail, &.{ "--toolchain", "--source", "--source-base", "--output", "--root", "--source-file", "--module", "--mode" }, &.{});
        break :blk try z.capture.run(ctx, init.io, .{ .toolchain = try a.one("--toolchain"), .source = try a.one("--source"), .source_base = try a.default("--source-base", "."), .output = try a.one("--output"), .roots = a.many("--root"), .extra_sources = a.many("--source-file"), .modules = a.many("--module"), .mode = try a.default("--mode", "ReleaseFast") });
    } else if (std.mem.eql(u8, command, "check-patch")) blk: {
        const a = try Arguments.parse(ctx, tail, &.{ "--zig-tree", "--output" }, &.{});
        break :blk try z.toolchain.checkPatch(ctx, init.io, try a.one("--zig-tree"), z.project_root, try a.one("--output"));
    } else if (std.mem.eql(u8, command, "toolchain")) blk: {
        const a = try Arguments.parse(ctx, tail, &.{ "--zig-tree", "--output", "--bootstrap-zig", "--bootstrap", "--llvm-prefix", "--lld-prefix", "--cmake", "--generator", "--cmake-generator", "--system-libcpp", "--search-prefix", "--jobs" }, &.{ "--fresh-air-capture", "--fresh-air" });
        break :blk try z.toolchain.build(ctx, init.io, init.environ_map, z.project_root, .{ .tree = try a.one("--zig-tree"), .output = try a.one("--output"), .bootstrap = try a.either("--bootstrap", "--bootstrap-zig") orelse return ctx.fail("missing --bootstrap", .{}), .llvm = try a.one("--llvm-prefix"), .lld = try a.one("--lld-prefix"), .cmake = try a.default("--cmake", "cmake"), .generator = try a.either("--cmake-generator", "--generator") orelse "Ninja", .system_libcpp = try a.optional("--system-libcpp"), .search_prefixes = a.many("--search-prefix"), .fresh_air = a.flag("--fresh-air-capture") or a.flag("--fresh-air"), .jobs = try std.fmt.parseInt(u32, try a.default("--jobs", "2"), 10) });
    } else if (std.mem.eql(u8, command, "translate") or implicitTranslate(args[1..])) blk: {
        const a = try Arguments.parse(ctx, if (std.mem.eql(u8, command, "translate")) tail else args[1..], &.{ "--capture", "--root", "--output", "--profile", "--namespace", "--certify", "--lake", "--specialized-source", "--declaration-source" }, &.{"--call-machine"});
        const profile = z.air.Profile.parse(try a.default("--profile", "scalar")) orelse return ctx.fail("unknown profile", .{});
        const certify = try a.optional("--certify");
        try ctx.require(certify == null or compiler_payload.len == 0, "use zig build run -- translate --certify from the Zean checkout or check the generated project with Lake");
        break :blk try z.translate.run(ctx, init.io, .{ .capture = try a.one("--capture"), .roots = a.many("--root"), .output = try a.one("--output"), .profile = profile, .namespace = try a.default("--namespace", "Zean.Generated"), .certify = certify, .lake = try a.optional("--lake"), .environment = init.environ_map, .specialized_source = try a.optional("--specialized-source"), .declaration_source = try a.optional("--declaration-source"), .call_machine = a.flag("--call-machine") });
    } else return runProject(ctx, init, args[1..], &output.interface);
    try output.interface.print("{s}\n", .{try ctx.json(result)});
}

fn implicitTranslate(args: []const []const u8) bool {
    if (!std.mem.startsWith(u8, args[0], "--")) return false;
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--")) return false;
        if (z.common.oneOf(arg, &.{ "--capture", "--root", "--output", "--profile", "--namespace", "--certify", "--specialized-source", "--declaration-source", "--call-machine" })) return true;
    }
    return false;
}

fn runProject(ctx: *z.common.Context, init: std.process.Init, args: []const []const u8, output: *std.Io.Writer) !void {
    const parsed = try Arguments.project(ctx, args);
    const options: z.project.Options = .{
        .directory = parsed.directory orelse ".",
        .toolchain = try parsed.optional("--toolchain"),
        .evidence = try parsed.optional("--evidence"),
        .check = parsed.flag("--check"),
        .compiler_payload = compiler_payload,
    };
    return z.project.run(ctx, init.io, init.gpa, options, init.environ_map, output);
}
