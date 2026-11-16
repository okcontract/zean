// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! One active orchestration wait per process; signal handlers only use atomics and kill.
const std = @import("std");
const builtin = @import("builtin");
pub const supported = builtin.os.tag == .macos or builtin.os.tag == .linux;
var active_group = std.atomic.Value(i32).init(0);
var interrupted = std.atomic.Value(bool).init(false);
pub const Guard = if (supported) struct {
    old_int: std.posix.Sigaction,
    old_term: std.posix.Sigaction,
    fn onSignal(_: std.posix.SIG) callconv(.c) void {
        const saved_errno = if (builtin.link_libc) std.c._errno().* else 0;
        defer if (builtin.link_libc) {
            std.c._errno().* = saved_errno;
        };
        interrupted.store(true, .seq_cst);
        const group = active_group.load(.seq_cst);
        if (group > 0) std.posix.kill(-group, .KILL) catch {};
    }
    pub fn start() !@This() {
        if (active_group.cmpxchgStrong(0, -1, .seq_cst, .seq_cst) != null) return error.ConcurrentProcessWait;
        interrupted.store(false, .seq_cst);
        var result: @This() = undefined;
        var mask = std.posix.sigemptyset();
        std.posix.sigaddset(&mask, .INT);
        std.posix.sigaddset(&mask, .TERM);
        const action: std.posix.Sigaction = .{ .handler = .{ .handler = onSignal }, .mask = mask, .flags = 0 };
        std.posix.sigaction(.INT, &action, &result.old_int);
        std.posix.sigaction(.TERM, &action, &result.old_term);
        return result;
    }
    pub fn attach(_: @This(), pid: i32) void {
        active_group.store(pid, .seq_cst);
        if (interrupted.load(.seq_cst)) std.posix.kill(-pid, .KILL) catch {};
    }
    pub fn wasInterrupted(_: @This()) bool {
        return interrupted.load(.seq_cst);
    }
    pub fn restore(self: @This()) void {
        active_group.store(0, .seq_cst);
        std.posix.sigaction(.INT, &self.old_int, null);
        std.posix.sigaction(.TERM, &self.old_term, null);
        interrupted.store(false, .seq_cst);
    }
} else struct {
    pub fn start() !@This() {
        return error.UnsupportedHost;
    }
    pub fn attach(_: @This(), _: anytype) void {}
    pub fn wasInterrupted(_: @This()) bool {
        return false;
    }
    pub fn restore(_: @This()) void {}
};
