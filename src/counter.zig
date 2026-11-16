// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const c = @import("common.zig");
const tutorial = @import("tutorial.zig");
pub const Options = tutorial.Options;

pub fn run(ctx: *c.Context, io: std.Io, options: Options, environment: *const std.process.Environ.Map) !c.Value {
    return tutorial.run(ctx, io, .counter, options, environment);
}
pub fn replayBody(ctx: *c.Context, text: []const u8) ![]const u8 {
    return tutorial.replayBody(ctx, .counter, text);
}
pub fn compareRetained(ctx: *c.Context, retained: []const u8, fresh: []const u8) !void {
    return tutorial.compareRetained(ctx, .counter, retained, fresh);
}
