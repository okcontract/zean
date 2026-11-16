// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Immutable upstream exercises and explicit applications of their pinned fixes.
const std = @import("std");

pub const repository = "https://codeberg.org/ziglings/exercises";
pub const tag = "v0.17.0";
pub const commit = "f594c3f60940506a6b0c8a920e4f440a6e2962dc";
pub const compiler = "0.17.1";

pub const files = [_]struct { path: []const u8, sha256: []const u8 }{
    .{ .path = "038_structs2.zig", .sha256 = "1a38a23b89e7a6ee78005fbab11cafd7df6d368dde46ead209b0aed67443f912" },
    .{ .path = "054_manypointers.zig", .sha256 = "3c81ddd989d33165a4ec4aaeba330a11f3979a93f110f240d1a7a534f18791e9" },
    .{ .path = "038_structs2.patch", .sha256 = "ea85756850af0c1908dfccc43f64c17be52459a5eb3773584e1155fe758dbcff" },
    .{ .path = "054_manypointers.patch", .sha256 = "5a16a522b10c3f64019edddf06da971d0d35c0593c03209de4a896c657223b98" },
    .{ .path = "LICENSE", .sha256 = "f547e0129ce966ebe69721a5660a2eb0d18a5c4b895cd183e9e6040f9bb66121" },
};

pub const Exercise = enum { characters, pointers };
pub fn original(exercise: Exercise) []const u8 {
    return switch (exercise) {
        .characters => @embedFile("upstream/038_structs2.zig"),
        .pointers => @embedFile("upstream/054_manypointers.zig"),
    };
}

pub fn corrected(a: std.mem.Allocator, exercise: Exercise) ![]const u8 {
    const old = switch (exercise) {
        .characters => "    // it do and why?\n",
        .pointers => "const zen12_string: []const u8 = zen_manyptr;",
    };
    const new = switch (exercise) {
        .characters =>
        \\    // it do and why?
        \\    chars[1] = Character{
        \\        .role = Role.bard,
        \\        .gold = 10,
        \\        .health = 100,
        \\        .experience = 20,
        \\    };
        \\
        ,
        .pointers => "const zen12_string: []const u8 = zen_manyptr[0..21];",
    };
    const source = original(exercise);
    if (std.mem.count(u8, source, old) != 1) return error.ChangedUpstreamExercise;
    return std.mem.replaceOwned(u8, a, source, old, new);
}

test "vendored inputs match the immutable upstream pin" {
    inline for (files) |file| {
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(@embedFile("upstream/" ++ file.path), &digest, .{});
        try std.testing.expectEqualStrings(file.sha256, &std.fmt.bytesToHex(digest, .lower));
    }
}
