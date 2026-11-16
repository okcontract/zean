// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");
const options = @import("example_options");

test "generated buffer module identifies the current Zig source bytes" {
    const allocator = std.testing.allocator;
    const source_path = try std.fs.path.join(allocator, &.{ z.project_root, options.source_path });
    defer allocator.free(source_path);
    const source = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, source_path, allocator, .limited(4096));
    defer allocator.free(source);
    const generated_path = try std.fs.path.join(allocator, &.{ z.project_root, options.generated_path });
    defer allocator.free(generated_path);
    const generated = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, generated_path, allocator, .limited(65536));
    defer allocator.free(generated);
    const marker = try std.fmt.allocPrint(allocator, "-- Source SHA-256: {s}\n", .{&z.common.digest(source)});
    defer allocator.free(marker);
    if (std.mem.indexOf(u8, generated, marker) == null) return error.StaleBufferTranslation;
}
