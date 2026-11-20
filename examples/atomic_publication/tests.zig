// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");
const protocol = @import("publication.zig");

test "the executable example is the source admitted by the AIR replay" {
    try std.testing.expectEqualStrings(z.atomic_publication.source_sha, &z.common.digest(@embedFile("publication.zig")));
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
