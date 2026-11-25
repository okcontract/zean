// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");

test "undefined-byte copies retain initialization obligations" {
    try @import("undefined_copy.zig").controls();
}
const z = @import("zean");

test "captured ordinary declarations bind their actual owners and source closure" {
    try @import("declaration_source.zig").controls();
}
test "captured standard-library source evidence binds hashes and safe identities" {
    try @import("capture_stdlib.zig").controls();
}
test "record fields preserve complete geometry, declaration indices and permissions" {
    try @import("record_fields.zig").controls();
}
test "inlined slice guards bind the retained source and preserve the bound check" {
    try @import("bounded_slices.zig").inlineSources();
}

test "bounded length-based slices retain their original extent and overflow work" {
    try @import("bounded_slices.zig").controls();
}
test "integer extrema and byte copies retain their types and effects" {
    try @import("bulk_copy.zig").controls();
    try @import("byte_reads.zig").controls();
}
test "integer switches keep typed disjoint cases and own each body" {
    try @import("integer_switch.zig").controls();
}
test "native byte moves allow overlap in either direction" {
    try @import("bulk_copy.zig").nativeMoves();
}
const fixtures = @import("fixtures.zig");

test "versioned admission vocabulary is closed and records its evidence boundary" {
    try @import("admission.zig").controls();
}

test "declarative clients reject ambiguous paths, profiles and unchecked proof imports" {
    try @import("client.zig").controls();
}
test "project workflows retain explicit paths and protect existing Lean sources" {
    try @import("project.zig").controls();
}

test "project client replay selects only a declared manifest" {
    try @import("project.zig").replayControls();
}

test "project freshness reports obsolete outputs and keeps evidence outside the checkout" {
    try @import("project.zig").inventoryControls();
}

test "the project inventory detects restored retired modules after regeneration" {
    try @import("project.zig").retiredControls();
}

test "project generation checks its own retiring paths before publication" {
    try @import("project.zig").retiringLayoutControls();
}

test "project outputs respect nested ownership before and after recording an inventory" {
    try @import("project.zig").nestedControls();
}

test "enclosing inventories own their outputs and absent paths retain filesystem identity" {
    try @import("project.zig").enclosingControls();
}

test "project outputs reserve their directory components across project boundaries" {
    try @import("project.zig").fileDirectoryControls();
}

test "the bundle inspects ELF architecture and linkage before calling ldd" {
    try @import("bundle.zig").elfControls();
}

test "standalone packaging rejects ELF RPATH in a compiler or shared library" {
    try @import("bundle.zig").elfSearchPaths();
}

test "standalone packaging rejects external frameworks even when weak and absent" {
    try @import("bundle.zig").macFramework();
}

test "standalone library names must have distinct archive paths" {
    try @import("bundle.zig").archiveNameControls();
}

test "component inventories include private and nested function declarations" {
    try @import("component.zig").controls();
}

test "Lean framework imports preserve core, optional and pure memory boundaries" {
    try @import("lean_layout.zig").controls();
}

test "certificate lifter preserves strings and rejects unsupported data" {
    try @import("certificate.zig").controls();
}

test "explicit type specialization binds its actual declaration and parameter map" {
    try @import("specialized_source.zig").controls();
}

test "direct-call closure rejects identity, signature, recursion and unsupported body mutations" {
    try @import("call_admission.zig").controls();
}

test "void-payload error unions keep checked try branches and named errors" {
    try @import("error_status.zig").controls();
}

test "enum comparisons and switches check declared tags and identities" {
    try @import("enum_tags.zig").controls();
}

test "counter regeneration compares complete programs and admits only replayed imports" {
    try @import("tutorial_replay.zig").controls();
}

test "buffer regeneration binds program identity and replays only its own proof imports" {
    try @import("tutorial_replay.zig").bufferControls();
}

test "copy regeneration checks both roots and proof import boundaries" {
    try @import("tutorial_replay.zig").copyControls();
}

test "call regeneration checks the complete callee closure and proof import boundaries" {
    try @import("tutorial_replay.zig").callControls();
}

test "standard-library replay checks source identity and imports only its fresh client" {
    try @import("tutorial_replay.zig").componentControls();
}

test "Ziglings replay binds all four kernels and rejects unrelated proof imports" {
    try @import("tutorial_replay.zig").ziglingsControls();
}

test "recorded AIR admission and semantic mutation controls" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var context: z.common.Context = .{ .allocator = arena.allocator() };
    const root = try fixtures.cases(context.allocator, &@import("cases/air.zig").cases);
    const cases = try context.array(root);
    for (cases, 0..) |case, index| {
        var case_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer case_arena.deinit();
        var ctx: z.common.Context = .{ .allocator = case_arena.allocator() };
        const profile_name = try ctx.str(try ctx.field(case, "profile"));
        const profile = z.air.Profile.parse(profile_name) orelse return error.InvalidProfile;
        const input = try ctx.field(case, "input");
        const result = if (z.common.tag(case, "kind", "constant")) blk: {
            const value = z.air.constant(&ctx, input, profile) catch |err| break :blk @as(z.common.Error![]const u8, err);
            break :blk @as(z.common.Error![]const u8, value.text);
        } else z.air.decode(&ctx, input, profile);
        const reject = z.common.flag(case, "reject", true);
        if (result) |actual| {
            if (reject) {
                std.debug.print("unexpected admission: case {d}, {s}\n", .{ index, profile_name });
                return error.UnexpectedAdmission;
            }
            const expected = try ctx.str(try ctx.field(case, "output"));
            std.testing.expectEqualStrings(expected, actual) catch |err| {
                std.debug.print("output mismatch: case {d}, {s}\n", .{ index, profile_name });
                return err;
            };
        } else |err| {
            if (err == error.OutOfMemory) return err;
            if (!reject) {
                std.debug.print("unexpected rejection: case {d}, {s}: {s}\n", .{ index, profile_name, ctx.diagnostic });
                return err;
            }
        }
    }
}

test "specialization mapping and direct-call provenance reference controls" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    for (try ctx.array(try fixtures.cases(ctx.allocator, &@import("cases/link.zig").cases)), 0..) |case, index| {
        var local_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer local_arena.deinit();
        var local: z.common.Context = .{ .allocator = local_arena.allocator() };
        const names = try ctx.array(try ctx.field(case, "roots"));
        const roots = try local.allocator.alloc([]const u8, names.len);
        for (names, roots) |name, *out| out.* = try ctx.str(name);
        const result = z.specialization.link(&local, try ctx.field(case, "records"), roots, try ctx.field(case, "sources"));
        if (result) |actual| {
            if (z.common.flag(case, "reject", true)) {
                std.debug.print("unexpected link admission {d}\n", .{index});
                return error.UnexpectedAdmission;
            }
            if (!z.common.equal(try ctx.field(case, "output"), actual)) {
                std.debug.print("link output mismatch {d}: {s}\n", .{ index, try ctx.json(actual) });
                return error.OutputMismatch;
            }
        } else |err| {
            if (err == error.OutOfMemory) return err;
            if (!z.common.flag(case, "reject", true)) {
                std.debug.print("unexpected link rejection {d}: {s}\n", .{ index, local.diagnostic });
                return err;
            }
        }
    }
}

test "word swap retains source mapping and wraps the explicit word-pair contract" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    for (try ctx.array(try fixtures.cases(ctx.allocator, &@import("cases/word.zig").cases)), 0..) |case, index| {
        var local_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer local_arena.deinit();
        var local: z.common.Context = .{ .allocator = local_arena.allocator() };
        const record = try ctx.field(case, "record");
        const original = try ctx.json(record);
        const result = z.word_swap.decode(&local, record, try ctx.field(case, "sources"));
        if (result) |actual| {
            if (z.common.flag(case, "reject", true)) {
                std.debug.print("unexpected word-swap admission {d}\n", .{index});
                return error.UnexpectedAdmission;
            }
            try std.testing.expectEqualStrings(try ctx.str(try ctx.field(case, "output")), actual.program);
            try std.testing.expectEqualStrings(original, try ctx.json(record));
        } else |err| {
            if (err == error.OutOfMemory) return err;
            if (!z.common.flag(case, "reject", true)) {
                std.debug.print("unexpected word-swap rejection {d}: {s}\n", .{ index, local.diagnostic });
                return err;
            }
        }
    }
}

fn tmpPath(ctx: *z.common.Context, tmp: std.testing.TmpDir) ![]const u8 {
    return std.fs.path.resolve(ctx.allocator, &.{ ".zig-cache", "tmp", &tmp.sub_path });
}

test "translation publishes escaped namespace components and rejects malformed names atomically" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try tmpPath(&ctx, tmp);
    const record = try fixtures.load(ctx.allocator, @import("cases/shared.zig").air_scalar_program_1_input_2);
    const bytes = try ctx.json(record);
    try tmp.dir.createDir(std.testing.io, "air", .default_dir);
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "air/root.json", .data = bytes });
    const report = try ctx.json(.{
        .schema = "oksolc.fresh-air-capture.v1",
        .status = "captured",
        .captureComplete = true,
        .zigVersion = z.version,
        .zigRevision = z.revision,
        .sourceSha256 = try ctx.field(record, "sourceSha256"),
        .functions = .{ .@"fixture.choose" = .{ .requested = true, .file = "root.json", .sha256 = &z.common.digest(bytes) } },
    });
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "report.json", .data = report });
    const capture = try std.fs.path.join(ctx.allocator, &.{ path, "report.json" });
    const names = [_]struct { raw: []const u8, lean: []const u8 }{
        .{ .raw = "by", .lean = "«by»" },
        .{ .raw = "namespace", .lean = "«namespace»" },
        .{ .raw = "Example.by", .lean = "«Example».«by»" },
        .{ .raw = "by.end.match", .lean = "«by».«end».«match»" },
        .{ .raw = "Zean.Generated", .lean = "«Zean».«Generated»" },
    };
    for (names, 0..) |name, index| {
        const output = try ctx.fmt("{s}/valid-{d}", .{ path, index });
        const manifest = try z.translate.run(&ctx, std.testing.io, .{ .capture = capture, .roots = &.{"fixture.choose"}, .output = output, .namespace = name.raw });
        const lean = try ctx.read(std.testing.io, try std.fs.path.join(ctx.allocator, &.{ output, "Generated.lean" }), 16384);
        try std.testing.expect(std.mem.startsWith(u8, lean, "-- Autogenerated by Zean. Do not edit.\n"));
        const identities = [_]struct { label: []const u8, hash: []const u8 }{
            .{ .label = "Source", .hash = try ctx.str(try ctx.field(record, "sourceSha256")) },
            .{ .label = "Capture report", .hash = &z.common.digest(report) },
            .{ .label = "AIR", .hash = &z.common.digest(bytes) },
        };
        for (identities) |identity| try std.testing.expect(std.mem.indexOf(u8, lean, try ctx.fmt("-- {s} SHA-256: {s}\n", .{ identity.label, identity.hash })) != null);
        try std.testing.expect(std.mem.indexOf(u8, lean, try ctx.fmt("\nnamespace {s}\n", .{name.lean})) != null);
        try std.testing.expect(std.mem.endsWith(u8, lean, try ctx.fmt("\nend {s}\n", .{name.lean})));
        try std.testing.expect(z.common.tag(manifest, "namespace", name.raw));
        const entry = try ctx.field(try ctx.field(manifest, "functions"), "fixture.choose");
        try std.testing.expect(z.common.tag(entry, "declaration", try ctx.fmt("{s}.fn_choose", .{name.raw})));
        try std.testing.expect(z.common.tag(manifest, "leanSha256", &z.common.digest(lean)));
        const provenance = try ctx.field(manifest, "provenance");
        try std.testing.expect(z.common.tag(try ctx.field(provenance, "producer"), "name", "zean"));
        try std.testing.expect(z.common.isDigest(try ctx.str(try ctx.field(try ctx.field(provenance, "producer"), "sourceSha256"))));
        try std.testing.expect(z.common.tag(try ctx.field(provenance, "library"), "leanToolchain", "leanprover/lean4:v4.35.0"));
    }
    for ([_][]const u8{ "", ".by", "Example..by", "by.", "Example.«by»", "by\nend by", "0bad", "bad-name" }, 0..) |name, index| {
        const relative = try ctx.fmt("invalid-{d}", .{index});
        const output = try std.fs.path.join(ctx.allocator, &.{ path, relative });
        try std.testing.expectError(error.InvalidInput, z.translate.run(&ctx, std.testing.io, .{ .capture = capture, .roots = &.{"fixture.choose"}, .output = output, .namespace = name }));
        try std.testing.expectError(error.FileNotFound, tmp.dir.statFile(std.testing.io, relative, .{}));
    }
    for ([_][]const u8{
        "{}",
        \\{"fixture.zig":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"}
    }, 0..) |inventory, index| {
        var changed = try ctx.parse(report);
        try changed.object.put(ctx.allocator, "sourceFiles", try ctx.parse(inventory));
        try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "report.json", .data = try ctx.json(changed) });
        const relative = try ctx.fmt("bad-inventory-{d}", .{index});
        const output = try std.fs.path.join(ctx.allocator, &.{ path, relative });
        try std.testing.expectError(error.InvalidInput, z.translate.run(&ctx, std.testing.io, .{ .capture = capture, .roots = &.{"fixture.choose"}, .output = output }));
        try std.testing.expectError(error.FileNotFound, tmp.dir.statFile(std.testing.io, relative, .{}));
    }
}

test "capture record inspection retains unsupported payloads and rejects corrupted provenance" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    for (try ctx.array(try fixtures.cases(ctx.allocator, &@import("cases/capture.zig").cases)), 0..) |case, index| {
        var tmp = std.testing.tmpDir(.{ .iterate = true });
        defer tmp.cleanup();
        const path = try tmpPath(&ctx, tmp);
        const entries = try ctx.field(case, "files");
        var iterator = entries.object.iterator();
        while (iterator.next()) |entry| {
            if (entry.value_ptr.* == .string) try tmp.dir.writeFile(std.testing.io, .{ .sub_path = entry.key_ptr.*, .data = entry.value_ptr.string }) else try tmp.dir.symLink(std.testing.io, try ctx.str(try ctx.field(entry.value_ptr.*, "symlink")), entry.key_ptr.*, .{});
        }
        const root_values = try ctx.array(try ctx.field(case, "roots"));
        const roots = try ctx.allocator.alloc([]const u8, root_values.len);
        for (root_values, roots) |value, *out| out.* = try ctx.str(value);
        const result = z.capture.inspectRecords(&ctx, std.testing.io, path, roots, try ctx.str(try ctx.field(case, "sha")), try ctx.str(try ctx.field(case, "mode")));
        if (result) |actual| {
            if (z.common.flag(case, "reject", true)) {
                std.debug.print("unexpected capture admission {d}\n", .{index});
                return error.UnexpectedAdmission;
            }
            try std.testing.expect(z.common.equal(try ctx.field(case, "output"), actual));
        } else |err| {
            if (err == error.OutOfMemory) return err;
            if (!z.common.flag(case, "reject", true)) {
                std.debug.print("unexpected capture rejection {d}: {s}\n", .{ index, ctx.diagnostic });
                return err;
            }
        }
    }
}

test "independent memory and source-validity fixture audits match reference controls" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    for (try ctx.array(try fixtures.cases(ctx.allocator, &@import("cases/audit.zig").cases)), 0..) |case, index| {
        const kind = try ctx.str(try ctx.field(case, "kind"));
        const input = try ctx.field(case, "input");
        const result = if (std.mem.eql(u8, kind, "memory")) z.audit.inspectMemory(&ctx, input) else if (std.mem.eql(u8, kind, "validity")) z.audit.inspectSlices(&ctx, input, try ctx.str(try ctx.field(case, "basename")), try ctx.str(try ctx.field(case, "source"))) else blk: {
            z.audit.inspectSignatures(&ctx, input) catch |err| break :blk @as(anyerror!z.common.Value, err);
            break :blk @as(anyerror!z.common.Value, .null);
        };
        if (result) |actual| {
            if (z.common.flag(case, "reject", true)) {
                std.debug.print("unexpected audit admission {d}: {s}\n", .{ index, kind });
                return error.UnexpectedAdmission;
            }
            try std.testing.expect(z.common.equal(try ctx.field(case, "output"), try ctx.parse(try ctx.json(actual))));
        } else |err| {
            if (err == error.OutOfMemory) return err;
            if (!z.common.flag(case, "reject", true)) {
                std.debug.print("unexpected audit rejection {d}: {s}\n", .{ index, ctx.diagnostic });
                return err;
            }
        }
    }
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try tmpPath(&ctx, tmp);
    const toolchain = try std.fs.path.join(ctx.allocator, &.{ path, "toolchain.json" });
    const output = try std.fs.path.join(ctx.allocator, &.{ path, "audit" });
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "toolchain.json", .data = "{}" });
    try std.testing.expectError(error.InvalidInput, z.audit.run(&ctx, std.testing.io, z.project_root, .{ .toolchain = toolchain, .output = output, .profile = .memory }));
    const saved = try ctx.parse(try ctx.read(std.testing.io, try std.fs.path.join(ctx.allocator, &.{ output, "report.json" }), 65536));
    try std.testing.expect(z.common.tag(saved, "status", "failed") and z.common.get(saved, "error") != null);
}

test "explicit capture imports bind normalized module identities and self-contained leaves" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try tmpPath(&ctx, tmp);
    try tmp.dir.createDir(std.testing.io, "src", .default_dir);
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "fixture.zig", .data = "const p = @import(\"src/production.zig\");" });
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/production.zig", .data = "const n = @import(\"number\");" });
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/number.zig", .data = "const s = @import(\"std\"); pub const Word = u64;" });
    const modules = try z.capture.moduleBindings(&ctx, &.{"number=./src/number.zig"});
    const extras = &[_][]const u8{ "src/production.zig", "src/number.zig" };
    const sources = try z.capture.sourceFilesAt(&ctx, std.testing.io, path, "fixture.zig", extras, modules);
    try std.testing.expectEqual(@as(usize, 3), sources.object.count());
    try std.testing.expectError(error.InvalidInput, z.capture.moduleBindings(&ctx, &.{ "x=src/x.zig", "y=./src/x.zig" }));
    try std.testing.expectError(error.InvalidInput, z.capture.sourceFilesAt(&ctx, std.testing.io, path, "fixture.zig", extras[0..1], modules));
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/number.zig", .data = "const n = @import(\"number\");" });
    try std.testing.expectError(error.InvalidInput, z.capture.sourceFilesAt(&ctx, std.testing.io, path, "fixture.zig", extras, modules));
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/number.zig", .data = "pub const Word = u64;" });
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/production.zig", .data = "const n = @import(\"number.zig\");" });
    try std.testing.expectError(error.InvalidInput, z.capture.sourceFilesAt(&ctx, std.testing.io, path, "fixture.zig", extras, modules));
}

test "file-backed child logs, actual terminal receipts and whole-group timeout cleanup" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try tmpPath(&ctx, tmp);
    const child = @import("test_options").child;
    const runner: z.runtime.Runner = .{ .ctx = &ctx, .io = std.testing.io, .output = path };
    try runner.run("large", &.{ child, "large" }, .{});
    const stat = try tmp.dir.statFile(std.testing.io, "large.stdout", .{});
    try std.testing.expectEqual(@as(u64, 2 * 1024 * 1024), stat.size);
    const literal = "`never execute` $(anything)\nsecond line";
    try std.testing.expectError(error.InvalidInput, runner.run("failure", &.{ child, "fail", literal }, .{}));
    try std.testing.expectEqualStrings(try ctx.fmt("{s}\n", .{literal}), try ctx.read(std.testing.io, try std.fs.path.join(ctx.allocator, &.{ path, "failure.stdout" }), 65536));
    const failed = try ctx.parse(try ctx.read(std.testing.io, try std.fs.path.join(ctx.allocator, &.{ path, "failure.process.json" }), 65536));
    try std.testing.expect(z.common.tag(failed, "status", "completed"));
    const argv = try ctx.array(try ctx.field(failed, "command"));
    try std.testing.expectEqualStrings(literal, try ctx.str(argv[argv.len - 1]));
    try std.testing.expectEqual(@as(i1024, 7), try ctx.integer(try ctx.field(failed, "exitCode")));
    const marker = try std.fs.path.join(ctx.allocator, &.{ path, "marker" });
    try std.testing.expectError(error.Timeout, runner.run("timeout", &.{ child, "group", marker }, .{ .timeout_ms = 100 }));
    try std.Io.sleep(std.testing.io, .fromMilliseconds(600), .awake);
    try std.testing.expectError(error.FileNotFound, tmp.dir.statFile(std.testing.io, "marker", .{}));
    const timed = try ctx.parse(try ctx.read(std.testing.io, try std.fs.path.join(ctx.allocator, &.{ path, "timeout.process.json" }), 65536));
    try std.testing.expect(z.common.tag(timed, "status", "failed") and z.common.tag(timed, "error", "Timeout"));
    try std.testing.expect(try ctx.integer(try ctx.field(timed, "exitCode")) < 0);
    runner.run("missing", &.{try std.fs.path.join(ctx.allocator, &.{ path, "no-such-executable" })}, .{}) catch {};
    const missing = try ctx.parse(try ctx.read(std.testing.io, try std.fs.path.join(ctx.allocator, &.{ path, "missing.process.json" }), 65536));
    try std.testing.expect(z.common.tag(missing, "status", "failed") and z.common.none(missing, "exitCode"));
}

test "process deadlines remain effective without async worker capacity" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try tmpPath(&ctx, tmp);
    var constrained_io: std.Io.Threaded = .init(std.testing.allocator, .{
        .async_limit = .nothing,
        .environ = std.testing.environ,
    });
    defer constrained_io.deinit();
    const runner: z.runtime.Runner = .{ .ctx = &ctx, .io = constrained_io.io(), .output = path };
    const marker = try ctx.fmt("{s}/marker", .{path});
    try std.testing.expectError(error.Timeout, runner.run("deadline", &.{ @import("test_options").child, "group", marker }, .{ .timeout_ms = 100 }));
    try std.Io.sleep(std.testing.io, .fromMilliseconds(600), .awake);
    try std.testing.expectError(error.FileNotFound, tmp.dir.statFile(std.testing.io, "marker", .{}));
    const receipt = try ctx.parse(try ctx.read(std.testing.io, try ctx.fmt("{s}/deadline.process.json", .{path}), 65536));
    try std.testing.expect(z.common.tag(receipt, "status", "failed") and z.common.tag(receipt, "error", "Timeout"));
    try std.testing.expect(try ctx.integer(try ctx.field(receipt, "exitCode")) < 0);
}

test "unavailable process wait concurrency rejects and cleans up the child group" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try tmpPath(&ctx, tmp);
    for (0..2) |limit| {
        var constrained_io: std.Io.Threaded = .init(std.testing.allocator, .{
            .async_limit = .nothing,
            .concurrent_limit = .limited(limit),
            .environ = std.testing.environ,
        });
        defer constrained_io.deinit();
        const runner: z.runtime.Runner = .{ .ctx = &ctx, .io = constrained_io.io(), .output = path };
        const name = try ctx.fmt("capacity-{d}", .{limit});
        const marker = try ctx.fmt("{s}/marker-{d}", .{ path, limit });
        try std.testing.expectError(error.ConcurrencyUnavailable, runner.run(name, &.{ @import("test_options").child, "group", marker }, .{ .timeout_ms = 100 }));
        try std.Io.sleep(std.testing.io, .fromMilliseconds(600), .awake);
        try std.testing.expectError(error.FileNotFound, tmp.dir.statFile(std.testing.io, try ctx.fmt("marker-{d}", .{limit}), .{}));
        const receipt = try ctx.parse(try ctx.read(std.testing.io, try ctx.fmt("{s}/{s}.process.json", .{ path, name }), 65536));
        try std.testing.expect(z.common.tag(receipt, "status", "failed") and z.common.tag(receipt, "error", "ConcurrencyUnavailable"));
    }
}

test "capture orchestration binds toolchain and source bytes, compares objects, and retains failed reports" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try tmpPath(&ctx, tmp);
    const child = @import("test_options").child;
    try tmp.dir.createDirPath(std.testing.io, "tree/lib/std");
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "tree/lib/std/std.zig", .data = "pub const fixture = true;\n" });
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "fixture.zig", .data = "export fn add(x: u32) u32 { return x; }\n" });
    const tree = try std.fs.path.join(ctx.allocator, &.{ path, "tree" });
    const lib = try std.fs.path.join(ctx.allocator, &.{ tree, "lib" });
    const toolchain = try ctx.parse(try ctx.json(.{ .status = "built", .freshAirCaptureImplemented = true, .zigRevision = z.revision, .compiler = .{ .path = child, .sha256 = &(try z.runtime.fileDigest(&ctx, std.testing.io, child)), .version = z.version, .zigLibDir = lib }, .sourceTree = try z.runtime.sourceIdentity(&ctx, std.testing.io, tree) }));
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "toolchain.json", .data = try ctx.json(toolchain) });
    const report_path = try std.fs.path.join(ctx.allocator, &.{ path, "toolchain.json" });
    const source_path = try std.fs.path.join(ctx.allocator, &.{ path, "fixture.zig" });
    for ([_][]const u8{ "success", "object-mismatch", "source-change" }) |behavior| {
        var environment = std.process.Environ.Map.init(ctx.allocator);
        try environment.put("ZEAN_FIXTURE_MODE", behavior);
        const output = try std.fs.path.join(ctx.allocator, &.{ path, behavior });
        const result = z.capture.run(&ctx, std.testing.io, .{
            .toolchain = report_path,
            .source = source_path,
            .output = output,
            .roots = &.{"fixture.add"},
            .environment = &environment,
            .target = .{ .triple = "aarch64-macos.15.0...15.0", .cpu = "apple_m1" },
        });
        if (std.mem.eql(u8, behavior, "success")) {
            const report = try result;
            try std.testing.expect(z.common.tag(report, "status", "captured") and z.common.flag(report, "captureComplete", true) and z.common.flag(report, "compilerVerified", false));
        } else try std.testing.expectError(error.InvalidInput, result);
        const saved = try ctx.parse(try ctx.read(std.testing.io, try std.fs.path.join(ctx.allocator, &.{ output, "report.json" }), 1024 * 1024));
        try std.testing.expect(z.common.tag(saved, "status", if (std.mem.eql(u8, behavior, "success")) "captured" else "failed"));
        const receipt = try ctx.parse(try ctx.read(std.testing.io, try std.fs.path.join(ctx.allocator, &.{ output, "ordinary.process.json" }), 65536));
        try std.testing.expect(z.common.tag(receipt, "status", "completed") and try ctx.integer(try ctx.field(receipt, "exitCode")) == 0);
        for ([_][]const u8{ "ordinary.process.json", "capture.process.json" }) |name| {
            const child_receipt = try ctx.parse(try ctx.read(std.testing.io, try std.fs.path.join(ctx.allocator, &.{ output, name }), 65536));
            const command = try ctx.array(try ctx.field(child_receipt, "command"));
            try std.testing.expectEqualStrings("-target", try ctx.str(command[8]));
            try std.testing.expectEqualStrings("aarch64-macos.15.0...15.0", try ctx.str(command[9]));
            try std.testing.expectEqualStrings("-mcpu=apple_m1", try ctx.str(command[10]));
        }
    }
}

test "evidence snapshots bind an independent client root and reject changed inputs" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try tmpPath(&ctx, tmp);
    try tmp.dir.createDirPath(std.testing.io, "client");
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "client/input.lean", .data = "abc" });
    var bundle: z.evidence.Bundle = .{
        .ctx = &ctx,
        .io = std.testing.io,
        .input_root = try ctx.fmt("{s}/client", .{path}),
        .output = try ctx.fmt("{s}/evidence", .{path}),
    };
    try std.testing.expectEqualStrings("abc", try bundle.input("input.lean"));
    try std.testing.expectEqualStrings("abc", try bundle.input("input.lean"));
    try bundle.unchanged();
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "client/input.lean", .data = "abd" });
    try std.testing.expectError(error.InvalidInput, bundle.input("input.lean"));
    try std.testing.expectError(error.InvalidInput, bundle.unchanged());
    try std.testing.expectEqualStrings("abc", try ctx.read(std.testing.io, try bundle.path("inputs/input.lean"), 16));
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "client/input.lean", .data = "abc" });
    try bundle.unchanged();
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "evidence/inputs/input.lean", .data = "abd" });
    try std.testing.expectError(error.InvalidInput, bundle.unchanged());
}

test "evidence streams large proof objects and rejects changed content" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try tmpPath(&ctx, tmp);
    const size = 64 * 1024 * 1024 + 1;
    const file = try tmp.dir.createFile(std.testing.io, "proof.olean", .{});
    defer file.close(std.testing.io);
    try file.setLength(std.testing.io, size);
    // SHA-256 of 67,108,865 zero bytes, independently recorded with shasum.
    const expected = "91990977345985aaf03af1358f4f989d7eaf985b58529efb72f613c588f6599a";
    var buffer: [64 * 1024]u8 = undefined;
    var discarded = std.Io.Writer.Discarding.init(&buffer);
    var tar: std.tar.Writer = .{ .underlying_writer = &discarded.writer };
    try z.evidence.archiveFile(&ctx, std.testing.io, &tar, try ctx.fmt("{s}/proof.olean", .{path}), "proof.olean", expected);
    try std.testing.expectEqual(@as(u64, 64 * 1024 * 1024 + 1024), discarded.fullCount());

    const original = "abc";
    const original_hash = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "original", .data = original });
    try z.evidence.archiveFile(&ctx, std.testing.io, &tar, try ctx.fmt("{s}/original", .{path}), "original", original_hash);
    for ([_][]const u8{ "abd", "ab", "abcd" }, 0..) |changed, index| {
        const name = try ctx.fmt("changed-{d}", .{index});
        try tmp.dir.writeFile(std.testing.io, .{ .sub_path = name, .data = changed });
        try std.testing.expectError(error.InvalidInput, z.evidence.archiveFile(&ctx, std.testing.io, &tar, try ctx.fmt("{s}/{s}", .{ path, name }), name, original_hash));
    }
}

test "archives reject traversal and links before publishing any source tree" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try tmpPath(&ctx, tmp);
    for ([_][]const u8{ "../escape", "/escape", "link" }, 0..) |name, index| {
        var bytes = std.Io.Writer.Allocating.init(ctx.allocator);
        var tar: std.tar.Writer = .{ .underlying_writer = &bytes.writer };
        try tar.writeFileBytes("valid", "ok", .{});
        if (index == 2) try tar.writeLink(name, "valid", .{}) else try tar.writeFileBytes(name, "bad", .{});
        try tar.finishPedantically();
        try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "source.tar", .data = bytes.written() });
        const archive = try std.fs.path.join(ctx.allocator, &.{ path, "source.tar" });
        const destination = try std.fs.path.join(ctx.allocator, &.{ path, "out" });
        try std.testing.expectError(error.InvalidInput, z.runtime.unpack(&ctx, std.testing.io, archive, destination));
        try std.testing.expectError(error.FileNotFound, tmp.dir.statFile(std.testing.io, "out", .{}));
    }
    var bytes = std.Io.Writer.Allocating.init(ctx.allocator);
    var tar: std.tar.Writer = .{ .underlying_writer = &bytes.writer };
    try tar.writeFileBytes("dir/source.zig", "ok", .{});
    try tar.finishPedantically();
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "source.tar", .data = bytes.written() });
    const archive = try std.fs.path.join(ctx.allocator, &.{ path, "source.tar" });
    const destination = try std.fs.path.join(ctx.allocator, &.{ path, "out" });
    try z.runtime.unpack(&ctx, std.testing.io, archive, destination);
    const before = try z.runtime.sourceIdentity(&ctx, std.testing.io, destination);
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "out/dir/source.zig", .data = "no" });
    try std.testing.expect(!z.common.equal(before, try z.runtime.sourceIdentity(&ctx, std.testing.io, destination)));
    try tmp.dir.symLink(std.testing.io, "dir/source.zig", "out/link", .{});
    try std.testing.expectError(error.InvalidInput, z.runtime.sourceIdentity(&ctx, std.testing.io, destination));
}

test "bounded JSON rejects duplicate keys, nonfinite numbers and excessive nesting" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    for ([_][]const u8{ "{\"name\":", "{\"name\":1,\"name\":2}", "{\"n\":NaN}" }) |raw| try std.testing.expectError(error.InvalidInput, ctx.parse(raw));
    var raw: std.ArrayList(u8) = .empty;
    try raw.appendNTimes(ctx.allocator, '[', 130);
    try raw.append(ctx.allocator, '0');
    try raw.appendNTimes(ctx.allocator, ']', 130);
    try std.testing.expectError(error.InvalidInput, ctx.parse(raw.items));
    try std.testing.expectError(error.InvalidInput, ctx.nat(.{ .bool = true }, 1));
    const value = try ctx.parse("123456789123456789123456789123456789123456789");
    try std.testing.expectEqual(@as(i1024, 123456789123456789123456789123456789123456789), try ctx.integer(value));
}

test "interruption reaps the entire child group and retains actual terminal status" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try tmpPath(&ctx, tmp);
    const child = @import("test_options").child;
    const runner: z.runtime.Runner = .{ .ctx = &ctx, .io = std.testing.io, .output = path };
    const marker = try std.fs.path.join(ctx.allocator, &.{ path, "marker" });
    try std.testing.expectError(error.Canceled, runner.run("interrupt", &.{ child, "interrupt", marker, try ctx.fmt("{d}", .{std.posix.system.getpid()}) }, .{}));
    try std.Io.sleep(std.testing.io, .fromMilliseconds(600), .awake);
    try std.testing.expectError(error.FileNotFound, tmp.dir.statFile(std.testing.io, "marker", .{}));
    const receipt = try ctx.parse(try ctx.read(std.testing.io, try std.fs.path.join(ctx.allocator, &.{ path, "interrupt.process.json" }), 65536));
    try std.testing.expect(z.common.tag(receipt, "status", "failed") and z.common.tag(receipt, "error", "Interrupted") and try ctx.integer(try ctx.field(receipt, "exitCode")) < 0);
}
