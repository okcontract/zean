// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");
const f = @import("fixtures.zig");
const shared = @import("cases/shared.zig");

const size = f.obj(&.{ .{ "kind", f.s("int") }, .{ "bits", f.n("64") }, .{ "signedness", f.s("unsigned") } });
const view = f.ref(&shared.pointer_21);
const pointer = f.ref(&shared.pointer_17);
fn ref(comptime index: []const u8) f.Value {
    return comptime f.obj(&.{ .{ "kind", f.s("instruction") }, .{ "index", f.n(index) } });
}
const bounded = f.derive(&shared.air_memory_program_2_input_13, &.{
    f.set("/signature/parameters", f.arr(&.{ view, size, size })),                                               f.set("/signature/returnType", view),
    f.set("/sourceOperationTags", f.arr(&.{f.s("slice_length")})),
    f.set("/sourceValidity/slices", f.arr(&.{f.obj(&.{
        .{ "source", f.obj(&.{ .{ "file", f.s("fixture.zig") }, .{ "sha256", f.s("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") }, .{ "span", f.obj(&.{ .{ "start", f.n("0") }, .{ "main", f.n("1") }, .{ "end", f.n("4") } }) } }) },
        .{ "anchor", f.obj(&.{ .{ "kind", f.s("beforeInstruction") }, .{ "index", f.n("6") }, .{ "inSupportedBody", f.b(true) } }) },
        .{ "start", ref("1") },
        .{ "end", ref("5") },
        .{ "upperBound", f.obj(&.{ .{ "kind", f.s("sliceLength") }, .{ "original", ref("0") } }) },
        .{ "unsupportedReason", .null },
    })})),
    f.set("/body", f.arr(&.{ f.n("0"), f.n("1"), f.n("2"), f.n("3"), f.n("4"), f.n("5"), f.n("6"), f.n("7") })),
    f.set("/instructions", f.arr(&.{
        f.obj(&.{ .{ "index", f.n("0") }, .{ "tag", f.s("arg") }, .{ "payloadVisited", f.b(true) }, .{ "type", view }, .{ "zirParameterIndex", f.n("0") } }),
        f.obj(&.{ .{ "index", f.n("1") }, .{ "tag", f.s("arg") }, .{ "payloadVisited", f.b(true) }, .{ "type", size }, .{ "zirParameterIndex", f.n("1") } }),
        f.obj(&.{ .{ "index", f.n("2") }, .{ "tag", f.s("arg") }, .{ "payloadVisited", f.b(true) }, .{ "type", size }, .{ "zirParameterIndex", f.n("2") } }),
        f.obj(&.{ .{ "index", f.n("3") }, .{ "tag", f.s("slice_ptr") }, .{ "payloadVisited", f.b(true) }, .{ "type", pointer }, .{ "operand", ref("0") } }),
        f.obj(&.{ .{ "index", f.n("4") }, .{ "tag", f.s("ptr_add") }, .{ "payloadVisited", f.b(true) }, .{ "type", pointer }, .{ "lhs", ref("3") }, .{ "rhs", ref("1") } }),
        f.obj(&.{ .{ "index", f.n("5") }, .{ "tag", f.s("add") }, .{ "payloadVisited", f.b(true) }, .{ "type", size }, .{ "lhs", ref("1") }, .{ "rhs", ref("2") } }),
        f.obj(&.{ .{ "index", f.n("6") }, .{ "tag", f.s("slice") }, .{ "payloadVisited", f.b(true) }, .{ "type", view }, .{ "lhs", ref("4") }, .{ "rhs", ref("2") } }),
        f.obj(&.{ .{ "index", f.n("7") }, .{ "tag", f.s("ret") }, .{ "payloadVisited", f.b(true) }, .{ "type", f.obj(&.{.{ "kind", f.s("noreturn") }}) }, .{ "operand", ref("6") } }),
    })),
});

pub fn controls() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    const decoded = try z.air.decode(&ctx, try f.load(ctx.allocator, bounded), .memory);
    try std.testing.expect(std.mem.indexOf(u8, decoded, "(.checkBounds (.local 1) (.local 5) (.slice (.local 0)))") != null);
    for ([_]f.Value{
        f.derive(&bounded, &.{f.set("/sourceValidity/slices", f.arr(&.{}))}),
        f.derive(&bounded, &.{f.set("/instructions/5/tag", f.s("add_wrap"))}),
        f.derive(&bounded, &.{f.set("/instructions/5/rhs", ref("1"))}),
        f.derive(&bounded, &.{f.set("/instructions/4/rhs", ref("2"))}),
        f.derive(&bounded, &.{f.set("/sourceValidity/slices/0/upperBound/original", ref("6"))}),
        f.derive(&bounded, &.{f.set("/sourceValidity/slices/0/upperBound", f.obj(&.{ .{ "kind", f.s("unboundedPointer") }, .{ "requiresMemoryValidity", f.b(true) } }))}),
    }) |input| try std.testing.expectError(error.InvalidInput, z.air.decode(&ctx, try f.load(ctx.allocator, input), .memory));
}

pub fn emitted(ctx: *z.common.Context) ![]const u8 {
    const raw = try f.load(ctx.allocator, bounded);
    return ctx.fmt(
        \\import Compiler.ZigAir.Captured
        \\open Compiler.ZigAir Compiler.ZigAir.MemoryAir Compiler.ZigAir.Memory
        \\def boundedSlice : Program := {s}
        \\{s}
        \\def heap : State := ⟨[(0, ⟨1, .array 5 (.scalar (.int false 8)), [], true, false⟩)], 1, 6⟩
        \\def view : Value := .slice (.slice false (.scalar (.int false 8))) ⟨0, 0⟩ 3
        \\example : boundedSlice.run [view, .scalar (.int false 64 2), .scalar (.int false 64 1)] heap =
        \\  (.ok (.slice (.slice false (.scalar (.int false 8))) ⟨0, 2⟩ 1), heap) := rfl
        \\example : boundedSlice.run [view, .scalar (.int false 64 2), .scalar (.int false 64 2)] heap =
        \\  (.error .sourceBounds, heap) := rfl
        \\
    , .{ try z.air.decode(ctx, raw, .memory), try z.certificate.declaration(ctx, raw, "boundedSlice", false) });
}

/// Mutate one field of the bounded-slice capture or its retained evidence.
pub fn inlineSources() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const dir = try std.fs.path.resolve(ctx.allocator, &.{ ".zig-cache", "tmp", &tmp.sub_path });
    try tmp.dir.createDir(io, "air", .default_dir);
    try tmp.dir.createDir(io, "lib", .default_dir);
    const helper = "pub inline fn view(bytes: []u8, i: usize, n: usize) []u8 { return bytes[i..][0..n]; }";
    const file = "lib/helper.zig";
    const digest = z.common.digest(helper);
    const raw = try f.load(ctx.allocator, bounded);
    const guard = &raw.object.getPtr("sourceValidity").?.object.getPtr("slices").?.array.items[0];
    const source = guard.object.getPtr("source").?;
    const span = source.object.getPtr("span").?;
    const start = std.mem.indexOf(u8, helper, "bytes[i..]").?;
    span.object.getPtr("start").?.* = .{ .integer = @intCast(start) };
    span.object.getPtr("main").?.* = .{ .integer = @intCast(start + "bytes".len) };

    var hashes: z.common.Value = .{ .object = .empty };
    try hashes.object.put(ctx.allocator, "fixture.zig", try ctx.field(raw, "sourceSha256"));
    try hashes.object.put(ctx.allocator, file, .{ .string = &digest });
    const Mutation = enum { good, no_inventory, unlisted_path, wrong_digest, changed_bytes, past_end, bad_anchor };
    for (std.meta.tags(Mutation)) |mutation| {
        try tmp.dir.writeFile(io, .{ .sub_path = file, .data = if (mutation == .changed_bytes) helper ++ " " else helper });
        source.object.getPtr("file").?.* = .{ .string = if (mutation == .unlisted_path) "helper.zig" else file };
        source.object.getPtr("sha256").?.* = if (mutation == .wrong_digest) try ctx.field(raw, "sourceSha256") else .{ .string = &digest };
        span.object.getPtr("end").?.* = .{ .integer = @intCast(if (mutation == .past_end) helper.len + 1 else start + "bytes[i..][0..n]".len) };
        guard.object.getPtr("anchor").?.object.getPtr("index").?.* = .{ .integer = if (mutation == .bad_anchor) 1 else 6 };
        const bytes = try ctx.json(raw);
        try tmp.dir.writeFile(io, .{ .sub_path = "air/root.json", .data = bytes });
        var functions: z.common.Value = .{ .object = .empty };
        const root = try ctx.str(try ctx.field(raw, "name"));
        try functions.object.put(ctx.allocator, root, try ctx.parse(try ctx.json(.{ .requested = true, .file = "root.json", .sha256 = &z.common.digest(bytes) })));
        var report = try ctx.parse(try ctx.json(.{
            .schema = "oksolc.fresh-air-capture.v1",
            .status = "captured",
            .captureComplete = true,
            .zigVersion = z.version,
            .zigRevision = z.revision,
            .sourceSha256 = try ctx.field(raw, "sourceSha256"),
            .functions = functions,
        }));
        if (mutation != .no_inventory) try report.object.put(ctx.allocator, "sourceFiles", hashes);
        try tmp.dir.writeFile(io, .{ .sub_path = "report.json", .data = try ctx.json(report) });
        const options: z.translate.Options = .{ .profile = .memory, .capture = try ctx.fmt("{s}/report.json", .{dir}), .roots = &.{root}, .output = try ctx.fmt("{s}/{s}", .{ dir, @tagName(mutation) }) };
        if (mutation == .good) {
            _ = try z.translate.run(&ctx, io, options);
            const model = try ctx.read(io, try ctx.fmt("{s}/Generated.lean", .{options.output}), 65536);
            try std.testing.expect(std.mem.indexOf(u8, model, "(.checkBounds (.local 1) (.local 5) (.slice (.local 0)))") != null);
            try std.testing.expectError(error.InvalidInput, z.air.decode(&ctx, raw, .memory));
        } else {
            try std.testing.expectError(error.InvalidInput, z.translate.run(&ctx, io, options));
            try std.testing.expectError(error.FileNotFound, tmp.dir.statFile(io, @tagName(mutation), .{}));
        }
    }
}
