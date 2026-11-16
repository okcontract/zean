// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");

pub fn controls() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    const baseline = .{ .schema = "zean.client.v1", .source = "cell.zig", .sources = .{}, .roots = .{"cell.put"}, .profile = "memory", .generatedModule = "Cell.Generated", .libraries = .{"Compiler.ZigAir.Verify.Words"}, .proofs = .{.{ .module = "Cell.Proofs", .path = "Proofs.lean" }}, .theorems = .{"Cell.safe"} };
    try std.testing.expect(!(try z.client.parse(&ctx, try ctx.parse(try ctx.json(baseline)))).call_machine);
    var scalar = try ctx.parse(try ctx.json(baseline));
    try scalar.object.put(ctx.allocator, "profile", .{ .string = "scalar" });
    try std.testing.expect(!(try z.client.parse(&ctx, scalar)).call_machine);
    for ([_][]const u8{ "calls", "call-loops", "nested-calls" }) |profile| {
        var value = try ctx.parse(try ctx.json(baseline));
        try value.object.put(ctx.allocator, "profile", .{ .string = profile });
        try std.testing.expect((try z.client.parse(&ctx, value)).call_machine);
        try value.object.put(ctx.allocator, "executionModel", .{ .string = "call-machine" });
        try std.testing.expect((try z.client.parse(&ctx, value)).call_machine);
        for ([_]z.common.Value{ .{ .string = "opaque" }, .{ .bool = true }, .null }) |invalid| {
            try value.object.put(ctx.allocator, "executionModel", invalid);
            try std.testing.expectError(error.InvalidInput, z.client.parse(&ctx, value));
        }
    }
    for ([_]struct { key: []const u8, value: []const u8 }{
        .{ .key = "source", .value = "../cell.zig" },
        .{ .key = "source", .value = "/tmp/cell.zig" },
        .{ .key = "source", .value = "src//cell.zig" },
        .{ .key = "profile", .value = "aggregate" },
        .{ .key = "profile", .value = "memory+calls" },
        .{ .key = "executionModel", .value = "call-machine" },
        .{ .key = "generatedModule", .value = "Compiler.ZigAir.Verify.Words" },
        .{ .key = "schema", .value = "zean.client.v2" },
    }) |mutation| {
        var value = try ctx.parse(try ctx.json(baseline));
        try value.object.put(ctx.allocator, mutation.key, .{ .string = mutation.value });
        try std.testing.expectError(error.InvalidInput, z.client.parse(&ctx, value));
    }
    const source = "/- header /- nested -/ -/\n import Cell.Generated\nimport Compiler.ZigAir.Verify.Words -- framework\n\nnamespace Cell\ntheorem safe : True := True.intro\nend Cell\n";
    const replayed = try z.proof_replay.replay(&ctx, source, &.{"Compiler.ZigAir.Verify.Words"}, &.{.{ .original = "Cell.Generated", .fresh = "Fresh_0" }});
    try std.testing.expectEqualStrings("import Fresh_0\nimport Compiler.ZigAir.Verify.Words\nnamespace Cell\ntheorem safe : True := True.intro\nend Cell\n", replayed);
    for ([_][]const u8{
        "import Cell.Retained\nexample : True := True.intro",
        "import Cell.Generated Cell.Retained\n",
        "module\npublic import Cell.Retained\n",
        "prelude\nimport Cell.Generated\n",
        "public import Cell.Retained\n",
        "/- unterminated",
    }) |bad| try std.testing.expectError(error.InvalidInput, z.proof_replay.replay(&ctx, bad, &.{}, &.{.{ .original = "Cell.Generated", .fresh = "Fresh_0" }}));
    try std.testing.expectError(error.InvalidInput, z.proof_replay.replay(&ctx, "import Cell.Later\n", &.{}, &.{}));
}
