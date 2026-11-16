// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const counter = @import("counter");
const options = @import("example_options");

pub fn main(init: std.process.Init) !void {
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &.{});
    const UInt = if (options.wide) u32 else u8;
    const cap = std.math.maxInt(UInt);
    try stdout.interface.print("Counter {s} (+{d}, capped at {d})\ninput   result\n", .{ options.version_name, options.step, cap });
    for ([_]UInt{ 0, 1, cap - 3, cap - 2, cap - 1, cap }) |value| {
        try stdout.interface.print("{d:>5}   {d:>6}\n", .{ value, counter.advance(value) });
    }
}
