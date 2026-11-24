// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Resolve native dependencies of the compiler being packaged.
const std = @import("std");
const builtin = @import("builtin");
const c = @import("common.zig");
const files = @import("files.zig");
const Dir = std.Io.Dir;

pub const Libraries = std.StringArrayHashMapUnmanaged([]const u8);

/// The archive flattens libraries into one directory, which may be case-insensitive.
pub fn checkArchiveNames(ctx: *c.Context, names: []const []const u8) !void {
    for (names, 0..) |name, index| {
        for (names[0..index]) |previous| {
            if (std.ascii.eqlIgnoreCase(name, previous) or
                (builtin.target.os.tag == .macos and try MacNames.equivalent(ctx, name, previous)))
                return ctx.fail("native library names {s} and {s} collide in the standalone bundle", .{ previous, name });
        }
    }
}

const MacNames = struct {
    const String = opaque {};
    const utf8: u32 = 0x08000100;
    const case_insensitive: usize = 1;
    const nonliteral: usize = 16;

    extern "CoreFoundation" fn CFStringCreateWithBytes(allocator: ?*const anyopaque, bytes: [*]const u8, length: isize, encoding: u32, external_representation: u8) ?*const String;
    extern "CoreFoundation" fn CFStringCompare(left: *const String, right: *const String, options: usize) isize;
    extern "CoreFoundation" fn CFRelease(object: *const anyopaque) void;

    fn equivalent(ctx: *c.Context, a: []const u8, b: []const u8) !bool {
        if (isAscii(a) and isAscii(b)) return false; // The caller checked ASCII case folding.
        const left = CFStringCreateWithBytes(null, a.ptr, @intCast(a.len), utf8, 0) orelse
            return ctx.fail("cannot compare native library name {s} as UTF-8", .{a});
        defer CFRelease(left);
        const right = CFStringCreateWithBytes(null, b.ptr, @intCast(b.len), utf8, 0) orelse
            return ctx.fail("cannot compare native library name {s} as UTF-8", .{b});
        defer CFRelease(right);
        return CFStringCompare(left, right, case_insensitive | nonliteral) == 0;
    }

    fn isAscii(name: []const u8) bool {
        for (name) |byte| {
            if (!std.ascii.isAscii(byte)) return false;
        }
        return true;
    }
};

pub fn collect(ctx: *c.Context, io: std.Io, executable: []const u8, version: []const u8) !Libraries {
    return switch (builtin.target.os.tag) {
        .macos => macLibraries(ctx, io, executable, version),
        .linux => linux: {
            const libraries = try linuxLibraries(ctx, io, executable);
            try checkVersion(ctx, try runTool(ctx, io, &.{ executable, "version" }), version);
            break :linux libraries;
        },
        else => ctx.fail("standalone packaging supports macOS and Linux", .{}),
    };
}

fn checkVersion(ctx: *c.Context, output: []const u8, expected: []const u8) !void {
    try ctx.require(std.mem.eql(u8, std.mem.trim(u8, output, " \t\r\n"), expected), "bundled compiler version mismatch");
}

fn addLibrary(ctx: *c.Context, io: std.Io, result: *Libraries, name: []const u8, path: []const u8) ![]const u8 {
    try ctx.require(Dir.path.isAbsolute(path) and files.validRelativePath(name) and std.mem.eql(u8, name, Dir.path.basename(name)), "invalid native library path");
    const real = try Dir.cwd().realPathFileAlloc(io, path, ctx.allocator);
    const entry = try result.getOrPut(ctx.allocator, name);
    if (entry.found_existing) {
        try ctx.require(std.mem.eql(u8, entry.value_ptr.*, real), "native libraries use the same filename for different dependencies");
    } else {
        entry.value_ptr.* = real;
    }
    return real;
}

const MacImage = struct {
    const Dependency = struct { name: []const u8, weak: bool };
    const Command = enum { run_path, install_name, load, weak_load };

    install_name: ?[]const u8 = null,
    run_paths: std.ArrayList([]const u8) = .empty,
    dependencies: std.ArrayList(Dependency) = .empty,

    fn read(ctx: *c.Context, io: std.Io, image: []const u8) !MacImage {
        const listing = try runTool(ctx, io, &.{ "/usr/bin/otool", "-arch", try macArch(ctx), "-l", image });
        var result: MacImage = .{};
        var pending: ?Command = null;
        var lines = std.mem.splitScalar(u8, listing, '\n');
        while (lines.next()) |raw| {
            const line = std.mem.trim(u8, raw, " \t\r");
            if (std.mem.startsWith(u8, line, "Load command "))
                try ctx.require(pending == null, "incomplete Mach-O load command");
            if (std.mem.startsWith(u8, line, "cmd ")) {
                const command = line["cmd ".len..];
                pending = if (std.mem.eql(u8, command, "LC_RPATH"))
                    .run_path
                else if (std.mem.eql(u8, command, "LC_ID_DYLIB"))
                    .install_name
                else if (std.mem.eql(u8, command, "LC_LOAD_WEAK_DYLIB"))
                    .weak_load
                else if (c.oneOf(command, &.{ "LC_LOAD_DYLIB", "LC_REEXPORT_DYLIB", "LC_LOAD_UPWARD_DYLIB", "LC_LAZY_LOAD_DYLIB" }))
                    .load
                else
                    null;
                continue;
            }
            const command = pending orelse continue;
            const field = if (command == .run_path) "path " else "name ";
            if (!std.mem.startsWith(u8, line, field)) continue;
            const end = std.mem.lastIndexOf(u8, line, " (offset ") orelse return ctx.fail("invalid Mach-O path field", .{});
            try ctx.require(end > field.len, "empty Mach-O load path");
            const path = line[field.len..end];
            switch (command) {
                .run_path => try result.run_paths.append(ctx.allocator, path),
                .install_name => result.install_name = path,
                .load, .weak_load => try result.dependencies.append(ctx.allocator, .{ .name = path, .weak = command == .weak_load }),
            }
            pending = null;
        }
        try ctx.require(pending == null, "incomplete Mach-O load command");
        return result;
    }
};

const MacTrace = struct {
    const Image = struct { path: []const u8, commands: MacImage };

    images: std.StringArrayHashMapUnmanaged(Image) = .empty,
    install_names: std.StringHashMapUnmanaged(?[]const u8) = .empty,
    system: std.StringHashMapUnmanaged(void) = .empty,

    fn read(ctx: *c.Context, io: std.Io, executable: []const u8, version: []const u8) !MacTrace {
        // Probe without loader overrides. Dyld may satisfy a later reference
        // by install name using an image it has already loaded elsewhere.
        var env: std.process.Environ.Map = .init(ctx.allocator);
        defer env.deinit();
        try env.put("DYLD_PRINT_LIBRARIES", "1");
        const probe = try runProcess(ctx, io, &.{ executable, "version" }, &env);
        try checkVersion(ctx, probe.stdout, version);
        var trace: MacTrace = .{};
        var saw_executable = false;
        var lines = std.mem.splitScalar(u8, probe.stderr, '\n');
        while (lines.next()) |line| {
            if (!std.mem.startsWith(u8, line, "dyld[")) continue;
            const delimiter = std.mem.indexOf(u8, line, "> /") orelse continue;
            const path = line[delimiter + "> ".len ..];
            if (macSystemLibrary(path)) {
                try trace.system.put(ctx.allocator, path, {});
                continue;
            }
            const real = try Dir.cwd().realPathFileAlloc(io, path, ctx.allocator);
            if (std.mem.eql(u8, real, executable)) {
                saw_executable = true;
                continue;
            }
            if (trace.images.contains(real)) continue;
            const commands = try MacImage.read(ctx, io, path);
            try trace.images.put(ctx.allocator, real, .{ .path = path, .commands = commands });
            if (commands.install_name) |name| {
                const entry = try trace.install_names.getOrPut(ctx.allocator, name);
                entry.value_ptr.* = if (entry.found_existing) null else path;
            }
        }
        try ctx.require(saw_executable, "could not inspect the compiler's dyld libraries");
        return trace;
    }
};

const MacLibraries = struct {
    ctx: *c.Context,
    io: std.Io,
    executable: []const u8,
    trace: MacTrace,
    result: Libraries = .empty,
    visited: std.StringHashMapUnmanaged(void) = .empty,

    fn visit(self: *MacLibraries, image: []const u8, real: []const u8, inherited: []const []const u8) !void {
        const ctx = self.ctx;
        if ((try self.visited.getOrPut(ctx.allocator, real)).found_existing) return;
        const commands = if (self.trace.images.get(real)) |loaded| loaded.commands else try MacImage.read(ctx, self.io, image);
        if (!std.mem.eql(u8, real, self.executable)) {
            try rejectMacFramework(ctx, image);
            try rejectMacFramework(ctx, real);
            if (commands.install_name) |name| try rejectMacFramework(ctx, name);
        }
        var run_paths: std.ArrayList([]const u8) = .empty;
        for (commands.run_paths.items) |path|
            try run_paths.append(ctx.allocator, try self.expand(image, path));
        try run_paths.appendSlice(ctx.allocator, inherited);
        for (commands.dependencies.items) |dependency| {
            const resolved_path = try self.resolve(image, dependency.name, run_paths.items);
            if (resolved_path) |path| {
                if (macSystemLibrary(path)) continue;
            }
            try rejectMacFramework(ctx, dependency.name);
            const path = resolved_path orelse {
                if (dependency.weak) continue;
                return ctx.fail("could not resolve {s} loaded by {s}", .{ dependency.name, image });
            };
            const name = Dir.path.basename(dependency.name);
            const resolved = try addLibrary(ctx, self.io, &self.result, name, path);
            try self.visit(path, resolved, run_paths.items);
        }
    }

    fn expand(self: *const MacLibraries, image: []const u8, path: []const u8) ![]const u8 {
        if (Dir.path.isAbsolute(path)) return path;
        const slash = std.mem.indexOfScalar(u8, path, '/') orelse path.len;
        const base = path[0..slash];
        const path_owner = if (std.mem.eql(u8, base, "@loader_path")) image else if (std.mem.eql(u8, base, "@executable_path")) self.executable else return self.ctx.fail("unsupported Mach-O path {s} in {s}", .{ path, image });
        const directory = Dir.path.dirname(path_owner) orelse return error.InvalidNativeImagePath;
        return files.join(self.ctx, &.{ directory, std.mem.trimStart(u8, path[slash..], "/") });
    }

    fn resolve(self: *const MacLibraries, image: []const u8, name: []const u8, run_paths: []const []const u8) !?[]const u8 {
        if (macSystemLibrary(name)) return name;
        const prefix = "@rpath/";
        var fallback: ?[]const u8 = null;
        if (std.mem.startsWith(u8, name, prefix)) {
            for (run_paths) |dir| {
                const path = try files.join(self.ctx, &.{ dir, name[prefix.len..] });
                if (try self.loadedPath(path)) |loaded| return loaded;
                if (fallback == null and try self.available(path)) fallback = path;
            }
        } else {
            const path = try self.expand(image, name);
            if (try self.loadedPath(path)) |loaded| return loaded;
            if (try self.available(path)) fallback = path;
        }
        if (self.trace.install_names.get(name)) |loaded| {
            if (loaded) |path| return path;
        }
        return fallback;
    }

    fn loadedPath(self: *const MacLibraries, path: []const u8) !?[]const u8 {
        if (macSystemLibrary(path)) return if (self.trace.system.contains(path)) path else null;
        const real = Dir.cwd().realPathFileAlloc(self.io, path, self.ctx.allocator) catch |err| switch (err) {
            error.FileNotFound, error.NotDir => return null,
            else => return err,
        };
        defer self.ctx.allocator.free(real);
        return if (self.trace.images.get(real)) |loaded| loaded.path else null;
    }

    extern "c" fn _dyld_shared_cache_contains_path(path: [*:0]const u8) bool;

    fn available(self: *const MacLibraries, path: []const u8) !bool {
        if (macSystemLibrary(path)) {
            const name = try std.posix.toPosixPath(path);
            if (_dyld_shared_cache_contains_path(&name)) return true;
        }
        const stat = Dir.cwd().statFile(self.io, path, .{}) catch |err| switch (err) {
            error.FileNotFound, error.NotDir => return false,
            else => return err,
        };
        return stat.kind == .file and try macImageHasType(self.ctx, self.io, path, "DYLIB");
    }
};

fn macArch(ctx: *c.Context) ![]const u8 {
    return switch (builtin.target.cpu.arch) {
        .aarch64 => "arm64",
        .x86_64 => "x86_64",
        else => ctx.fail("unsupported macOS packaging architecture", .{}),
    };
}

fn macImageHasType(ctx: *c.Context, io: std.Io, path: []const u8, kind: []const u8) !bool {
    // otool can succeed with no output when the requested architecture is absent.
    const listing = try runTool(ctx, io, &.{ "/usr/bin/otool", "-arch", try macArch(ctx), "-hv", path });
    var lines = std.mem.splitScalar(u8, listing, '\n');
    while (lines.next()) |line| {
        var fields = std.mem.tokenizeAny(u8, line, " \t");
        if (!std.mem.eql(u8, fields.next() orelse continue, "MH_MAGIC_64")) continue;
        _ = fields.next(); // cputype
        _ = fields.next(); // cpusubtype
        _ = fields.next(); // caps
        return std.mem.eql(u8, fields.next() orelse return false, kind);
    }
    return false;
}

fn macSystemLibrary(path: []const u8) bool {
    return std.mem.startsWith(u8, path, "/usr/lib/") or std.mem.startsWith(u8, path, "/System/Library/");
}

fn rejectMacFramework(ctx: *c.Context, path: []const u8) !void {
    // Dyld searches framework paths separately when the framework and binary names match.
    const name_end = std.mem.findLast(u8, path, ".framework/") orelse return;
    if (std.mem.eql(u8, Dir.path.basename(path[0..name_end]), Dir.path.basename(path)))
        return ctx.fail("cannot bundle external macOS framework {s}", .{path});
}

fn macLibraries(ctx: *c.Context, io: std.Io, executable: []const u8, version: []const u8) !Libraries {
    const real = try Dir.cwd().realPathFileAlloc(io, executable, ctx.allocator);
    try ctx.require(try macImageHasType(ctx, io, real, "EXECUTE"), "bundled compiler must be a native Mach-O executable");
    var libraries: MacLibraries = .{ .ctx = ctx, .io = io, .executable = real, .trace = try MacTrace.read(ctx, io, real, version) };
    try libraries.visit(real, real, &.{});
    for (libraries.trace.images.keys(), libraries.trace.images.values()) |path, loaded| {
        if (libraries.visited.contains(path)) continue;
        _ = try addLibrary(ctx, io, &libraries.result, Dir.path.basename(loaded.commands.install_name orelse path), path);
        try libraries.visit(loaded.path, path, &.{});
    }
    return libraries.result;
}

/// Inspect an ELF image for paths that override the bundle and report whether it needs a loader.
pub fn elfIsDynamic(ctx: *c.Context, io: std.Io, path: []const u8, host: std.Target) !bool {
    const file = try Dir.cwd().openFile(io, path, .{ .allow_directory = false });
    defer file.close(io);
    var buffer: [4096]u8 = undefined;
    var reader = file.reader(io, &buffer);
    const elf = std.elf;
    const header = elf.Header.read(&reader.interface) catch
        return ctx.fail("bundled compiler must be a native ELF executable", .{});
    try ctx.require(header.machine == host.toElfMachine() and header.endian == host.cpu.arch.endian() and
        header.is_64 == (host.ptrBitWidth() == 64), "compiler ELF architecture does not match the packaging host");
    try ctx.require(header.type == .EXEC or header.type == .DYN, "compiler ELF must be executable");
    const file_size = (try file.stat(io)).size;
    const phdr_size: u16 = if (header.is_64) @sizeOf(elf.Elf64.Phdr) else @sizeOf(elf.Elf32.Phdr);
    try ctx.require(header.phentsize == phdr_size and header.phnum != 0 and header.phoff <= file_size and
        @as(u64, phdr_size) * header.phnum <= file_size - header.phoff, "invalid compiler ELF program headers");
    var needs_loader = false;
    var headers = header.iterateProgramHeaders(&reader);
    while (try headers.next()) |program| {
        if (program.type == .INTERP) needs_loader = true;
        if (program.type != .DYNAMIC) continue;
        const entry_size: u64 = if (header.is_64) @sizeOf(elf.Elf64_Dyn) else @sizeOf(elf.Elf32_Dyn);
        try ctx.require(program.offset <= file_size and program.filesz <= file_size - program.offset and
            program.filesz % entry_size == 0, "invalid ELF dynamic table");
        var dynamic = header.iterateDynamicSection(&reader, program.offset, program.filesz);
        while (try dynamic.next()) |entry| switch (entry.d_tag) {
            elf.DT_NULL => break,
            elf.DT_NEEDED => needs_loader = true,
            elf.DT_RPATH => return ctx.fail("ELF DT_RPATH in {s} can override bundled libraries. Relink with DT_RUNPATH", .{path}),
            else => {},
        } else return ctx.fail("unterminated ELF dynamic table in {s}", .{path});
    }
    return needs_loader;
}

fn linuxLibraries(ctx: *c.Context, io: std.Io, executable: []const u8) !Libraries {
    var result: Libraries = .empty;
    if (!try elfIsDynamic(ctx, io, executable, builtin.target)) return result;
    const listing = try runTool(ctx, io, &.{ "ldd", executable });
    var lines = std.mem.splitScalar(u8, listing, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        const separator = std.mem.indexOf(u8, trimmed, " => ") orelse {
            if (trimmed.len == 0 or std.mem.startsWith(u8, trimmed, "linux-vdso") or
                std.mem.startsWith(u8, trimmed, "linux-gate") or std.mem.startsWith(u8, Dir.path.basename(trimmed), "ld-linux") or
                std.mem.startsWith(u8, Dir.path.basename(trimmed), "ld-musl-")) continue;
            return ctx.fail("unsupported ldd entry {s}", .{trimmed});
        };
        const name = trimmed[0..separator];
        const path = trimmed[separator + " => ".len ..];
        const end = std.mem.lastIndexOf(u8, path, " (") orelse
            return ctx.fail("could not resolve native library {s}", .{name});
        if (c.oneOf(name, &.{ "libc.so.6", "libm.so.6", "libpthread.so.0", "librt.so.1", "libdl.so.2" })) continue;
        const real = try addLibrary(ctx, io, &result, name, path[0..end]);
        _ = try elfIsDynamic(ctx, io, real, builtin.target);
    }
    return result;
}

fn runTool(ctx: *c.Context, io: std.Io, argv: []const []const u8) ![]const u8 {
    return (try runProcess(ctx, io, argv, null)).stdout;
}

fn runProcess(ctx: *c.Context, io: std.Io, argv: []const []const u8, env: ?*const std.process.Environ.Map) !std.process.RunResult {
    const result = try std.process.run(ctx.allocator, io, .{
        .argv = argv,
        .environ_map = env,
        .stdout_limit = .limited(1024 * 1024),
        .stderr_limit = .limited(1024 * 1024),
    });
    if (result.term != .exited or result.term.exited != 0)
        return ctx.fail("{s} failed for {s} ({s})", .{ argv[0], argv[argv.len - 1], result.stderr });
    return result;
}
