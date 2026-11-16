// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");
const f = @import("fixtures.zig");
const shared = @import("cases/shared.zig");

const definition = "pub fn choose(data: [*]const u8, len: usize) usize { _ = data[0..len]; return len; }";

fn check(ctx: *z.common.Context, name: []const u8, bytes: []const u8) !void {
    return checkAt(ctx, name, "fixture.zig", bytes);
}

fn checkAt(ctx: *z.common.Context, name: []const u8, filename: []const u8, bytes: []const u8) !void {
    var raw = try f.load(ctx.allocator, shared.air_memory_program_2_input_13);
    const sha = try ctx.allocator.dupe(u8, &z.common.digest(bytes));
    try raw.object.put(ctx.allocator, "name", .{ .string = name });
    try raw.object.put(ctx.allocator, "sourceFile", .{ .string = filename });
    try raw.object.put(ctx.allocator, "sourceSha256", .{ .string = sha });
    var sources: z.common.Value = .{ .object = .empty };
    try sources.object.put(ctx.allocator, filename, .{ .string = sha });
    try z.declaration_source.select(ctx, raw, sources, filename, bytes);
    // Source bytes and the explicit closure must independently match the record.
    try std.testing.expectError(error.InvalidInput, z.declaration_source.select(ctx, raw, sources, filename, definition ++ "// changed"));
    try sources.object.put(ctx.allocator, filename, .{ .string = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" });
    try std.testing.expectError(error.InvalidInput, z.declaration_source.select(ctx, raw, sources, filename, bytes));
}

pub fn controls() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    try check(&ctx, "fixture.choose", definition);
    try check(&ctx, "fixture.choose", definition ++ "const Decoy = struct { " ++ definition ++ " }; ");
    try check(&ctx, "fixture.Text.choose", "pub const Text = struct { " ++ definition ++ " }; ");
    try check(&ctx, "fixture.Outer.Text.choose", "const Outer = struct { const Text = struct { " ++ definition ++ " }; }; ");
    try checkAt(&ctx, "nested.fixture.choose", "nested/fixture.zig", definition);
    try checkAt(&ctx, "nested.fixture.Text.choose", "nested/fixture.zig", "const Text = struct { " ++ definition ++ " };");
    try std.testing.expectError(error.InvalidInput, checkAt(&ctx, "fixture.choose", "nested/fixture.zig", definition));
    try std.testing.expectError(error.InvalidInput, checkAt(&ctx, "other.fixture.choose", "nested/fixture.zig", definition));
    try std.testing.expectError(error.InvalidInput, checkAt(&ctx, "nested.fixture.choose", "nested/fixture.zig", "const Decoy = struct { " ++ definition ++ " };"));
    for ([_][]const u8{ "../fixture.zig", "/fixture.zig", "./fixture.zig", "nested//fixture.zig", "nested/../fixture.zig", "nested\\fixture.zig" }) |path|
        try std.testing.expectError(error.InvalidInput, z.declaration_source.ownerPrefix(&ctx, path));
    const invalid = [_]struct { name: []const u8, bytes: []const u8 }{
        .{ .name = "other.choose", .bytes = definition },
        .{ .name = "fixture.choose", .bytes = "const Decoy = struct { " ++ definition ++ " };" },
        .{ .name = "fixture.Text.choose", .bytes = "const Other = struct { " ++ definition ++ " }; const Text = Other;" },
        .{ .name = "fixture.Text.choose", .bytes = "const Text = struct { const Decoy = struct { " ++ definition ++ " }; };" },
        .{ .name = "fixture.choose", .bytes = definition ++ definition },
        .{ .name = "fixture.choose", .bytes = "pub fn choose(data: [*]const u8) usize { _ = data; return 0; }" },
        .{ .name = "fixture.choose", .bytes = "pub fn choose(noalias data: [*]const u8, len: usize) usize { _ = data; return len; }" },
        .{ .name = "fixture.choose", .bytes = "pub fn choose(comptime data: u8, len: usize) usize { _ = data; return len; }" },
        .{ .name = "fixture.choose", .bytes = "pub fn choose(data: anytype, len: usize) usize { _ = data; return len; }" },
        .{ .name = "fixture.choose", .bytes = "extern fn choose(data: [*]const u8, len: usize) usize;" },
    };
    for (invalid) |item| try std.testing.expectError(error.InvalidInput, check(&ctx, item.name, item.bytes));
    try publication();
}

fn publication() !void {
    const body = "pub const Text = struct { pub fn empty() void {} };";
    const leaf = f.derive(&shared.air_memory_program_2_input_13, &.{
        f.set("/name", f.s("fixture.Text.empty")),
        f.set("/signature/parameters", f.arr(&.{})),
        f.set("/signature/returnType", f.obj(&.{.{ "kind", f.s("void") }})),
        f.set("/sourceValidity/slices", f.arr(&.{})),
        f.set("/body", f.arr(&.{f.n("0")})),
        f.set("/instructions", f.arr(&.{f.obj(&.{
            .{ "index", f.n("0") },                               .{ "tag", f.s("ret") },                              .{ "payloadVisited", f.b(true) },
            .{ "type", f.obj(&.{.{ "kind", f.s("noreturn") }}) }, .{ "operand", f.obj(&.{.{ "kind", f.s("unit") }}) },
        })})),
    });
    for ([_]bool{ true, false }) |correct| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var ctx: z.common.Context = .{ .allocator = arena.allocator() };
        var tmp = std.testing.tmpDir(.{});
        defer tmp.cleanup();
        const path = try std.fs.path.resolve(ctx.allocator, &.{ ".zig-cache", "tmp", &tmp.sub_path });
        try tmp.dir.createDir(std.testing.io, "air", .default_dir);
        const bytes = if (correct) body else "const Decoy = struct { " ++ body ++ " };";
        const sha = try ctx.allocator.dupe(u8, &z.common.digest(bytes));
        var raw = try f.load(ctx.allocator, leaf);
        try raw.object.put(ctx.allocator, "sourceSha256", .{ .string = sha });
        const json = try ctx.json(raw);
        try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "air/leaf.json", .data = json });
        try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "fixture.zig", .data = bytes });
        const report = try ctx.json(.{
            .schema = "oksolc.fresh-air-capture.v1",
            .status = "captured",
            .captureComplete = true,
            .zigVersion = z.version,
            .zigRevision = z.revision,
            .sourceSha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            .sourceFiles = .{ .@"fixture.zig" = sha },
            .functions = .{ .@"fixture.Text.empty" = .{ .requested = false, .file = "leaf.json", .sha256 = &z.common.digest(json) } },
        });
        try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "report.json", .data = report });
        const options: z.translate.Options = .{
            .capture = try ctx.fmt("{s}/report.json", .{path}),
            .roots = &.{"fixture.Text.empty"},
            .output = try ctx.fmt("{s}/output", .{path}),
            .profile = .memory,
            .declaration_source = try ctx.fmt("{s}/fixture.zig", .{path}),
        };
        if (correct) {
            const manifest = try z.translate.run(&ctx, std.testing.io, options);
            try std.testing.expect(z.common.tag(manifest, "declarationSourceSha256", sha));
            try std.testing.expect(z.common.flag(manifest, "standaloneCapturedDeclaration", true));
            const generated = try ctx.read(std.testing.io, try ctx.fmt("{s}/Generated.lean", .{options.output}), 16384);
            try std.testing.expect(std.mem.indexOf(u8, generated, "(.ret (.constant (.scalar .unit)))") != null);
        } else {
            try std.testing.expectError(error.InvalidInput, z.translate.run(&ctx, std.testing.io, options));
            try std.testing.expectError(error.FileNotFound, tmp.dir.statFile(std.testing.io, "output", .{}));
        }
    }
}
