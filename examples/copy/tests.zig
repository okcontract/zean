// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const copy = @import("copy");
const z = @import("zean");

test "copy initializes the destination and preserves source and neighbors" {
    const source = [_]u32{ 0, 17, 0xffffffff };
    var target = [_]u32{ 101, undefined, undefined, undefined, 103 };
    copy.copy(target[1..].ptr, &source, source.len);
    try std.testing.expectEqualSlices(u32, &.{ 101, 0, 17, 0xffffffff, 103 }, &target);
    try std.testing.expectEqualSlices(u32, &.{ 0, 17, 0xffffffff }, &source);
}

test "disjoint views in one allocation and empty copies" {
    var words = [_]u32{ 11, 23, 37, 41, 53, 67, 79, 83 };
    copy.copy(words[4..].ptr, words[1..].ptr, 2);
    try std.testing.expectEqualSlices(u32, &.{ 11, 23, 37, 41, 23, 37, 79, 83 }, &words);
    copy.copy(words[words.len..].ptr, words[words.len..].ptr, 0);
    try std.testing.expectEqualSlices(u32, &.{ 11, 23, 37, 41, 23, 37, 79, 83 }, &words);
}

test "single word helper reads before writing an alias" {
    var value: u32 = 0xffffffff;
    copy.copy_word(&value, &value);
    try std.testing.expectEqual(@as(u32, 0xffffffff), value);
    const source: u32 = 7;
    copy.copy_word(&value, &source);
    try std.testing.expectEqual(@as(u32, 7), value);
}

test "copy capture identifies the current source bytes" {
    const allocator = std.testing.allocator;
    const source_path = try std.fs.path.join(allocator, &.{ z.project_root, "examples/copy/copy.zig" });
    defer allocator.free(source_path);
    const source = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, source_path, allocator, .limited(4096));
    defer allocator.free(source);
    const generated_path = try std.fs.path.join(allocator, &.{ z.project_root, "lean/Compiler/Tutorial/Copy/Generated.lean" });
    defer allocator.free(generated_path);
    const generated = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, generated_path, allocator, .limited(65536));
    defer allocator.free(generated);
    const marker = try std.fmt.allocPrint(allocator, "-- Source SHA-256: {s}\n", .{&z.common.digest(source)});
    defer allocator.free(marker);
    if (std.mem.indexOf(u8, generated, marker) == null) return error.StaleCopyTranslation;
}
