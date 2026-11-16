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

pub fn controls() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    const raw = try record(&ctx, source);
    const selected = try z.specialized_source.select(&ctx, raw, "fixture.zig", source);
    try std.testing.expectEqualSlices(usize, &.{ 1, 2 }, selected.indices);
    var decoder = try z.air.Decoder.initWith(&ctx, raw, .memory, .{ .source_parameters = selected.indices, .explicit_type_specialization = true });
    try std.testing.expectEqualStrings((try f.load(ctx.allocator, golden.air_memory_program_2_output_30)).string, try decoder.program());
    try std.testing.expectError(error.InvalidInput, z.air.Decoder.init(&ctx, raw, .memory));
    try std.testing.expectError(error.InvalidInput, z.specialized_source.select(&ctx, raw, "other.zig", source));
    const bad_sources = [_][]const u8{
        "pub fn choose(T: type, data: [*]const T, len: usize) usize { return 0; } const Decoy = struct { " ++ source ++ " };",
        "const Decoy = struct { " ++ source ++ " };",
        "pub fn choose(comptime T: anytype, data: [*]const u8, len: usize) usize { return 0; } const Decoy = struct { " ++ source ++ " };",
        "pub fn choose(comptime T: type, noalias data: [*]const T, len: usize) usize { return 0; }",
        "pub fn choose(comptime T: type, data: [*]const T) usize { return 0; }",
    };
    for (bad_sources) |bytes| try std.testing.expectError(error.InvalidInput, z.specialized_source.select(&ctx, try record(&ctx, bytes), "fixture.zig", bytes));
    const bad_metadata = [_][]const u8{ "sourceParameterCount", "sourceComptimeBits", "sourceNoaliasBits" };
    for (bad_metadata) |field| {
        var modified = try record(&ctx, source);
        var spec = try ctx.field(modified, "specialization");
        try spec.object.put(ctx.allocator, field, .{ .integer = 2 });
        try modified.object.put(ctx.allocator, "specialization", spec);
        try std.testing.expectError(error.InvalidInput, z.specialized_source.select(&ctx, modified, "fixture.zig", source));
    }
}

pub fn emitted(ctx: *z.common.Context) ![]const u8 {
    const raw = try record(ctx, source);
    const selected = try z.specialized_source.select(ctx, raw, "fixture.zig", source);
    var decoder = try z.air.Decoder.initWith(ctx, raw, .memory, .{ .source_parameters = selected.indices, .explicit_type_specialization = true });
    return ctx.fmt("import Compiler.ZigAir.Captured\nopen Compiler.ZigAir.MemoryAir\ndef program : Program :=\n{s}\n{s}", .{ try decoder.program(), try z.certificate.declaration(ctx, raw, "program", false) });
}
