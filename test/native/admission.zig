// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");

pub fn controls() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    for ([_][]const u8{ "call_always_tail", "atomic_load", "atomic_store_release", "atomic_rmw", "cmpxchg_weak", "memmove", "struct_field_ptr_index_4", "ret_safe_extra", "", "add sub" }) |tag|
        try std.testing.expectError(error.InvalidInput, z.admission.require(&ctx, tag));
    try std.testing.expectEqual(z.admission.Origin.source_and_air, z.admission.lookup("slice").?.origin);
    try std.testing.expectEqual(z.admission.Origin.air, z.admission.lookup("memcpy").?.origin);
    var seen: std.StringHashMap(void) = .init(arena.allocator());
    for (z.admission.operations) |operation| {
        var tags = std.mem.tokenizeScalar(u8, operation.tags, ' ');
        while (tags.next()) |tag| {
            try std.testing.expect(!(try seen.getOrPut(tag)).found_existing);
            try z.admission.require(&ctx, tag);
        }
        try std.testing.expect(operation.obligations.len > 0 and operation.interpretation.len > 0);
        _ = try ctx.read(std.testing.io, operation.controls, 1024 * 1024);
    }
    const report = try z.admission.report(&ctx);
    try std.testing.expect(z.common.flag(report, "sourceRequirementsComplete", false));
    try std.testing.expect(z.common.flag(report, "sourceSafetyVerified", false));
    const configuration = .{ .arch = "aarch64", .os = "macos", .pointerBits = 64, .endianness = "little", .optimize = "ReleaseFast", .useLlvm = true, .isTest = false };
    try std.testing.expectEqual(z.target.Model.aarch64_macos_le64, try z.target.admit(&ctx, try ctx.parse(try ctx.json(configuration)), true));
    for ([_]struct { field: []const u8, value: z.common.Value }{
        .{ .field = "arch", .value = .{ .string = "x86_64" } },
        .{ .field = "os", .value = .{ .string = "linux" } },
        .{ .field = "pointerBits", .value = .{ .integer = 32 } },
        .{ .field = "endianness", .value = .{ .string = "big" } },
        .{ .field = "optimize", .value = .{ .string = "Debug" } },
        .{ .field = "useLlvm", .value = .{ .bool = false } },
        .{ .field = "isTest", .value = .{ .bool = true } },
    }) |mutation| {
        var changed = try ctx.parse(try ctx.json(configuration));
        try changed.object.put(ctx.allocator, mutation.field, mutation.value);
        try std.testing.expectError(error.InvalidInput, z.target.admit(&ctx, changed, true));
    }
    for ([_]struct { name: []const u8, loops: bool, calls: bool, bytes: bool, certificate: bool }{
        .{ .name = "scalar", .loops = false, .calls = false, .bytes = false, .certificate = true },
        .{ .name = "memory", .loops = false, .calls = false, .bytes = false, .certificate = true },
        .{ .name = "loops", .loops = true, .calls = false, .bytes = false, .certificate = true },
        .{ .name = "aggregate", .loops = false, .calls = false, .bytes = false, .certificate = false },
        .{ .name = "word-bytes", .loops = false, .calls = false, .bytes = true, .certificate = false },
        .{ .name = "word-byte-loops", .loops = true, .calls = false, .bytes = true, .certificate = false },
        .{ .name = "calls", .loops = false, .calls = true, .bytes = false, .certificate = true },
        .{ .name = "call-loops", .loops = true, .calls = true, .bytes = false, .certificate = true },
        .{ .name = "nested-calls", .loops = true, .calls = true, .bytes = false, .certificate = true },
        .{ .name = "recursive-calls", .loops = true, .calls = true, .bytes = false, .certificate = true },
    }) |expected| {
        const profile = z.air.Profile.parse(expected.name).?;
        try std.testing.expectEqual(expected.loops, profile.hasLoops());
        try std.testing.expectEqual(expected.calls, profile.hasCalls());
        const graph = if (std.mem.eql(u8, expected.name, "recursive-calls")) "recursive" else if (expected.calls) "acyclic" else "unsupported";
        try std.testing.expect(z.common.tag(try ctx.field(report, "directCallGraphs"), expected.name, graph));
        try std.testing.expectEqual(expected.bytes, profile.hasBytes());
        try std.testing.expectEqual(expected.certificate, profile.capabilities().correspondence);
        try std.testing.expectEqual(std.mem.eql(u8, expected.name, "recursive-calls"), profile.capabilities().recursive_calls);
    }
    try std.testing.expect(z.air.Profile.parse("calls+bytes") == null);
}
