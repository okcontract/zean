// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");

pub fn ziglingsControls() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    const source = "-- Source SHA-256: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n";
    const names = [_][]const u8{ "initialize_pair", "missing_character", "phrase_byte", "exaggerated_byte" };
    var parts: std.ArrayList([]const u8) = .empty;
    try parts.append(ctx.allocator, source);
    for (names) |name| try parts.append(ctx.allocator, try ctx.fmt("def fn_{s} : Program :=\n  original_{s}\n", .{ name, name }));
    const baseline = try std.mem.concat(ctx.allocator, u8, parts.items);
    try z.tutorial.compareRetained(&ctx, .ziglings, baseline, baseline);
    for (names) |name| {
        const changed = try std.mem.replaceOwned(u8, ctx.allocator, baseline, try ctx.fmt("original_{s}", .{name}), "changed");
        try std.testing.expectError(error.InvalidInput, z.tutorial.compareRetained(&ctx, .ziglings, baseline, changed));
    }
    const stale = try std.mem.replaceOwned(u8, ctx.allocator, baseline, source, "-- Source SHA-256: bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n");
    try std.testing.expectError(error.InvalidInput, z.tutorial.compareRetained(&ctx, .ziglings, baseline, stale));
    try std.testing.expectEqualStrings("def witness := 1\n\n", try z.tutorial.replayBody(&ctx, .ziglings, "import Compiler.Tutorial.Ziglings.Generated\nimport Compiler.Tutorial.Ziglings.Bounds\nimport Compiler.ZigAir.Verify.Reads\ndef witness := 1\n"));
    try std.testing.expectError(error.InvalidInput, z.tutorial.replayBody(&ctx, .ziglings, "import Compiler.Tutorial.Buffer.Verification\n"));
    try std.testing.expectError(error.InvalidInput, z.tutorial.replayBody(&ctx, .ziglings, "import Compiler.Tutorial.Ziglings.Unchecked\n"));
}

pub fn controls() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    const source = "-- Source SHA-256: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n";
    const program = "def fn_advance : Program :=\n  original\nend Example\n";
    try z.counter.compareRetained(&ctx, source ++ "-- Capture report SHA-256: old\n" ++ program, source ++ "-- Capture report SHA-256: new\n" ++ program);
    try std.testing.expectError(error.InvalidInput, z.counter.compareRetained(&ctx, source ++ program, "-- Source SHA-256: bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n" ++ program));
    try std.testing.expectError(error.InvalidInput, z.counter.compareRetained(&ctx, source ++ program, source ++ "def fn_advance : Program :=\n  changed\nend Example\n"));
    try std.testing.expectError(error.InvalidInput, z.counter.compareRetained(&ctx, "missing identity", source ++ program));
    try std.testing.expectEqualStrings("def witness := 1\n\n", try z.counter.replayBody(&ctx, "import Compiler.Tutorial.Counter.V2.Generated\ndef witness := 1\n"));
    try std.testing.expectError(error.InvalidInput, z.counter.replayBody(&ctx, "import Compiler.Tutorial.Counter.Other\n"));
    try std.testing.expectError(error.InvalidInput, z.counter.replayBody(&ctx, "import Unrelated.Axioms\n"));
    const bundle = source ++ "def fn_copy : Program :=\n  original\nend Example\n";
    try z.proof_replay.compareBundle(&ctx, bundle, bundle, "def fn_copy : Program :=\n");
    try std.testing.expectError(error.InvalidInput, z.proof_replay.compareBundle(&ctx, bundle, source ++ "def fn_copy : Program :=\n  changed\nend Example\n", "def fn_copy : Program :=\n"));
    const generic = &.{ "Compiler.ZigAir.Verify.Bytes", "Compiler.ZigAir.MemoryByteWriteAutomation" };
    const dependencies = &.{z.proof_replay.Import{ .original = "Client.Generated", .fresh = "FreshCaptured_Part0" }};
    // An available optional domain must not be injected into a client's proof
    // environment. Only its original generic import and fresh model are used.
    try std.testing.expectEqualStrings("import Compiler.ZigAir.Verify.Bytes\nimport FreshCaptured_Part0\n", try z.proof_replay.imports(&ctx, &.{ "Compiler.ZigAir.Verify.Bytes", "Client.Generated" }, generic, dependencies));
    try std.testing.expectError(error.InvalidInput, z.proof_replay.imports(&ctx, &.{"Client.Generated"}, generic, &.{}));
    try std.testing.expectError(error.InvalidInput, z.proof_replay.imports(&ctx, &.{"Client.Contracts"}, generic, dependencies));
    try std.testing.expectError(error.InvalidInput, z.proof_replay.imports(&ctx, &.{"Unrelated.Axioms"}, generic, dependencies));
}

pub fn bufferControls() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    const source = "-- Source SHA-256: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n";
    const program = "def fn_replace : Program :=\n  original\nend Example\n";
    try z.buffer.compareRetained(&ctx, source ++ "-- Capture report SHA-256: old\n" ++ program, source ++ "-- Capture report SHA-256: new\n" ++ program);
    try std.testing.expectError(error.InvalidInput, z.buffer.compareRetained(&ctx, source ++ program, source ++ "def fn_replace : Program :=\n  changed\nend Example\n"));
    try std.testing.expectError(error.InvalidInput, z.buffer.compareRetained(&ctx, source ++ program, "-- Source SHA-256: bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n" ++ program));
    try std.testing.expectError(error.InvalidInput, z.buffer.compareRetained(&ctx, source ++ program, source ++ "def fn_advance : Program :=\n  original\nend Example\n"));
    try std.testing.expectEqualStrings("def witness := 1\n\n", try z.buffer.replayBody(&ctx, "import Compiler.Tutorial.Buffer.V2.Generated\nimport Compiler.Tutorial.Buffer.Inputs\nimport Compiler.Tutorial.Buffer.Contracts\nimport Compiler.Tutorial.Buffer.Verification\nimport Compiler.Tutorial.Buffer.Proofs\nimport Compiler.Tutorial.Buffer.Broken.Proofs\ndef witness := 1\n"));
    try std.testing.expectError(error.InvalidInput, z.buffer.replayBody(&ctx, "import Compiler.Tutorial.Buffer.Execution\n"));
    try std.testing.expectError(error.InvalidInput, z.buffer.replayBody(&ctx, "import Compiler.Baselines.BufferExecution\n"));
    try std.testing.expectError(error.InvalidInput, z.buffer.replayBody(&ctx, "import Compiler.Tutorial.Buffer.Other\n"));
    try std.testing.expectError(error.InvalidInput, z.buffer.replayBody(&ctx, "import Compiler.Tutorial.Counter.V2.Generated\n"));
    try std.testing.expectError(error.InvalidInput, z.counter.replayBody(&ctx, "import Compiler.Tutorial.Buffer.V2.Generated\n"));
    try std.testing.expectError(error.InvalidInput, z.buffer.replayBody(&ctx, "import Unrelated.Axioms\n"));
}

pub fn copyControls() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    const source = "-- Source SHA-256: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n";
    const first = "def fn_copy : Program true :=\n  loop\n";
    const second = "def fn_copy_word : Program true :=\n  helper\nend Example\n";
    const original = source ++ first ++ "-- AIR SHA-256: old\n" ++ second;
    try z.tutorial.compareRetained(&ctx, .copy, original, source ++ first ++ "-- AIR SHA-256: fresh\n" ++ second);
    try std.testing.expectError(error.InvalidInput, z.tutorial.compareRetained(&ctx, .copy, original, source ++ first ++ "def fn_copy_word : Program true :=\n  changed\nend Example\n"));
    try std.testing.expectError(error.InvalidInput, z.tutorial.compareRetained(&ctx, .copy, original, source ++ first));
    try std.testing.expectError(error.InvalidInput, z.tutorial.compareRetained(&ctx, .copy, original, source ++ "def fn_copy : Program true :=\n  changed\n" ++ second));
    try std.testing.expectEqualStrings("def witness := 1\n\n", try z.tutorial.replayBody(&ctx, .copy, "import Compiler.Tutorial.Copy.Generated\nimport Compiler.Tutorial.Copy.Contracts\nimport Compiler.Tutorial.Copy.Verification\ndef witness := 1\n"));
    try std.testing.expectError(error.InvalidInput, z.tutorial.replayBody(&ctx, .copy, "import Compiler.Tutorial.Buffer.Verification\n"));
    try std.testing.expectError(error.InvalidInput, z.tutorial.replayBody(&ctx, .copy, "import Unrelated.Axioms\n"));
}

pub fn callControls() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    const source = "-- Source SHA-256: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n";
    const helper = "def FunctionId.fn_inside : Nat := 0\ndef fn_inside : Function :=\n  helper\n";
    const caller = "def fn_update : Program :=\n  caller\nend Example\n";
    const original = source ++ helper ++ "-- AIR SHA-256: old\n" ++ caller;
    try z.tutorial.compareRetained(&ctx, .calls, original, source ++ helper ++ "-- AIR SHA-256: fresh\n" ++ caller);
    try std.testing.expectError(error.InvalidInput, z.tutorial.compareRetained(&ctx, .calls, original, source ++ helper));
    try std.testing.expectError(error.InvalidInput, z.tutorial.compareRetained(&ctx, .calls, original, source ++ helper ++ "def fn_update : Program :=\n changed\nend Example\n"));
    try std.testing.expectEqualStrings("def witness := 1\n\n", try z.tutorial.replayBody(&ctx, .calls, "import Compiler.Tutorial.Calls.Generated\nimport Compiler.ZigAir.Verify.Machine\ndef witness := 1\n"));
    try std.testing.expectError(error.InvalidInput, z.tutorial.replayBody(&ctx, .calls, "import Compiler.Tutorial.Buffer.Verification\n"));
    try std.testing.expectError(error.InvalidInput, z.tutorial.replayBody(&ctx, .calls, "import Compiler.Tutorial.Calls.Other\n"));
}

pub fn componentControls() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    const source = "-- Source SHA-256: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n";
    const program = "def fn_replaceScalar__func_0 : Program true :=\n  original\nend Example\n";
    try z.tutorial.compareRetained(&ctx, .stdlib_replace, source ++ program, source ++ "-- AIR SHA-256: fresh\n" ++ program);
    try std.testing.expectError(error.InvalidInput, z.tutorial.compareRetained(&ctx, .stdlib_replace, source ++ program, source ++ "def fn_replaceScalar__func_0 : Program true :=\n changed\nend Example\n"));
    try std.testing.expectError(error.InvalidInput, z.tutorial.compareRetained(&ctx, .stdlib_replace, source ++ program, "-- Source SHA-256: bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n" ++ program));
    try std.testing.expectEqualStrings("def witness := 1\n\n", try z.tutorial.replayBody(&ctx, .stdlib_replace, "import Compiler.Components.Replace.Generated\nimport Compiler.Components.Replace.Controls\nimport Compiler.ZigAir.MemoryInitializedWords\ndef witness := 1\n"));
    try std.testing.expectError(error.InvalidInput, z.tutorial.replayBody(&ctx, .stdlib_replace, "import Compiler.Tutorial.Copy.Verification\n"));
    try std.testing.expectError(error.InvalidInput, z.tutorial.replayBody(&ctx, .stdlib_replace, "import Compiler.Components.Replace.Other\n"));
}
