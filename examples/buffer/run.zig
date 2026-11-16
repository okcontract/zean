// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const buffer = @import("buffer");
const options = @import("example_options");

pub fn main() void {
    var words = [_]u32{ 10, 20, 30, 40 };
    const view = words[1..3];
    const changed = buffer.replace(view.ptr, view.len, 1, 99);
    const rejected = !buffer.replace(view.ptr, view.len, view.len, 777);
    std.debug.print("{s}: changed={any}, boundary rejected={any}, words={any}\n", .{ options.version_name, changed, rejected, words });
}
