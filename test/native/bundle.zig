// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");
const builtin = @import("builtin");

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

fn link(ctx: *z.common.Context, dir: std.Io.Dir, args: []const []const u8) !void {
    const argv = try std.mem.concat(ctx.allocator, []const u8, &.{ &.{@import("test_options").zig}, args });
    const result = try std.process.run(ctx.allocator, std.testing.io, .{ .argv = argv, .cwd = .{ .dir = dir } });
    if (result.term != .exited or result.term.exited != 0) {
        std.debug.print("fixture link failed: {s}\n", .{result.stderr});
        return error.TestUnexpectedResult;
    }
}

pub fn elfSearchPaths() !void {
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    const native_linux = builtin.target.os.tag == .linux;
    const target = if (native_linux) "native" else "x86_64-linux-gnu";
    const host = if (native_linux) builtin.target else try std.zig.system.resolveTargetQuery(io, .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu });
    try tmp.dir.createDir(io, "original", .default_dir);
    try tmp.dir.createDir(io, "libraries", .default_dir);
    var buffer: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const directory = buffer[0..try tmp.dir.realPath(io, &buffer)];
    const original = try ctx.fmt("{s}/original", .{directory});
    const library = try ctx.fmt("{s}/libfixture.so", .{original});
    const compiler = try ctx.fmt("{s}/compiler", .{directory});

    try tmp.dir.writeFile(io, .{ .sub_path = "library.zig", .data =
        \\export fn version() [*:0]const u8 { return "original"; }
    });
    const library_args = [_][]const u8{ "build-lib", "library.zig", "-target", target, "-Osmall", "-dynamic", "--name", "fixture" };
    try link(&ctx, tmp.dir, &(library_args ++ .{ "-flld", "-rpath", original, "--disable-new-dtags", "-femit-bin=original/libfixture.so" }));
    try tmp.dir.writeFile(io, .{ .sub_path = "library.zig", .data =
        \\export fn version() [*:0]const u8 { return "0.17.1"; }
    });
    try link(&ctx, tmp.dir, &(library_args ++ .{"-femit-bin=libraries/libfixture.so"}));
    try tmp.dir.writeFile(io, .{ .sub_path = "compiler.zig", .data =
        \\const std = @import("std");
        \\extern fn version() [*:0]const u8;
        \\pub fn main() void {
        \\    const text = std.mem.span(version());
        \\    _ = std.os.linux.write(1, text.ptr, text.len);
        \\}
    });
    try link(&ctx, tmp.dir, &.{ "build-obj", "compiler.zig", "-target", target, "-Osmall", "-fPIC", "-fsingle-threaded", "-fcompiler-rt", "-femit-bin=compiler.o" });

    const flags = [_][]const u8{ "--disable-new-dtags", "--enable-new-dtags" };
    for (flags, [_][]const u8{ compiler, library }) |flag, rejected| {
        try link(&ctx, tmp.dir, &.{ "ld.lld", flag, "-rpath", original, "--dynamic-linker", host.dynamic_linker.get().?, "compiler.o", "libraries/libfixture.so", "-o", "compiler" });
        if (native_linux) {
            try std.testing.expectError(error.InvalidInput, z.bundle_dependencies.collect(&ctx, io, compiler, "0.17.1"));
        } else {
            try std.testing.expectError(error.InvalidInput, z.bundle_dependencies.elfIsDynamic(&ctx, io, rejected, host));
        }
        try std.testing.expectEqualStrings(try ctx.fmt("ELF DT_RPATH in {s} can override bundled libraries. Relink with DT_RUNPATH", .{rejected}), ctx.diagnostic);
    }

    try tmp.dir.rename("libraries/libfixture.so", tmp.dir, "original/libfixture.so", io);
    if (native_linux) {
        const collected = try z.bundle_dependencies.collect(&ctx, io, compiler, "0.17.1");
        try std.testing.expectEqualStrings(library, collected.get("libfixture.so").?);
    } else {
        try std.testing.expect(try z.bundle_dependencies.elfIsDynamic(&ctx, io, compiler, host));
        _ = try z.bundle_dependencies.elfIsDynamic(&ctx, io, library, host);
    }
}

pub fn macFramework() !void {
    if (builtin.target.os.tag != .macos) return error.SkipZigTest;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    const install_name = "@rpath/Codec.framework/Versions/A/Codec";
    try tmp.dir.createDirPath(io, "Codec.framework/Versions/A");
    try tmp.dir.writeFile(io, .{ .sub_path = "library.zig", .data = "export fn codec() u8 { return 1; }" });
    try link(&ctx, tmp.dir, &.{ "build-lib", "library.zig", "-Osmall", "-dynamic", "-install_name", install_name, "-femit-bin=Codec.framework/Versions/A/Codec" });
    try tmp.dir.symLink(io, "Versions/A/Codec", "Codec.framework/Codec", .{});
    try tmp.dir.writeFile(io, .{ .sub_path = "compiler.zig", .data =
        \\extern "c" fn puts(s: [*:0]const u8) c_int;
        \\pub fn main() void { _ = puts("0.17.1"); }
    });
    const compiler_args = [_][]const u8{ "build-exe", "compiler.zig", "-Osmall", "-lc", "-femit-bin=compiler" };
    try link(&ctx, tmp.dir, &(compiler_args ++ .{ "-needed_framework", "CoreFoundation" }));
    const compiler = try tmp.dir.realPathFileAlloc(io, "compiler", ctx.allocator);
    const system = try z.bundle_dependencies.collect(&ctx, io, compiler, "0.17.1");
    try std.testing.expectEqual(0, system.count());

    try link(&ctx, tmp.dir, &(compiler_args ++ .{ "-weak_framework", "Codec", "-F.", "-rpath", "@executable_path", "-rpath", "/System/Library/Frameworks" }));
    try std.testing.expectError(error.InvalidInput, z.bundle_dependencies.collect(&ctx, io, compiler, "0.17.1"));
    try std.testing.expectEqualStrings("cannot bundle external macOS framework " ++ install_name, ctx.diagnostic);
    try tmp.dir.rename("Codec.framework", tmp.dir, "moved-framework", io);
    try std.testing.expectError(error.InvalidInput, z.bundle_dependencies.collect(&ctx, io, compiler, "0.17.1"));
    try std.testing.expectEqualStrings("cannot bundle external macOS framework " ++ install_name, ctx.diagnostic);
}
