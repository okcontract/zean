// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");

pub fn archiveNameControls() !void {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    try z.bundle_dependencies.checkArchiveNames(&ctx, &.{ "Link.dylib", "libLLVM.dylib" });
    try std.testing.expectError(error.InvalidInput, z.bundle_dependencies.checkArchiveNames(&ctx, &.{ "Link.dylib", "link.dylib" }));
    try std.testing.expectEqualStrings("native library names Link.dylib and link.dylib collide in the standalone bundle", ctx.diagnostic);
    if (@import("builtin").target.os.tag == .macos) {
        try std.testing.expectError(error.InvalidInput, z.bundle_dependencies.checkArchiveNames(&ctx, &.{ "Café.dylib", "cafe\u{0301}.dylib" }));
    }
}

pub fn elfControls() !void {
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    var buffer: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const directory = buffer[0..try tmp.dir.realPath(io, &buffer)];
    const executable = try ctx.fmt("{s}/compiler", .{directory});
    const host = try std.zig.system.resolveTargetQuery(io, .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu });

    const baseline = executableHeader();
    try tmp.dir.writeFile(io, .{ .sub_path = "compiler", .data = &baseline });
    try std.testing.expect(!try z.bundle_dependencies.elfIsDynamic(&ctx, io, executable, host));

    var dynamic = baseline;
    std.mem.writeInt(u32, dynamic[64..68], 3, .little); // PT_INTERP
    try tmp.dir.writeFile(io, .{ .sub_path = "compiler", .data = &dynamic });
    try std.testing.expect(try z.bundle_dependencies.elfIsDynamic(&ctx, io, executable, host));

    var foreign = baseline;
    std.mem.writeInt(u16, foreign[18..20], 183, .little); // EM_AARCH64
    try tmp.dir.writeFile(io, .{ .sub_path = "compiler", .data = &foreign });
    try std.testing.expectError(error.InvalidInput, z.bundle_dependencies.elfIsDynamic(&ctx, io, executable, host));
    try std.testing.expectEqualStrings("compiler ELF architecture does not match the packaging host", ctx.diagnostic);
}

fn executableHeader() [120]u8 {
    // ELF64 header followed by a single PT_LOAD program header.
    var bytes: [120]u8 = @splat(0);
    @memcpy(bytes[0..7], "\x7fELF\x02\x01\x01");
    std.mem.writeInt(u16, bytes[16..18], 2, .little); // ET_EXEC
    std.mem.writeInt(u16, bytes[18..20], 62, .little); // EM_X86_64
    std.mem.writeInt(u32, bytes[20..24], 1, .little);
    std.mem.writeInt(u64, bytes[32..40], 64, .little);
    std.mem.writeInt(u16, bytes[52..54], 64, .little);
    std.mem.writeInt(u16, bytes[54..56], 56, .little);
    std.mem.writeInt(u16, bytes[56..58], 1, .little);
    std.mem.writeInt(u32, bytes[64..68], 1, .little); // PT_LOAD
    return bytes;
}
