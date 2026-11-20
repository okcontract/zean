// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");
const protocol = @import("publication.zig");

test "the executable example is the source admitted by the AIR replay" {
    try std.testing.expectEqualStrings(z.atomic_publication.source_sha, &z.common.digest(@embedFile("publication.zig")));
}

test "publication inventories require a unique tag for the corresponding atomic operation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    const writer = try ctx.parse("[\"atomic_store\",\"ret_implicit\"]");
    const reader = try ctx.parse("[\"atomic_load\",\"ret_node\"]");
    try z.capture.validateSourceOperationTags(&ctx, writer, "atomic_store");
    try z.capture.validateSourceOperationTags(&ctx, reader, "atomic_load");
    try std.testing.expectError(error.InvalidInput, z.capture.validateSourceOperationTags(&ctx, reader, "atomic_store"));
    try std.testing.expectError(error.InvalidInput, z.capture.validateSourceOperationTags(&ctx, writer, "atomic_load"));
    for ([_][]const u8{ "[]", "[\"atomic_store\",\"atomic_store\"]", "[\"atomic_store\",\"\"]", "[\"atomic_store\",0]" }) |malformed|
        try std.testing.expectError(error.InvalidInput, z.capture.validateSourceOperationTags(&ctx, try ctx.parse(malformed), "atomic_store"));
}

test "publication replay binds the whole configuration and all three counts of each root" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    const writer =
        \\{"configuration":{"cpu":"apple_m5","cpuFeatures":[2,4]},"sourceOperationTags":["atomic_store"],
        \\ "sourceValidity":{"slices":[]},"instructions":[{"index":0,"tag":"atomic_store_release"}]}
    ;
    const reader =
        \\{"configuration":{"cpuFeatures":[2,4],"cpu":"apple_m5"},"sourceOperationTags":["atomic_load"],
        \\ "sourceValidity":{"slices":[{}]},"instructions":[{"index":0,"tag":"atomic_load"},{"index":1,"tag":"future","unsupportedPayload":true}]}
    ;
    // These fixtures exercise the capture summary before instruction semantics.
    const report =
        \\{"publication.publish":{"sourceOperationTags":["atomic_store"],"instructionCount":1,"sourceValiditySliceCount":0,"unsupportedPayloadCount":0},
        \\ "publication.readEntry":{"sourceOperationTags":["atomic_load"],"instructionCount":2,"sourceValiditySliceCount":1,"unsupportedPayloadCount":1}}
    ;
    const records = .{ try ctx.parse(writer), try ctx.parse(reader) };
    const functions = try ctx.parse(report);
    try z.atomic_publication.validateMetadata(&ctx, functions, records);
    for ([_]struct { key: []const u8, replacement: []const u8 }{
        .{ .key = "cpu", .replacement = "\"apple_m1\"" },
        .{ .key = "cpuFeatures", .replacement = "[4,2]" },
    }) |mutation| {
        var changed = try ctx.parse(writer);
        try changed.object.getPtr("configuration").?.object.put(ctx.allocator, mutation.key, try ctx.parse(mutation.replacement));
        try std.testing.expectError(error.InvalidInput, z.atomic_publication.validateMetadata(&ctx, functions, .{ changed, records[1] }));
    }
    for ([_][]const u8{ "publication.publish", "publication.readEntry" }) |root| {
        for ([_][]const u8{ "instructionCount", "sourceValiditySliceCount", "unsupportedPayloadCount" }) |field| {
            var changed = try ctx.parse(report);
            try changed.object.getPtr(root).?.object.put(ctx.allocator, field, .{ .integer = 3 });
            try std.testing.expectError(error.InvalidInput, z.atomic_publication.validateMetadata(&ctx, changed, records));
        }
    }
}

test "reader takes the early return before publication, then reads either entry" {
    var ready: u8 = 0;
    var table: [2]u8 = undefined;
    try std.testing.expectEqual(0, protocol.readEntry(&table[1], &ready));
    protocol.publish(&table[0], &table[1], &ready, 17, 42);
    try std.testing.expectEqual(17, protocol.readEntry(&table[0], &ready));
    try std.testing.expectEqual(42, protocol.readEntry(&table[1], &ready));
}

test "a concurrent reader can see zero or the published byte" {
    var ready: u8 = 0;
    var table: [2]u8 = undefined;
    const writer = try std.Thread.spawn(.{}, protocol.publish, .{ &table[0], &table[1], &ready, 17, 42 });
    const observed = protocol.readEntry(&table[1], &ready);
    writer.join();
    try std.testing.expect(observed == 0 or observed == 42);
    try std.testing.expectEqual(17, protocol.readEntry(&table[0], &ready));
}
