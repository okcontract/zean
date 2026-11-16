// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const kernels = @import("kernels");
const z = @import("zean");

test "038 initializes both slots before either selected read" {
    for ([_]usize{ 0, 1 }) |index| {
        var gold = [_]u32{ 101, undefined, undefined, 103 };
        const result = kernels.initialize_pair(gold[1..].ptr, 20, 10, index);
        try std.testing.expectEqual(([_]u32{ 20, 10 })[index], result);
        try std.testing.expectEqualSlices(u32, &.{ 101, 20, 10, 103 }, &gold);
    }
}

test "054 reads initialized bytes and handles out-of-range indices" {
    const phrase = "Memory is a resource.";
    try std.testing.expectEqual(@as(u8, 'M'), kernels.phrase_byte(phrase, 21, 0));
    try std.testing.expectEqual(@as(u8, '.'), kernels.phrase_byte(phrase, 21, 20));
    try std.testing.expectEqual(@as(u8, 0), kernels.phrase_byte(phrase, 21, 21));
    try std.testing.expectEqual(@as(u8, 0), kernels.phrase_byte(phrase, 0, 0));
    const binary = [_]u8{ 0, 255, 127 };
    try std.testing.expectEqual(@as(u8, 255), kernels.phrase_byte(&binary, 3, 1));
}

test "captured kernels identify the current source bytes" {
    const a = std.testing.allocator;
    const source_path = try std.fs.path.join(a, &.{ z.project_root, "examples/ziglings/ziglings.zig" });
    defer a.free(source_path);
    const source = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, source_path, a, .limited(65536));
    defer a.free(source);
    const generated_path = try std.fs.path.join(a, &.{ z.project_root, "lean/Compiler/Tutorial/Ziglings/Generated.lean" });
    defer a.free(generated_path);
    const generated = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, generated_path, a, .limited(65536));
    defer a.free(generated);
    const marker = try std.fmt.allocPrint(a, "-- Source SHA-256: {s}\n", .{&z.common.digest(source)});
    defer a.free(marker);
    try std.testing.expect(std.mem.indexOf(u8, generated, marker) != null);
}
