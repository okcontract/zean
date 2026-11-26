// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");
const f = @import("fixtures.zig");
const shared = @import("cases/shared.zig");
const golden = @import("cases/golden.zig");

pub fn controls() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    try std.testing.expectEqualStrings("\"quote\\\" slash\\\\ line\\n λ\"", try z.certificate.string(&ctx, "quote\" slash\\ line\n λ"));
    try std.testing.expectError(error.InvalidInput, z.certificate.string(&ctx, "\x01"));
    try std.testing.expectError(error.InvalidInput, z.certificate.string(&ctx, "\xff"));
    try std.testing.expectError(error.InvalidInput, z.certificate.lift(&ctx, .{ .float = 1.5 }, 0));
    try std.testing.expectError(error.InvalidInput, z.certificate.lift(&ctx, .null, 129));
}

pub fn standaloneOrder() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDir(io, "air", .default_dir);
    const directory = try std.fs.path.resolve(ctx.allocator, &.{ ".zig-cache", "tmp", &tmp.sub_path });
    const roots = [_][]const u8{ "fixture.choose", "fixture.choose_captured" };
    var entries: z.common.Value = .{ .object = .empty };
    var record = try f.load(ctx.allocator, shared.air_scalar_program_1_input_2);
    for (roots, 0..) |root, i| {
        try record.object.put(ctx.allocator, "name", .{ .string = root });
        const bytes = try ctx.json(record);
        const file = try ctx.fmt("{d}.json", .{i});
        try tmp.dir.writeFile(io, .{ .sub_path = try ctx.fmt("air/{s}", .{file}), .data = bytes });
        try entries.object.put(ctx.allocator, root, try ctx.parse(try ctx.json(.{ .requested = true, .file = file, .sha256 = &z.common.digest(bytes) })));
    }
    const report = try ctx.json(.{ .schema = "oksolc.fresh-air-capture.v1", .status = "captured", .captureComplete = true, .zigVersion = z.version, .zigRevision = z.revision, .sourceSha256 = try ctx.field(record, "sourceSha256"), .functions = entries });
    try tmp.dir.writeFile(io, .{ .sub_path = "report.json", .data = report });
    const output = try ctx.fmt("{s}/model", .{directory});
    _ = try z.translate.run(&ctx, io, .{ .capture = try ctx.fmt("{s}/report.json", .{directory}), .roots = &roots, .output = output, .emit_correspondence = true });
    const model = try ctx.read(io, try ctx.fmt("{s}/Generated.lean", .{output}), 65536);
    var rest = model;
    for ([_][]const u8{
        "def fn_choose : Program :=",      "def fn_choose_captured : Program :=",
        "namespace Certificate.fn_choose", "theorem fn_choose_correspondence :",
        "end Certificate.fn_choose",       "theorem fn_choose_captured_correspondence :",
    }) |marker| {
        const at = std.mem.indexOf(u8, rest, marker) orelse return error.TestUnexpectedResult;
        rest = rest[at + marker.len ..];
    }
}

pub const mutations = [_]f.Edit{
    f.set("/instructions/0/zirParameterIndex", f.n("1")),
    f.set("/instructions/3/operand/value", f.n("2")),
    f.set("/instructions/2/tag", f.s("ptr_add")),
    f.set("/body", f.arr(&.{ f.n("1"), f.n("0"), f.n("2"), f.n("3") })),
    f.set("/body", f.arr(&.{ f.n("0"), f.n("1"), f.n("3") })),
    f.set("/sourceValidity/slices/0/upperBound", f.obj(&.{ .{ "kind", f.s("arrayLength") }, .{ "value", f.n("0") } })),
    f.set("/instructions/2/tag", f.s("unrecognized_operation")),
    f.set("/signature/parameters/0/flags/isConst", f.b(false)),
};

pub fn emitted(ctx: *z.common.Context, mutation: ?usize) ![]const u8 {
    const raw = try f.load(ctx.allocator, if (mutation) |index| f.derive(&shared.air_memory_program_2_input_13, mutations[index .. index + 1]) else f.ref(&shared.air_memory_program_2_input_13));
    // Independently recorded model, not constructed from the input decoder.
    const model = try f.load(ctx.allocator, golden.air_memory_program_2_output_30);
    return ctx.fmt("import Compiler.ZigAir.Captured\nopen Compiler.ZigAir.MemoryAir\ndef program : Program :=\n{s}\n{s}\n", .{ model.string, try z.certificate.declaration(ctx, raw, "program", false) });
}

pub const scalar_mutations = [_]f.Edit{
    f.set("/instructions/0/zirParameterIndex", f.n("1")),
    f.set("/instructions/2/rhs/value", f.n("129")),
    f.set("/instructions/4/tag", f.s("sub")),
    f.set("/instructions/4/tag", f.s("add_wrap")),
    f.set("/instructions/3/thenBody", f.arr(&.{ f.n("5"), f.n("4") })),
    f.set("/instructions/3/thenBody", f.arr(&.{f.n("5")})),
    f.set("/instructions/3/thenBody", f.arr(&.{f.n("6")})),
    f.set("/instructions/4/payloadVisited", f.b(false)),
    f.set("/instructions/4/tag", f.s("unrecognized_operation")),
    f.set("/instructions/4/tag", f.s("store")),
    f.set("/instructions/4/type/bits", f.n("257")),
    f.set("/sourceValidity/slices", f.arr(&.{.null})),
    f.set("/instructions/7/operand/index", f.n("0")),
};

pub fn scalarEmitted(ctx: *z.common.Context, mutation: ?usize) ![]const u8 {
    const raw = try f.load(ctx.allocator, if (mutation) |index| f.derive(&shared.air_scalar_program_1_input_2, scalar_mutations[index .. index + 1]) else f.ref(&shared.air_scalar_program_1_input_2));
    // Retain the independently recorded model when changing the raw input.
    const model = try f.load(ctx.allocator, golden.air_scalar_program_1_output_11);
    return ctx.fmt("import Compiler.ZigAir.CapturedScalar\nopen Compiler.ZigAir.Scalar\ndef program : Program :=\n{s}\n{s}\n", .{ model.string, try z.certificate.scalarDeclaration(ctx, raw, "program") });
}
