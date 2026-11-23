// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");

const manifest =
    \\{"schema":"zean.client.v1","source":"wrapper.zig","sources":["shared.zig"],
    \\ "roots":["wrapper.selected"],"profile":"scalar","generatedModule":"Example.Generated",
    \\ "libraries":[],"proofs":[],"theorems":[]}
;

pub fn controls() !void {
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    try tmp.dir.createDir(io, "verification", .default_dir);
    try tmp.dir.writeFile(io, .{ .sub_path = "verification/client.json", .data = manifest });
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };

    var map: z.client.SourceMap = .empty;
    try map.put(ctx.allocator, "verification/shared.zig", .{ .path = "src/shared.zig" });
    const plan = try z.client.load(&ctx, io, tmp.dir, "verification/client.json", &map);
    try std.testing.expectEqualStrings("verification/wrapper.zig", plan.inputs[0].actual);
    try std.testing.expectEqualStrings("src/shared.zig", plan.inputs[1].actual);
    try std.testing.expectEqualStrings("shared.zig", plan.inputs[1].logical);
    try std.testing.expect(map.get("verification/shared.zig").?.used);
    try std.testing.expectError(error.InvalidInput, z.client.load(&ctx, io, tmp.dir, "verification/client.json", null));
    try std.testing.expectError(error.InvalidInput, z.client.load(&ctx, io, tmp.dir, "verification/../client.json", &map));

    const args = try z.Arguments.project(&ctx, &.{ "--check", "one directory", "--evidence", "run" });
    try std.testing.expectEqualStrings("one directory", args.directory.?);
    try std.testing.expect(args.flag("--check"));
    try std.testing.expectEqualStrings("run", try args.one("--evidence"));
    try std.testing.expectError(error.InvalidInput, z.Arguments.project(&ctx, &.{ "first", "second" }));
    try std.testing.expectError(error.InvalidInput, z.Arguments.project(&ctx, &.{ "--evidence", "--check" }));

    const baseline =
        \\{"schema":"zean.project.v1","clients":["verification/client.json"],
        \\ "sourceMap":{"verification/shared.zig":"src/shared.zig"}}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "zean.json", .data = baseline });
    var buffer: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const length = try tmp.dir.realPath(io, &buffer);
    const options: z.project.Options = .{ .directory = buffer[0..length] };
    var env: std.process.Environ.Map = .init(ctx.allocator);
    var output_buffer: [1024]u8 = undefined;
    var output: std.Io.Writer = .fixed(&output_buffer);
    try std.testing.expectError(error.InvalidInput, z.project.run(&ctx, io, std.testing.allocator, options, &env, &output));
    try std.testing.expect(std.mem.containsAtLeast(u8, ctx.diagnostic, 1, "standalone"));
    {
        const lock: std.Io.File = .{ .handle = tmp.dir.handle, .flags = .{ .nonblocking = false } };
        try std.testing.expect(try lock.tryLock(io, .exclusive));
        defer lock.unlock(io);
        try std.testing.expectError(error.InvalidInput, z.project.run(&ctx, io, std.testing.allocator, options, &env, &output));
        try std.testing.expect(std.mem.startsWith(u8, ctx.diagnostic, "another Zean run is using"));
    }

    try tmp.dir.createDirPath(io, "lean/Example");
    const handwritten = "-- handwritten proof\n";
    try tmp.dir.writeFile(io, .{ .sub_path = "lean/Example/Generated.lean", .data = handwritten });
    try std.testing.expectError(error.InvalidInput, z.project.run(&ctx, io, std.testing.allocator, options, &env, &output));
    try std.testing.expect(std.mem.containsAtLeast(u8, ctx.diagnostic, 1, "is not a Zean-generated file"));
    try std.testing.expectEqualStrings(handwritten, try tmp.dir.readFileAlloc(io, "lean/Example/Generated.lean", ctx.allocator, .limited(128)));

    try tmp.dir.symLink(io, "lean", "linked", .{ .is_directory = true });
    var linked = try ctx.parse(baseline);
    try linked.object.put(ctx.allocator, "leanDir", .{ .string = "linked" });
    try tmp.dir.writeFile(io, .{ .sub_path = "zean.json", .data = try ctx.json(linked) });
    try std.testing.expectError(error.InvalidInput, z.project.run(&ctx, io, std.testing.allocator, options, &env, &output));
    try std.testing.expect(std.mem.containsAtLeast(u8, ctx.diagnostic, 1, "cannot read generated destination"));

    var overlap = try ctx.parse(baseline);
    try overlap.object.put(ctx.allocator, "leanDir", .{ .string = "verification" });
    try overlap.object.put(ctx.allocator, "clients", try ctx.parse("[\"verification/client.json\",\"verification/other.json\"]"));
    try tmp.dir.writeFile(io, .{ .sub_path = "zean.json", .data = try ctx.json(overlap) });
    var other = try ctx.parse(manifest);
    try other.object.put(ctx.allocator, "generatedModule", .{ .string = "Other.Generated" });
    try other.object.put(ctx.allocator, "proofs", try ctx.parse(
        \\[{"module":"Example.Proofs","path":"Example/Generated.lean"}]
    ));
    try other.object.put(ctx.allocator, "theorems", try ctx.parse("[\"Example.safe\"]"));
    try tmp.dir.writeFile(io, .{ .sub_path = "verification/other.json", .data = try ctx.json(other) });
    try tmp.dir.createDirPath(io, "verification/Example");
    const managed = "-- Autogenerated by Zean. Do not edit.\n";
    try tmp.dir.writeFile(io, .{ .sub_path = "verification/Example/Generated.lean", .data = managed });
    try std.testing.expectError(error.InvalidInput, z.project.run(&ctx, io, std.testing.allocator, options, &env, &output));
    try std.testing.expectEqualStrings("generated destination verification/Example/Generated.lean overlaps a client input", ctx.diagnostic);
    try std.testing.expectEqualStrings(managed, try tmp.dir.readFileAlloc(io, "verification/Example/Generated.lean", ctx.allocator, .limited(128)));

    try tmp.dir.hardLink("verification/Example/Generated.lean", tmp.dir, "verification/Alias.lean", io, .{});
    other.object.getPtr("proofs").?.array.items[0].object.getPtr("path").?.* = .{ .string = "Alias.lean" };
    try tmp.dir.writeFile(io, .{ .sub_path = "verification/other.json", .data = try ctx.json(other) });
    try std.testing.expectError(error.InvalidInput, z.project.run(&ctx, io, std.testing.allocator, options, &env, &output));
    try std.testing.expectEqualStrings("generated destination verification/Example/Generated.lean overlaps a client input", ctx.diagnostic);
    try std.testing.expectEqualStrings(managed, try tmp.dir.readFileAlloc(io, "verification/Alias.lean", ctx.allocator, .limited(128)));
}

pub fn inventoryControls() !void {
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    var env: std.process.Environ.Map = .init(ctx.allocator);
    var output_buffer: [1024]u8 = undefined;
    var output: std.Io.Writer = .fixed(&output_buffer);
    var buffer: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const directory = buffer[0..try tmp.dir.realPath(io, &buffer)];
    const baseline =
        \\{"schema":"zean.project.v1","clients":["client.json"],"leanDir":"models"}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "client.json", .data = manifest });
    try tmp.dir.writeFile(io, .{ .sub_path = "zean.json", .data = baseline });
    try tmp.dir.createDir(io, "models", .default_dir);
    const obsolete = "models/Previous.lean";
    const managed = "-- Autogenerated by Zean. Do not edit.\ndef previous : Nat := 0\n";
    try tmp.dir.writeFile(io, .{ .sub_path = obsolete, .data = managed });
    const expected = "obsolete Zean output models/Previous.lean. Remove it or restore its client";
    var options: z.project.Options = .{ .directory = directory, .check = true };
    try std.testing.expectError(error.InvalidInput, z.project.run(&ctx, io, std.testing.allocator, options, &env, &output));
    try std.testing.expectEqualStrings(expected, ctx.diagnostic);

    // Changing leanDir must not hide an earlier output recorded in the inventory.
    var moved = try ctx.parse(baseline);
    moved.object.getPtr("leanDir").?.* = .{ .string = "lean" };
    try tmp.dir.writeFile(io, .{ .sub_path = "zean.json", .data = try ctx.json(moved) });
    const inventory =
        \\{"schema":"zean.outputs.v1","outputs":["models/Previous.lean"]}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "zean.outputs.json", .data = inventory });
    try std.testing.expectError(error.InvalidInput, z.project.run(&ctx, io, std.testing.allocator, options, &env, &output));
    try std.testing.expectEqualStrings(expected, ctx.diagnostic);
    try std.testing.expectEqualStrings(managed, try tmp.dir.readFileAlloc(io, obsolete, ctx.allocator, .limited(128)));

    const handwritten = "-- handwritten theorem\n";
    try tmp.dir.writeFile(io, .{ .sub_path = obsolete, .data = handwritten });
    try std.testing.expectError(error.InvalidInput, z.project.run(&ctx, io, std.testing.allocator, options, &env, &output));
    try std.testing.expectEqualStrings("zean.outputs.json needs regeneration. Run zean without --check", ctx.diagnostic);
    try std.testing.expectEqualStrings(handwritten, try tmp.dir.readFileAlloc(io, obsolete, ctx.allocator, .limited(128)));

    options.check = false;
    options.toolchain = try ctx.fmt("{s}/toolchain.json", .{directory});
    options.evidence = try ctx.fmt("{s}/new/evidence", .{directory});
    try tmp.dir.writeFile(io, .{ .sub_path = "toolchain.json", .data = "{}" });
    try std.testing.expectError(error.InvalidInput, z.project.run(&ctx, io, std.testing.allocator, options, &env, &output));
    try std.testing.expect(std.mem.startsWith(u8, ctx.diagnostic, "choose an --evidence directory outside"));
    try std.testing.expectError(error.FileNotFound, tmp.dir.statFile(io, "new", .{}));

    try moved.object.put(ctx.allocator, "captureTarget", try ctx.parse(
        \\{"triple":"aarch64-macos.15.0","cpu":"native"}
    ));
    try tmp.dir.writeFile(io, .{ .sub_path = "zean.json", .data = try ctx.json(moved) });
    try std.testing.expectError(error.InvalidInput, z.project.run(&ctx, io, std.testing.allocator, options, &env, &output));
    try std.testing.expectEqualStrings("captureTarget requires an explicit architecture and CPU", ctx.diagnostic);
}

pub fn retiredControls() !void {
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };

    const original =
        \\{"schema":"zean.outputs.v1","outputs":["old/Cell.lean"]}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "zean.outputs.json", .data = original });
    const prior = try z.project_outputs.Inventory.load(&ctx, io, tmp.dir);
    var active = [_][]const u8{"lean/Cell/Renamed.lean"};
    const bytes = try prior.encode(&ctx, &active);
    const value = try ctx.parse(bytes);
    const retired = try ctx.array(try ctx.field(value, "retired"));
    try std.testing.expectEqual(@as(usize, 1), retired.len);
    try std.testing.expectEqualStrings("old/Cell.lean", try ctx.str(retired[0]));
    try prior.publish(&ctx, io, tmp.dir, bytes);

    const updated = try z.project_outputs.Inventory.load(&ctx, io, tmp.dir);
    try updated.checkObsolete(&ctx, io, tmp.dir, "lean", &active);
    try std.testing.expectEqualStrings(bytes, try updated.encode(&ctx, &active));
    try tmp.dir.createDir(io, "old", .default_dir);
    const restored = "-- Autogenerated by Zean. Do not edit.\ndef previous : Nat := 0\n";
    try tmp.dir.writeFile(io, .{ .sub_path = "old/Cell.lean", .data = restored });
    try std.testing.expectError(error.InvalidInput, updated.checkObsolete(&ctx, io, tmp.dir, "lean", &active));
    try std.testing.expectEqualStrings("obsolete Zean output old/Cell.lean. Remove it or restore its client", ctx.diagnostic);
    try std.testing.expectEqualStrings(restored, try tmp.dir.readFileAlloc(io, "old/Cell.lean", ctx.allocator, .limited(128)));
}

pub fn nestedControls() !void {
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    const nested =
        \\{"schema":"zean.outputs.v1","outputs":["lean/Child.lean"]}
    ;
    try tmp.dir.createDirPath(io, "nested/lean");
    try tmp.dir.writeFile(io, .{ .sub_path = "nested/zean.outputs.json", .data = nested });
    const generated = "-- Autogenerated by Zean. Do not edit.\ndef model : Nat := 0\n";
    try tmp.dir.writeFile(io, .{ .sub_path = "nested/lean/Child.lean", .data = generated });

    const parent = try z.project_outputs.Inventory.load(&ctx, io, tmp.dir);
    try parent.checkObsolete(&ctx, io, tmp.dir, ".", &.{"Parent.lean"});
    try parent.checkObsolete(&ctx, io, tmp.dir, "nested/lean", &.{"nested/lean/Parent.lean"});
    try std.testing.expectError(error.InvalidInput, parent.checkObsolete(&ctx, io, tmp.dir, ".", &.{"nested/lean/Child.lean"}));
    try std.testing.expectEqualStrings("generated destination nested/lean/Child.lean belongs to a nested Zean project", ctx.diagnostic);

    try tmp.dir.writeFile(io, .{ .sub_path = "nested/lean/Unclaimed.lean", .data = generated });
    try std.testing.expectError(error.InvalidInput, parent.checkObsolete(&ctx, io, tmp.dir, ".", &.{"Parent.lean"}));
    try std.testing.expectEqualStrings("obsolete Zean output nested/lean/Unclaimed.lean. Remove it or restore its client", ctx.diagnostic);
}
