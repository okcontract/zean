// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Isolated, identity-bound instrumented Zig builds.
const std = @import("std");
const c = @import("common.zig");
const files = @import("files.zig");
const runtime = @import("runtime.zig");
const patch = @import("patch.zig");
const z = @import("root.zig");
pub const Options = struct { tree: []const u8, output: []const u8, bootstrap: []const u8, llvm: []const u8, lld: []const u8, cmake: []const u8 = "cmake", generator: []const u8 = "Ninja", system_libcpp: ?[]const u8 = null, search_prefixes: []const []const u8 = &.{}, fresh_air: bool = false, jobs: u32 = 2 };

pub fn set(ctx: *c.Context, object: *c.Value, name: []const u8, value: anytype) !void {
    try object.object.put(ctx.allocator, name, try ctx.parse(try ctx.json(value)));
}
pub fn absolute(ctx: *c.Context, path: []const u8) ![]const u8 {
    return std.fs.path.resolve(ctx.allocator, &.{path});
}
pub fn newOutput(ctx: *c.Context, io: std.Io, path: []const u8) ![]const u8 {
    const output = try absolute(ctx, path);
    if (std.fs.path.dirname(output)) |parent| try std.Io.Dir.cwd().createDirPath(io, parent);
    try std.Io.Dir.cwd().createDir(io, output, .default_dir);
    return output;
}
pub fn checkCheckout(runner: runtime.Runner, tree: []const u8, label: []const u8) !void {
    const ctx = runner.ctx;
    const revision_label = try ctx.fmt("{s}-revision", .{label});
    try runner.run(revision_label, &.{ "git", "-C", tree, "rev-parse", "HEAD" }, .{});
    try ctx.require(std.mem.eql(u8, try runner.text(revision_label), z.revision), "Zig checkout is not the pinned 0.17.1 revision");
    const status_label = try ctx.fmt("{s}-status", .{label});
    try runner.run(status_label, &.{ "git", "-C", tree, "status", "--porcelain", "--untracked-files=normal" }, .{});
    try ctx.require((try runner.text(status_label)).len == 0, "Zig checkout has local changes; original sources are never modified");
}
pub fn checkPatch(ctx: *c.Context, io: std.Io, tree: []const u8, project: []const u8, output: []const u8) !c.Value {
    const directory = try newOutput(ctx, io, output);
    const runner: runtime.Runner = .{ .ctx = ctx, .io = io, .output = directory };
    try checkCheckout(runner, try absolute(ctx, tree), "checkout");
    const isolated = try files.join(ctx, &.{ directory, "source" });
    try std.Io.Dir.cwd().createDir(io, isolated, .default_dir);
    for ([_][]const u8{ "src/main.zig", "src/Compilation.zig", "src/Air.zig", "src/Sema.zig", "src/Zcu/PerThread.zig" }) |name| {
        const target = try files.join(ctx, &.{ isolated, name });
        try std.Io.Dir.cwd().createDirPath(io, std.fs.path.dirname(target).?);
        try files.write(io, target, try ctx.read(io, try files.join(ctx, &.{ tree, name }), 64 * 1024 * 1024));
    }
    const changes = try patch.apply(ctx, io, isolated, project);
    return ctx.parse(try ctx.json(.{ .zigVersion = z.version, .zigRevision = z.revision, .patchFiles = changes.array.items.len, .patchApplies = true, .instrumentedCompilerBuilt = false }));
}
pub fn build(ctx: *c.Context, io: std.Io, environ: *const std.process.Environ.Map, project: []const u8, options: Options) !c.Value {
    try ctx.require(options.jobs > 0 and options.jobs <= 64, "jobs must be positive and bounded");
    try ctx.require(c.oneOf(options.generator, &.{ "Ninja", "Unix Makefiles" }), "unsupported CMake generator");
    const output = try newOutput(ctx, io, options.output);
    var report = try ctx.parse(try ctx.json(.{ .schema = "oksolc.zig-air-toolchain.v1", .status = "failed", .zigRevision = z.revision, .jobs = options.jobs, .buildMode = "ReleaseFast", .compilerVerified = false, .compilerDebugInfo = "stripped", .compilerBuildMemoryLimitBytes = @as(u64, 8_000_000_000), .externalToolchainClosureComplete = false, .semanticExportImplemented = false }));
    defer files.write(io, files.join(ctx, &.{ output, "report.json" }) catch unreachable, ctx.json(report) catch "{\"status\":\"failed\"}") catch {};
    return buildInto(ctx, io, environ, project, options, output, &report) catch |err| {
        set(ctx, &report, "status", "failed") catch {};
        set(ctx, &report, "error", if (err == error.InvalidInput) ctx.diagnostic else @errorName(err)) catch {};
        return err;
    };
}
fn buildInto(ctx: *c.Context, io: std.Io, environ: *const std.process.Environ.Map, project: []const u8, options: Options, output: []const u8, report: *c.Value) !c.Value {
    const runner: runtime.Runner = .{ .ctx = ctx, .io = io, .output = output };
    const tree = try absolute(ctx, options.tree);
    const bootstrap = try absolute(ctx, options.bootstrap);
    const llvm = try absolute(ctx, options.llvm);
    const lld = try absolute(ctx, options.lld);
    try checkCheckout(runner, tree, "before");
    try runner.run("bootstrap-version", &.{ bootstrap, "version" }, .{});
    try ctx.require(std.mem.eql(u8, try runner.text("bootstrap-version"), z.version), "bootstrap Zig must be exactly 0.17.1");
    const bootstrap_hash = try runtime.fileDigest(ctx, io, bootstrap);
    try set(ctx, report, "bootstrap", .{ .path = bootstrap, .sha256 = &bootstrap_hash, .version = z.version });
    try runner.run("llvm-version", &.{ try files.join(ctx, &.{ llvm, "bin/llvm-config" }), "--version" }, .{});
    const llvm_version = try runner.text("llvm-version");
    try ctx.require(std.mem.startsWith(u8, llvm_version, "22."), "pinned Zig requires LLVM 22.x");
    try set(ctx, report, "llvm", .{ .prefix = llvm, .version = llvm_version, .lldPrefix = lld });
    const archive = try files.join(ctx, &.{ output, "source.tar" });
    const source = try files.join(ctx, &.{ output, "source" });
    try runner.run("archive", &.{ "git", "-C", tree, "archive", "--format=tar", try ctx.fmt("--output={s}", .{archive}), z.revision }, .{});
    try set(ctx, report, "sourceArchiveSha256", &(try runtime.fileDigest(ctx, io, archive)));
    try runtime.unpack(ctx, io, archive, source);
    try set(ctx, report, "upstreamSourceTree", try runtime.sourceIdentity(ctx, io, source));
    if (options.system_libcpp) |library| try set(ctx, report, "systemCppLinkPatch", try linkLibcpp(ctx, io, source, try absolute(ctx, library)));
    if (options.fresh_air) {
        try set(ctx, report, "freshAirCapturePatch", try patch.apply(ctx, io, source, project));
        try set(ctx, report, "freshAirCaptureImplemented", true);
    }
    const identity = try runtime.sourceIdentity(ctx, io, source);
    try set(ctx, report, "sourceTree", identity);
    const cmake_directory = try files.join(ctx, &.{ output, "cmake" });
    const install = try files.join(ctx, &.{ output, "install" });
    try runner.run("configure", &.{ options.cmake, "-S", source, "-B", cmake_directory, "-G", options.generator, "-DCMAKE_BUILD_TYPE=Release", "-DZIG_SHARED_LLVM=ON", try ctx.fmt("-DCMAKE_PREFIX_PATH={s};{s}", .{ llvm, lld }) }, .{});
    try runner.run("zigcpp", &.{ options.cmake, "--build", cmake_directory, "--target", "zigcpp", "--parallel", try ctx.fmt("{d}", .{options.jobs}) }, .{});
    const config = try files.join(ctx, &.{ cmake_directory, "config.h" });
    try set(ctx, report, "configSha256", &(try runtime.fileDigest(ctx, io, config)));
    var build_environment = try environ.clone(ctx.allocator);
    try build_environment.put("ZIG_LIB_DIR", try files.join(ctx, &.{ source, "lib" }));
    try build_environment.put("ZIG_GLOBAL_CACHE_DIR", try files.join(ctx, &.{ output, "global-cache" }));
    var command: std.ArrayList([]const u8) = .empty;
    try command.appendSlice(ctx.allocator, &.{ bootstrap, "build", try ctx.fmt("-j{d}", .{options.jobs}), "-Doptimize=fast", "-Dstrip=true", "-Dversion-string=" ++ z.version, "-Denable-llvm", try ctx.fmt("-Dconfig_h={s}", .{config}), "-Dno-lib", "-Dno-langref" });
    var prefixes: std.ArrayList([]const u8) = .empty;
    for (options.search_prefixes) |prefix| {
        const path = try absolute(ctx, prefix);
        const stat = try std.Io.Dir.cwd().statFile(io, path, .{});
        try ctx.require(stat.kind == .directory, "build search prefixes must be existing directories");
        try prefixes.append(ctx.allocator, path);
        try command.appendSlice(ctx.allocator, &.{ "--search-prefix", path });
    }
    try set(ctx, report, "buildSearchPrefixes", prefixes.items);
    try command.appendSlice(ctx.allocator, &.{ "--cache-dir", try files.join(ctx, &.{ output, "zig-cache" }), "--prefix", install });
    try runner.run("build", command.items, .{ .cwd = source, .environ = &build_environment });
    const diagnostics = try ctx.read(io, try files.join(ctx, &.{ output, "build.stderr" }), 64 * 1024 * 1024);
    try set(ctx, report, "buildDiagnostics", .{ .bytes = diagnostics.len, .sha256 = &c.digest(diagnostics) });
    try ctx.require(std.mem.indexOf(u8, diagnostics, "error:") == null, "Zig build reported an error despite its zero exit status; inspect build.stderr");
    try set(ctx, report, "status", if (diagnostics.len == 0) "built" else "built-with-diagnostics");
    const compiler = try files.join(ctx, &.{ install, "bin/zig" });
    try runner.run("compiler-version", &.{ compiler, "version" }, .{});
    try ctx.require(std.mem.eql(u8, try runner.text("compiler-version"), z.version), "built Zig has an unexpected version");
    const smoke = try files.join(ctx, &.{ output, "smoke.zig" });
    try files.write(io, smoke, "// Copyright (C) 2026 OKcontract Pte. Ltd.\nexport fn add_wrapping(x: u32, y: u32) u32 { return x +% y; }\n");
    for ([_][]const u8{ "baseline", "rebuilt" }, [_][]const u8{ bootstrap, compiler }) |label, executable| try runner.run(try ctx.fmt("{s}-llvm-smoke", .{label}), &.{ executable, "build-obj", "--zig-lib-dir", try files.join(ctx, &.{ source, "lib" }), "-fllvm", "-OReleaseFast", "-fstrip", smoke, try ctx.fmt("-femit-bin={s}", .{try files.join(ctx, &.{ output, try ctx.fmt("{s}.o", .{label}) })}), "--cache-dir", try files.join(ctx, &.{ output, try ctx.fmt("{s}-cache", .{label}) }), "--global-cache-dir", try files.join(ctx, &.{ output, "global-cache" }) }, .{});
    const baseline_hash = try runtime.fileDigest(ctx, io, try files.join(ctx, &.{ output, "baseline.o" }));
    const rebuilt_hash = try runtime.fileDigest(ctx, io, try files.join(ctx, &.{ output, "rebuilt.o" }));
    try set(ctx, report, "llvmSmokeObjects", .{ .baseline = &baseline_hash, .rebuilt = &rebuilt_hash });
    try ctx.require(std.mem.eql(u8, &baseline_hash, &rebuilt_hash), "LLVM smoke object differs from the installed pinned compiler");
    try checkCheckout(runner, tree, "after");
    try ctx.require(c.equal(identity, try runtime.sourceIdentity(ctx, io, source)) and std.mem.eql(u8, &bootstrap_hash, &(try runtime.fileDigest(ctx, io, bootstrap))), "toolchain inputs changed during the build");
    if (options.system_libcpp) |library| try ctx.require(c.tag(try ctx.field(report.*, "systemCppLinkPatch"), "librarySha256", &(try runtime.fileDigest(ctx, io, try absolute(ctx, library)))), "system C++ link input changed during the build");
    try set(ctx, report, "compiler", .{ .path = compiler, .sha256 = &(try runtime.fileDigest(ctx, io, compiler)), .version = z.version, .zigLibDir = try files.join(ctx, &.{ source, "lib" }) });
    return report.*;
}
fn linkLibcpp(ctx: *c.Context, io: std.Io, source: []const u8, library: []const u8) !c.Value {
    const path = try files.join(ctx, &.{ source, "build.zig" });
    const original = try ctx.read(io, path, 16 * 1024 * 1024);
    const old = "            .driverkit, .ios, .maccatalyst, .macos, .tvos, .visionos, .watchos => {\n                mod.link_libcpp = true;\n            },";
    try ctx.require(std.mem.count(u8, original, old) == 1, "pinned system C++ build configuration changed");
    const offset = std.mem.indexOf(u8, original, old).?;
    const replacement = try ctx.fmt("            .driverkit, .ios, .maccatalyst, .macos, .tvos, .visionos, .watchos => {{\n                mod.addObjectFile(.{{ .cwd_relative = {s} }});\n            }},", .{try ctx.json(library)});
    const updated = try std.mem.concat(ctx.allocator, u8, &.{ original[0..offset], replacement, original[offset + old.len ..] });
    try files.write(io, path, updated);
    return ctx.parse(try ctx.json(.{ .file = "build.zig", .beforeSha256 = &c.digest(original), .afterSha256 = &c.digest(updated), .library = library, .librarySha256 = &(try runtime.fileDigest(ctx, io, library)) }));
}
