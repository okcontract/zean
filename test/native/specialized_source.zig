// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");
const f = @import("fixtures.zig");
const shared = @import("cases/shared.zig");
const golden = @import("cases/golden.zig");

const source = "pub fn choose(comptime T: type, data: [*]const T, len: usize) usize { _ = data[0..len]; return 1; }\n";
fn record(ctx: *z.common.Context, bytes: []const u8) !z.common.Value {
    var raw = try f.load(ctx.allocator, f.derive(&shared.air_memory_program_2_input_13, &.{
        f.set("/signature/genericInstance", f.b(true)),
        f.set("/name", f.s("fixture.choose__func_0")),
        f.set("/instructions/0/zirParameterIndex", f.n("1")),
        f.set("/instructions/1/zirParameterIndex", f.n("2")),
    }));
    const sha = try ctx.allocator.dupe(u8, &z.common.digest(bytes));
    try raw.object.put(ctx.allocator, "sourceSha256", .{ .string = sha });
    const validity = try ctx.field(raw, "sourceValidity");
    var guard_source = try ctx.field((try ctx.array(try ctx.field(validity, "slices")))[0], "source");
    try guard_source.object.put(ctx.allocator, "sha256", .{ .string = sha });
    // Objects share their fixture-owned backing; replace the guard explicitly.
    var guard = (try ctx.array(try ctx.field(validity, "slices")))[0];
    try guard.object.put(ctx.allocator, "source", guard_source);
    (try ctx.field(validity, "slices")).array.items[0] = guard;
    try raw.object.put(ctx.allocator, "specialization", try ctx.parse(try ctx.json(.{
        .schema = "oksolc.generic-instance.v1",
        .owner = .{ .name = "fixture.choose", .sourceFile = "fixture.zig", .sourceSha256 = sha },
        .sourceNoaliasBits = 0,
        .sourceComptimeBits = 1,
        .sourceParameterCount = 3,
        .arguments = .{
            .{ .kind = "type", .value = .{ .kind = "int", .bits = 8, .signedness = "unsigned" } },
            .{ .kind = "runtime", .runtimeIndex = 0 },
            .{ .kind = "runtime", .runtimeIndex = 1 },
        },
    })));
    return raw;
}

const mixed_source = "pub fn choose(comptime T: type, data: anytype, len: usize) usize { _ = T; _ = data; return len; }";
const implicit_source = "pub fn choose(data: anytype, len: usize) usize { _ = data; return len; }";

fn runtimeRecord(ctx: *z.common.Context, explicit_type: bool) !z.common.Value {
    var raw = try record(ctx, if (explicit_type) mixed_source else implicit_source);
    const spec = raw.object.getPtr("specialization").?;
    const args = &spec.object.getPtr("arguments").?.array;
    args.items[1].object.getPtr("kind").?.* = .{ .string = "runtimeAnytype" };
    if (!explicit_type) {
        _ = args.orderedRemove(0);
        spec.object.getPtr("sourceComptimeBits").?.* = .{ .integer = 0 };
        spec.object.getPtr("sourceParameterCount").?.* = .{ .integer = 2 };
        for (raw.object.getPtr("instructions").?.array.items[0..2], 0..) |*inst, i|
            inst.object.getPtr("zirParameterIndex").?.* = .{ .integer = @intCast(i) };
    }
    return raw;
}

fn historicalImplicit(ctx: *z.common.Context) !z.common.Value {
    var raw = try runtimeRecord(ctx, false);
    const args = &raw.object.getPtr("specialization").?.object.getPtr("arguments").?.array;
    args.items[0].object.getPtr("kind").?.* = .{ .string = "runtime" };
    return raw;
}

fn callParameters(ctx: *z.common.Context, raw: z.common.Value, bytes: []const u8) !z.specialization.Mapping {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    try tmp.dir.writeFile(io, .{ .sub_path = "fixture.zig", .data = bytes });
    try tmp.dir.writeFile(io, .{ .sub_path = "handlers.zig", .data = handler_source });
    var retained: z.declaration_source.Retained = .{ .ctx = ctx, .io = io, .directory = try tmp.dir.realPathFileAlloc(io, ".", ctx.allocator) };
    defer retained.deinit();
    const file = try retained.get("fixture.zig");
    var sources: z.common.Value = .{ .object = .empty };
    try sources.object.put(ctx.allocator, file.filename, .{ .string = &file.sha });
    try sources.object.put(ctx.allocator, "handlers.zig", .{ .string = &z.common.digest(handler_source) });
    return z.specialized_source.selectForCall(ctx, raw, .calls, file, sources, &retained);
}

fn comptimeAnytype(ctx: *z.common.Context) !z.common.Value {
    var raw = try record(ctx, "pub fn choose(comptime T: anytype, data: [*]const T, len: usize) usize { _ = data; return len; }");
    const args = &raw.object.getPtr("specialization").?.object.getPtr("arguments").?.array;
    args.items[0].object.getPtr("kind").?.* = .{ .string = "anytypeType" };
    return raw;
}

const callback_source = "fn handle(value: u8) u8 { return value; } " ++
    "pub fn choose(comptime transform: fn (u8) u8, data: [*]const u8, len: usize) usize { _ = transform; _ = data[0..len]; return 1; }";
const noncallback_source = "pub fn choose(comptime value: u8, data: [*]const u8, len: usize) usize { _ = value; _ = data[0..len]; return 1; }";
const handler_source = "pub const Handlers = struct { pub fn run(x: u8) u8 { return x; } };";

fn callbackRecord(ctx: *z.common.Context, bytes: []const u8, file: []const u8, name: []const u8) !z.common.Value {
    const raw = try record(ctx, bytes);
    const spec = try ctx.field(raw, "specialization");
    const args = try ctx.field(spec, "arguments");
    args.array.items[0] = try ctx.parse(try ctx.json(.{
        .kind = "value",
        .value = .{ .kind = "function", .identity = .{
            .name = name,
            .sourceFile = file,
            .sourceSha256 = if (std.mem.eql(u8, file, "handlers.zig")) &z.common.digest(handler_source) else try ctx.str(try ctx.field(raw, "sourceSha256")),
        } },
    }));
    return raw;
}

pub fn controls() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    const raw = try record(&ctx, source);
    const selected = try z.specialized_source.select(&ctx, raw, .memory, "fixture.zig", source);
    try std.testing.expectEqualSlices(usize, &.{ 1, 2 }, selected.indices);
    var decoder = try z.air.Decoder.initWith(&ctx, raw, .memory, .{ .source_parameters = selected.indices, .explicit_type_specialization = true });
    try std.testing.expectEqualStrings((try f.load(ctx.allocator, golden.air_memory_program_2_output_30)).string, try decoder.program());
    try std.testing.expectError(error.InvalidInput, z.air.Decoder.init(&ctx, raw, .memory));
    try std.testing.expectError(error.InvalidInput, z.specialized_source.select(&ctx, raw, .memory, "other.zig", source));
    for ([_]bool{ true, false }) |explicit_type| {
        const bytes = if (explicit_type) mixed_source else implicit_source;
        const instance = try runtimeRecord(&ctx, explicit_type);
        try std.testing.expectError(error.InvalidInput, z.specialized_source.select(&ctx, instance, .memory, "fixture.zig", bytes));
        const parameters = try callParameters(&ctx, instance, bytes);
        const indices: []const usize = if (explicit_type) &.{ 1, 2 } else &.{ 0, 1 };
        try std.testing.expectEqualSlices(usize, indices, parameters.indices);
    }
    const callback = try callbackRecord(&ctx, callback_source, "fixture.zig", "fixture.handle");
    const callback_parameters = try callParameters(&ctx, callback, callback_source);
    try std.testing.expectEqualSlices(usize, &.{ 1, 2 }, callback_parameters.indices);
    const imported = try callbackRecord(&ctx, callback_source, "handlers.zig", "handlers.Handlers.run");
    _ = try callParameters(&ctx, imported, callback_source);
    try std.testing.expectError(error.InvalidInput, z.specialized_source.select(&ctx, callback, .memory, "fixture.zig", callback_source));
    try std.testing.expectError(error.InvalidInput, callParameters(&ctx, try callbackRecord(&ctx, callback_source, "outside.zig", "fixture.handle"), callback_source));
    try std.testing.expectError(error.InvalidInput, callParameters(&ctx, try callbackRecord(&ctx, noncallback_source, "fixture.zig", "fixture.handle"), noncallback_source));
    for ([_][]const u8{ "fixture.missing", "decoy.handle", "fixture.Nested.handle" }) |name| {
        const modified = try callbackRecord(&ctx, callback_source, "fixture.zig", name);
        try std.testing.expectError(error.InvalidInput, callParameters(&ctx, modified, callback_source));
    }
    const old_implicit = try historicalImplicit(&ctx);
    _ = try callParameters(&ctx, old_implicit, implicit_source);
    try std.testing.expectError(error.InvalidInput, z.specialized_source.select(&ctx, old_implicit, .memory, "fixture.zig", implicit_source));
    const historical = try record(&ctx, mixed_source);
    _ = try callParameters(&ctx, historical, mixed_source);
    try std.testing.expectError(error.InvalidInput, z.specialized_source.select(&ctx, historical, .memory, "fixture.zig", mixed_source));
    const bad_sources = [_][]const u8{
        "pub fn choose(T: type, data: [*]const T, len: usize) usize { return 0; } const Decoy = struct { " ++ source ++ " };",
        "const Decoy = struct { " ++ source ++ " };",
        "pub fn choose(comptime T: anytype, data: [*]const u8, len: usize) usize { return 0; } const Decoy = struct { " ++ source ++ " };",
        "pub fn choose(comptime T: type, noalias data: [*]const T, len: usize) usize { return 0; }",
        "pub fn choose(comptime T: type, data: [*]const T) usize { return 0; }",
    };
    for (bad_sources) |bytes| try std.testing.expectError(error.InvalidInput, z.specialized_source.select(&ctx, try record(&ctx, bytes), .memory, "fixture.zig", bytes));
    const bad_metadata = [_][]const u8{ "sourceParameterCount", "sourceComptimeBits", "sourceNoaliasBits" };
    for (bad_metadata) |field| {
        var modified = try record(&ctx, source);
        var spec = try ctx.field(modified, "specialization");
        try spec.object.put(ctx.allocator, field, .{ .integer = 2 });
        try modified.object.put(ctx.allocator, "specialization", spec);
        try std.testing.expectError(error.InvalidInput, z.specialized_source.select(&ctx, modified, .memory, "fixture.zig", source));
    }
}

pub fn emitted(ctx: *z.common.Context) ![]const u8 {
    const raw = try record(ctx, source);
    const selected = try z.specialized_source.select(ctx, raw, .memory, "fixture.zig", source);
    var decoder = try z.air.Decoder.initWith(ctx, raw, .memory, .{ .source_parameters = selected.indices, .explicit_type_specialization = true });
    return ctx.fmt(
        \\import Compiler.ZigAir.CapturedCallMachine
        \\open Compiler.ZigAir Compiler.ZigAir.MemoryAir
        \\def program : Program :=
        \\{s}
        \\{s}
        \\def implicitInstance : Captured.Raw := {s}
        \\def mixedInstance : Captured.Raw := {s}
        \\def comptimeAnytypeInstance : Captured.Raw := {s}
        \\example : Captured.decode false comptimeAnytypeInstance = none := by rfl'
        \\example : CapturedCallMachine.decodeRecursive [comptimeAnytypeInstance] = none := by rfl'
        \\def historicalImplicitInstance : Captured.Raw := {s}
        \\example : Captured.decode false historicalImplicitInstance = none := by rfl'
        \\example : (CapturedCallMachine.decode [historicalImplicitInstance]).isSome = true := by rfl'
        \\example : Captured.decode false implicitInstance = none := by rfl'
        \\example : Captured.decode false mixedInstance = none := by rfl'
        \\example : (CapturedCallMachine.decode [implicitInstance]).isSome = true := by rfl'
        \\example : (CapturedCallMachine.decode [mixedInstance]).isSome = true := by rfl'
        \\def callbackInstance : Captured.Raw := {s}
        \\example : Captured.decode false callbackInstance = none := by rfl'
        \\example : (CapturedCallMachine.decode [callbackInstance]).isSome = true := by rfl'
        \\
    , .{ try decoder.program(), try z.certificate.declaration(ctx, raw, "program", false), try z.certificate.lift(ctx, try runtimeRecord(ctx, false), 0), try z.certificate.lift(ctx, try runtimeRecord(ctx, true), 0), try z.certificate.lift(ctx, try comptimeAnytype(ctx), 0), try z.certificate.lift(ctx, try historicalImplicit(ctx), 0), try z.certificate.lift(ctx, try callbackRecord(ctx, callback_source, "fixture.zig", "fixture.handle"), 0) });
}
