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

    // Changing leanDir must not hide an earlier output recorded in the inventory.
    var moved = try ctx.parse(baseline);
    moved.object.getPtr("leanDir").?.* = .{ .string = "lean" };
    try tmp.dir.writeFile(io, .{ .sub_path = "zean.json", .data = try ctx.json(moved) });
    const inventory =
        \\{"schema":"zean.outputs.v1","outputs":["models/Previous.lean"],"retired":[]}
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

    var ownership = try z.project_outputs.Ownership.init(&ctx, io, tmp.dir);
    defer ownership.deinit(ctx.allocator, io);
    const original =
        \\{"schema":"zean.outputs.v1","outputs":["old/Cell.lean"],"retired":[]}
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
    try updated.check(&ctx, io, ownership, &active);
    try std.testing.expectEqualStrings(bytes, try updated.encode(&ctx, &active));
    try tmp.dir.createDir(io, "old", .default_dir);
    const restored = "-- Autogenerated by Zean. Do not edit.\ndef previous : Nat := 0\n";
    try tmp.dir.writeFile(io, .{ .sub_path = "old/Cell.lean", .data = restored });
    try std.testing.expectError(error.InvalidInput, updated.check(&ctx, io, ownership, &active));
    try std.testing.expectEqualStrings("obsolete Zean output old/Cell.lean. Remove it or restore its client", ctx.diagnostic);
    try std.testing.expectEqualStrings(restored, try tmp.dir.readFileAlloc(io, "old/Cell.lean", ctx.allocator, .limited(128)));
}

pub fn retiringLayoutControls() !void {
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    var owner = try z.project_outputs.Ownership.init(&ctx, io, tmp.dir);
    defer owner.deinit(ctx.allocator, io);
    const previous =
        \\{"schema":"zean.outputs.v1","outputs":["lean/Models.lean"],"retired":["old/Tree.lean/Child.lean"]}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "zean.outputs.json", .data = previous });
    try tmp.dir.createDir(io, "lean", .default_dir);
    try tmp.dir.writeFile(io, .{ .sub_path = "lean/Models.lean", .data = z.files.generated_lean_header });
    try tmp.dir.rename("lean/Models.lean", tmp.dir, "saved.lean", io);
    const inventory = try z.project_outputs.Inventory.load(&ctx, io, tmp.dir);
    try tmp.dir.writeFile(io, .{ .sub_path = "client.json", .data = manifest });
    try tmp.dir.writeFile(io, .{ .sub_path = "zean.json", .data =
        \\{"schema":"zean.project.v1","clients":["client.json"],"leanDir":"lean/Models.lean"}
    });
    var env: std.process.Environ.Map = .init(ctx.allocator);
    var output: std.Io.Writer = .fixed(&.{});
    var buffer: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const directory = buffer[0..try tmp.dir.realPath(io, &buffer)];
    for ([_]bool{ false, true }) |check| {
        const options: z.project.Options = .{ .directory = directory, .check = check };
        try std.testing.expectError(error.InvalidInput, z.project.run(&ctx, io, std.testing.allocator, options, &env, &output));
        try std.testing.expectEqualStrings("generated destination lean/Models.lean/Example/Generated.lean conflicts with recorded output lean/Models.lean. One path needs the other as a directory", ctx.diagnostic);
    }
    try std.testing.expectError(error.InvalidInput, inventory.check(&ctx, io, owner, &.{"old/Tree.lean"}));
    try std.testing.expectEqualStrings("generated destination old/Tree.lean conflicts with recorded output old/Tree.lean/Child.lean. One path needs the other as a directory", ctx.diagnostic);
    try inventory.check(&ctx, io, owner, &.{ "lean/Models.lean", "old/Tree.lean/Child.lean" });
    try inventory.check(&ctx, io, owner, &.{"lean/models.lean"});
    try inventory.check(&ctx, io, owner, &.{"lean/Models.lean.backup/Cell/Generated.lean"});
    try std.testing.expectError(error.FileNotFound, tmp.dir.statFile(io, "lean/Models.lean", .{}));
    try std.testing.expectEqualStrings(previous, try tmp.dir.readFileAlloc(io, "zean.outputs.json", ctx.allocator, .limited(256)));
}

pub fn nestedControls() !void {
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    var ownership = try z.project_outputs.Ownership.init(&ctx, io, tmp.dir);
    defer ownership.deinit(ctx.allocator, io);
    const nested =
        \\{"schema":"zean.outputs.v1","outputs":["lean/Child.lean"],"retired":["missing/Previous.lean"]}
    ;
    try tmp.dir.createDirPath(io, "nested/lean");
    try tmp.dir.writeFile(io, .{ .sub_path = "nested/zean.outputs.json", .data = nested });
    const generated = "-- Autogenerated by Zean. Do not edit.\ndef model : Nat := 0\n";
    try tmp.dir.writeFile(io, .{ .sub_path = "nested/lean/Child.lean", .data = generated });

    const parent = try z.project_outputs.Inventory.load(&ctx, io, tmp.dir);
    try parent.check(&ctx, io, ownership, &.{"Parent.lean"});
    try std.testing.expectError(error.InvalidInput, parent.check(&ctx, io, ownership, &.{"nested/lean/Child.lean"}));
    try std.testing.expectEqualStrings("generated destination nested/lean/Child.lean belongs to a nested Zean project", ctx.diagnostic);

    const recorded =
        \\{"schema":"zean.outputs.v1","outputs":["Parent.lean"],"retired":[]}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "zean.outputs.json", .data = recorded });
    const updated = try z.project_outputs.Inventory.load(&ctx, io, tmp.dir);
    try tmp.dir.writeFile(io, .{ .sub_path = "nested/lean/Other.lean", .data = generated });
    try updated.check(&ctx, io, ownership, &.{ "Parent.lean", "nested/lean/Other.lean" });
    try tmp.dir.writeFile(io, .{ .sub_path = "nested/missing", .data = "ordinary file\n" });
    try updated.check(&ctx, io, ownership, &.{"nested/lean/Other.lean"});
    try tmp.dir.deleteFile(io, "nested/missing");
    try std.testing.expectError(error.InvalidInput, updated.check(&ctx, io, ownership, &.{ "Parent.lean", "nested/lean/Child.lean" }));
    try std.testing.expectEqualStrings("generated destination nested/lean/Child.lean belongs to a nested Zean project", ctx.diagnostic);
    try std.testing.expectError(error.InvalidInput, updated.check(&ctx, io, ownership, &.{"nested/missing/Previous.lean"}));
    try std.testing.expectEqualStrings("generated destination nested/missing/Previous.lean belongs to a nested Zean project", ctx.diagnostic);

    try tmp.dir.hardLink("nested/lean/Child.lean", tmp.dir, "nested/lean/Alias.lean", io, .{});
    try std.testing.expectError(error.InvalidInput, updated.check(&ctx, io, ownership, &.{"nested/lean/Alias.lean"}));
    try std.testing.expectEqualStrings("generated destination nested/lean/Alias.lean belongs to a nested Zean project", ctx.diagnostic);
}

pub fn enclosingControls() !void {
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    const parent =
        \\{"schema":"zean.outputs.v1","outputs":["nested/lean/Parent.lean"],"retired":["old/Cell/Generated.lean"]}
    ;
    const nested =
        \\{"schema":"zean.outputs.v1","outputs":["lean/Child.lean"],"retired":["café/Removed.lean","résumé/Missing.lean","ᲀ/Generated.lean","lean/Generated.lean"]}
    ;
    const child_path = "nested/lean/Child.lean";
    const parent_path = "nested/lean/Parent.lean";
    const generated = "-- Autogenerated by Zean. Do not edit.\ndef model : Nat := 0\n";
    try tmp.dir.createDirPath(io, "nested/lean");
    try tmp.dir.createDirPath(io, "nested/café");
    try tmp.dir.writeFile(io, .{ .sub_path = "zean.outputs.json", .data = parent });
    try tmp.dir.writeFile(io, .{ .sub_path = "nested/zean.outputs.json", .data = nested });
    try tmp.dir.writeFile(io, .{ .sub_path = child_path, .data = generated });
    try tmp.dir.writeFile(io, .{ .sub_path = parent_path, .data = generated });
    const child = try tmp.dir.openDir(io, "nested", .{});
    defer child.close(io);
    var child_ownership = try z.project_outputs.Ownership.init(&ctx, io, child);
    defer child_ownership.deinit(ctx.allocator, io);
    try std.testing.expect(!try z.files.directoryFile(tmp.dir).tryLock(io, .exclusive));

    const child_inventory = try z.project_outputs.Inventory.load(&ctx, io, child);
    try child_inventory.check(&ctx, io, child_ownership, &.{"lean/Child.lean"});
    try std.testing.expectError(error.InvalidInput, child_inventory.check(&ctx, io, child_ownership, &.{ "lean/Child.lean", "lean/Parent.lean" }));
    try std.testing.expectEqualStrings("generated destination lean/Parent.lean belongs to an enclosing Zean project", ctx.diagnostic);

    const parent_inventory = try z.project_outputs.Inventory.load(&ctx, io, tmp.dir);
    var parent_ownership = try z.project_outputs.Ownership.init(&ctx, io, tmp.dir);
    defer parent_ownership.deinit(ctx.allocator, io);
    // Observe each spelling on this directory's filesystem, then remove the entry
    // before checking ownership. Linux directories can opt into case folding.
    const Pair = struct { recorded: []const u8, requested: []const u8, destination: []const u8 };
    for ([_]Pair{
        .{ .recorded = "ᲀ", .requested = "в", .destination = "nested/в/Generated.lean" },
        .{ .recorded = "résumé", .requested = "re\u{0301}sume\u{0301}", .destination = "nested/re\u{0301}sume\u{0301}/Missing.lean" },
        .{ .recorded = "lean/Generated.lean", .requested = "lean/generated.lean", .destination = "nested/lean/generated.lean" },
        .{ .recorded = "ᲀ", .requested = "unrelated", .destination = "nested/unrelated/Generated.lean" },
    }) |pair| {
        try child.createDir(io, pair.recorded, .default_dir);
        const same_entry = if (child.statFile(io, pair.requested, .{})) |stat|
            stat.inode == (try child.statFile(io, pair.recorded, .{})).inode
        else |err| switch (err) {
            error.FileNotFound => false,
            else => return err,
        };
        try child.deleteDir(io, pair.recorded);
        const check = parent_inventory.check(&ctx, io, parent_ownership, &.{ parent_path, pair.destination });
        if (same_entry) {
            try std.testing.expectError(error.InvalidInput, check);
            try std.testing.expectEqualStrings(try ctx.fmt("generated destination {s} belongs to a nested Zean project", .{pair.destination}), ctx.diagnostic);
        } else try check;
        try std.testing.expectError(error.FileNotFound, child.statFile(io, pair.requested, .{}));
    }
    try tmp.dir.writeFile(io, .{ .sub_path = "old", .data = "ordinary file\n" });
    try child_inventory.check(&ctx, io, child_ownership, &.{"lean/Child.lean"});
    try parent_inventory.check(&ctx, io, parent_ownership, &.{parent_path});
    try std.testing.expectError(error.NotDir, parent_inventory.check(&ctx, io, parent_ownership, &.{"old/Cell/Generated.lean"}));
    const alias_dir = tmp.dir.openDir(io, "nested/cafe\u{0301}", .{}) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer alias_dir.close(io);
    try std.testing.expectError(error.FileNotFound, alias_dir.statFile(io, "Removed.lean", .{}));
    try std.testing.expectError(error.InvalidInput, parent_inventory.check(&ctx, io, parent_ownership, &.{ parent_path, "nested/cafe\u{0301}/Removed.lean" }));
    try std.testing.expectEqualStrings("generated destination nested/cafe\u{0301}/Removed.lean belongs to a nested Zean project", ctx.diagnostic);
}

pub fn fileDirectoryControls() !void {
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    try tmp.dir.createDirPath(io, "child/Models.lean/Cell");
    const child = try tmp.dir.openDir(io, "child", .{});
    defer child.close(io);
    const model = "Models.lean/Cell/Generated.lean";
    try child.writeFile(io, .{ .sub_path = model, .data = z.files.generated_lean_header });
    try child.writeFile(io, .{ .sub_path = "zean.outputs.json", .data =
        \\{"schema":"zean.outputs.v1","outputs":["Models.lean/Cell/Generated.lean"],"retired":["Previous.lean"]}
    });
    try child.rename("Models.lean", child, "aside", io);
    var owner = try z.project_outputs.Ownership.init(&ctx, io, tmp.dir);
    defer owner.deinit(ctx.allocator, io);
    const inventory = try z.project_outputs.Inventory.load(&ctx, io, tmp.dir);
    const dest = "child/Models.lean";
    try std.testing.expectError(error.InvalidInput, inventory.check(&ctx, io, owner, &.{dest}));
    try std.testing.expectEqualStrings("generated destination " ++ dest ++ " belongs to a nested Zean project", ctx.diagnostic);
    try std.testing.expectError(error.InvalidInput, inventory.check(&ctx, io, owner, &.{"child/Previous.lean/Other.lean"}));
    try inventory.check(&ctx, io, owner, &.{"child/Models.lean.backup/Other.lean"});
    try std.testing.expectError(error.FileNotFound, child.statFile(io, "Models.lean", .{}));
    const folds_case = if (child.statFile(io, "ASIDE", .{})) |_| true else |err| switch (err) {
        error.FileNotFound => false,
        else => return err,
    };
    for ([_][]const u8{ "child/models.lean", "child/previous.lean/Other.lean" }) |spelling| {
        const check = inventory.check(&ctx, io, owner, &.{spelling});
        if (folds_case) try std.testing.expectError(error.InvalidInput, check) else try check;
    }

    // A checkout produced by an earlier run may already have the blocking file.
    try child.writeFile(io, .{ .sub_path = "Models.lean", .data = z.files.generated_lean_header });
    try std.testing.expectError(error.InvalidInput, inventory.check(&ctx, io, owner, &.{dest}));
    try child.hardLink("Models.lean", child, "Independent.lean", io, .{});
    try inventory.check(&ctx, io, owner, &.{"child/Independent.lean"});
    try child.createDir(io, "Previous.lean", .default_dir);
    try std.testing.expectError(error.InvalidInput, inventory.check(&ctx, io, owner, &.{"child/Previous.lean/Other.lean"}));
    try inventory.check(&ctx, io, owner, &.{"child/Sibling.lean"});

    try tmp.dir.writeFile(io, .{ .sub_path = "zean.outputs.json", .data =
        \\{"schema":"zean.outputs.v1","outputs":["child/Outer.lean"],"retired":["child/Branch.lean/Old.lean"]}
    });
    var child_owner = try z.project_outputs.Ownership.init(&ctx, io, child);
    defer child_owner.deinit(ctx.allocator, io);
    const child_inventory = try z.project_outputs.Inventory.load(&ctx, io, child);
    for ([_][]const u8{ "Outer.lean/Other.lean", "Branch.lean" }) |path| {
        try std.testing.expectError(error.InvalidInput, child_inventory.check(&ctx, io, child_owner, &.{path}));
        try std.testing.expectEqualStrings(try ctx.fmt("generated destination {s} belongs to an enclosing Zean project", .{path}), ctx.diagnostic);
    }
}

pub fn replayControls() !void {
    const io = std.testing.io;
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const directory = try tmp.dir.realPathFileAlloc(io, ".", ctx.allocator);
    const output = try std.fs.path.join(ctx.allocator, &.{ directory, "replay" });
    try tmp.dir.writeFile(io, .{
        .sub_path = "zean.json",
        .data = "{\"schema\":\"zean.project.v1\",\"clients\":[\"proofs/client.json\"]}",
    });
    var env: std.process.Environ.Map = .init(ctx.allocator);
    defer env.deinit();
    var options: z.client.Options = .{
        .manifest = "unlisted.json",
        .toolchain = "unused.json",
        .output = output,
    };
    try std.testing.expectError(error.InvalidInput, z.project.replayClient(&ctx, io, directory, options, &env));
    try std.testing.expectEqualStrings("client is not declared in zean.json", ctx.diagnostic);
    options.manifest = "../client.json";
    try std.testing.expectError(error.InvalidInput, z.project.replayClient(&ctx, io, directory, options, &env));
    options.manifest = "proofs/client.json";
    try std.testing.expectError(error.FileNotFound, z.project.replayClient(&ctx, io, directory, options, &env));
    try std.testing.expectError(error.FileNotFound, tmp.dir.access(io, "replay", .{}));
}
