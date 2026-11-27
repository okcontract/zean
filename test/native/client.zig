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
    for ([_][]const u8{ "calls", "call-loops", "nested-calls", "recursive-calls" }) |profile| {
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
    var dependent = try ctx.parse(try ctx.json(baseline));
    try dependent.object.put(ctx.allocator, "dependencies", try ctx.parse("[\"proofs/other.json\"]"));
    const parsed = try z.client.parse(&ctx, dependent);
    try std.testing.expectEqualStrings("proofs/other.json", parsed.dependencies[0]);
    for ([_][]const u8{ "[\"../outside.json\"]", "[\"proofs/other.json\",\"proofs/other.json\"]" }) |invalid| {
        try dependent.object.put(ctx.allocator, "dependencies", try ctx.parse(invalid));
        try std.testing.expectError(error.InvalidInput, z.client.parse(&ctx, dependent));
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
    try std.testing.expectEqualStrings("proof import Cell.Later is undeclared or has not been checked yet", ctx.diagnostic);
    try dependencyImports(&ctx, parsed);
}

fn dependencyImports(ctx: *z.common.Context, baseline: z.client.Manifest) !void {
    const words = "import Compiler.ZigAir.Verify.Words\n";
    var a: z.client.ReplayInput = .{ .path = "a.json", .manifest = baseline, .generated = "", .proofs = &.{words} };
    a.manifest.dependencies = &.{};
    a.manifest.generated = "A.Generated";
    a.manifest.proofs = &.{.{ .module = "Shared.Proof", .path = "Shared.lean" }};
    var b = a;
    b.path = "b.json";
    b.manifest.generated = "B.Generated";
    b.manifest.libraries = &.{};
    b.manifest.proofs = &.{.{ .module = "B.Proof", .path = "B.lean" }};
    var root = b;
    root.path = "root.json";
    root.manifest.generated = "Root.Generated";
    root.manifest.dependencies = &.{ a.path, b.path };
    root.manifest.proofs = &.{.{ .module = "Root.Proof", .path = "Root.lean" }};
    root.manifest.theorems = &.{"Root.safe"};
    root.proofs = &.{"import A.Generated\nimport B.Generated\nimport Shared.Proof\n"};
    for ([_][]const u8{ "import A.Generated\n", "import Shared.Proof\n", words }) |unavailable| {
        b.proofs = &.{unavailable};
        try std.testing.expectError(error.InvalidInput, z.client.planProofs(ctx, &.{ a, b, root }, "Test"));
        try std.testing.expectError(error.InvalidInput, z.client.planProofs(ctx, &.{ b, a, root }, "Test"));
    }
    // Even identical proof bytes must resolve again before reusing A's module.
    b.manifest.proofs = a.manifest.proofs;
    b.proofs = a.proofs;
    try std.testing.expectError(error.InvalidInput, z.client.planProofs(ctx, &.{ a, b, root }, "Test"));
    b.manifest.libraries = a.manifest.libraries;
    const shared = try z.client.planProofs(ctx, &.{ a, b, root }, "Test");
    try std.testing.expectEqual(5, shared.modules.len);
    try std.testing.expectEqualStrings("import Test_0\nimport Test_2\nimport Test_1\n", shared.modules[4].body);
    try std.testing.expectEqual(3, shared.obligations.len);
    try std.testing.expectEqualStrings("(#[\"Cell.safe\"], #[\"Test_1\"])", shared.obligations[0]);
    try std.testing.expectEqualStrings(shared.obligations[0], shared.obligations[1]);
    try std.testing.expectEqualStrings("(#[\"Root.safe\"], #[\"Test_4\"])", shared.obligations[2]);

    b.manifest.dependencies = &.{a.path};
    b.manifest.proofs = &.{ .{ .module = "B.First", .path = "First.lean" }, .{ .module = "B.Second", .path = "Second.lean" } };
    b.proofs = &.{ "import Shared.Proof\n", "import B.First\n" };
    root.manifest.dependencies = &.{b.path};
    const transitive = try z.client.planProofs(ctx, &.{ a, b, root }, "Test");
    try std.testing.expectEqualStrings("import Test_0\nimport Test_2\nimport Test_1\n", transitive.modules[6].body);
    b.proofs = &.{ "import B.Second\n", "import Shared.Proof\n" };
    try std.testing.expectError(error.InvalidInput, z.client.planProofs(ctx, &.{ a, b, root }, "Test"));
}
