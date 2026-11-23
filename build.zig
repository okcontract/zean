// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.

const std = @import("std");
const builtin = @import("builtin");
const lean_toolchain = std.mem.trim(u8, @embedFile("lean-toolchain"), " \t\r\n");

comptime {
    if (builtin.zig_version.order(.{ .major = 0, .minor = 17, .patch = 1 }) != .eq)
        @compileError("Zean requires Zig 0.17.1");
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const toolchain_report = b.option([]const u8, "toolchain-report", "Instrumented Zig report for standalone and release-check");
    const options = b.addOptions();
    const producer = treeIdentity(b, "src", &.{ "build.zig", "build.zig.zon" }) catch @panic("cannot identify producer sources");
    const models = treeIdentity(b, "lean", &.{ "lean-toolchain", "lakefile.lean" }) catch @panic("cannot identify Lean library");
    options.addOption([]const u8, "producer_sha256", &producer.sha256);
    options.addOption(usize, "producer_files", producer.files);
    options.addOption([]const u8, "model_sha256", &models.sha256);
    options.addOption(usize, "model_files", models.files);
    options.addOption([]const u8, "lean_toolchain", lean_toolchain);
    // The installed CLI also runs from client repositories.
    const root_path = b.root.joinString(b.allocator, ".") catch @panic("cannot locate Zean sources");
    const project_root = std.Io.Dir.cwd().realPathFileAlloc(b.graph.io, root_path, b.allocator) catch @panic("cannot resolve Zean sources");
    options.addOption([]const u8, "project_root", project_root);
    const module = b.addModule("zean", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "build_options", .module = options.createModule() }},
    });
    const cli_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "zean", .module = module }},
    });
    cli_module.addAnonymousImport("capture_payload", .{ .root_source_file = b.addWriteFiles().add("empty-payload", "") });
    const executable = b.addExecutable(.{ .name = "zean", .root_module = cli_module });
    b.installArtifact(executable);
    const standalone = b.step("standalone", "Install a self-contained Zean executable with the instrumented Zig compiler");
    if (toolchain_report) |report| {
        if (target.query.isNative()) {
            const packer = b.addExecutable(.{ .name = "zean-bundle", .root_module = b.createModule(.{
                .root_source_file = b.path("src/bundle_tool.zig"),
                .target = b.graph.host,
                .optimize = .safe,
                .imports = &.{.{ .name = "zean", .module = module }},
            }) });
            if (b.graph.host.result.os.tag == .macos)
                packer.root_module.linkFramework("CoreFoundation", .{});
            const pack = b.addRunArtifact(packer);
            pack.addFileArg(b.graph.cwdRelativePath(report));
            const archive = pack.addOutputFileArg("compiler.tar.gz");
            // The report refers to an external source tree and executable.
            pack.has_side_effects = true;
            const bundled = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{.{ .name = "zean", .module = module }},
            });
            bundled.addAnonymousImport("capture_payload", .{ .root_source_file = archive });
            const standalone_exe = b.addExecutable(.{ .name = "zean", .root_module = bundled });
            standalone.dependOn(&b.addInstallArtifact(standalone_exe, .{}).step);
        } else standalone.dependOn(&b.addFail("standalone requires a native target and a report for that host").step);
    } else standalone.dependOn(&b.addFail("standalone requires -Dtoolchain-report=/path/to/report.json").step);
    const run = b.addRunArtifact(executable);
    run.addPassthruArgs();
    b.step("run", "Run the native Zig-to-Lean tool").dependOn(&run.step);
    inline for (.{ "capture", "toolchain", "check-patch", "audit", "admission", "verify-client", "allocator-evaluate" }) |command| {
        const command_run = b.addRunArtifact(executable);
        command_run.addArg(command);
        command_run.addPassthruArgs();
        b.step(command, "Run " ++ command).dependOn(&command_run.step);
    }
    const fixture = b.addExecutable(.{ .name = "zean-test-child", .root_module = b.createModule(.{ .root_source_file = b.path("test/native/process_fixture.zig"), .target = target, .optimize = optimize }) });
    const test_options = b.addOptions();
    test_options.addOptionPath("child", fixture.getEmittedBin());
    const test_module = b.createModule(.{
        .root_source_file = b.path("test/native/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "zean", .module = module }, .{ .name = "test_options", .module = test_options.createModule() } },
    });
    if (target.result.os.tag == .macos)
        test_module.linkFramework("CoreFoundation", .{});
    const tests = b.addTest(.{ .root_module = test_module });
    const test_run = b.addRunArtifact(tests);
    // Source profiles, checked-in models and process fixtures are runtime inputs.
    // Cache compilation, but rerun admission checks when those inputs change.
    test_run.has_side_effects = true;
    const test_step = b.step("test", "Run native translation, admission and tutorial regressions");
    test_step.dependOn(&test_run.step);
    const ziglings_upstream = b.step("ziglings-upstream", "Run the pinned upstream 038 and 054 corrections with Zig 0.17.1");
    const upstream = @import("examples/ziglings/upstream.zig");
    const upstream_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("examples/ziglings/upstream.zig"),
        .target = target,
        .optimize = optimize,
    }) });
    const upstream_tests_run = b.addRunArtifact(upstream_tests);
    ziglings_upstream.dependOn(&upstream_tests_run.step);
    test_step.dependOn(ziglings_upstream);
    for ([_]struct { exercise: upstream.Exercise, name: []const u8, expected: []const u8 }{
        .{ .exercise = .characters, .name = "038_structs2", .expected = "Character 1 - G:20 H:100 XP:10\nCharacter 2 - G:10 H:100 XP:20\n" },
        .{ .exercise = .pointers, .name = "054_manypointers", .expected = "Memory is a resource.\n" },
    }) |exercise| {
        const source = b.addWriteFiles().add(b.fmt("{s}.zig", .{exercise.name}), upstream.corrected(b.allocator, exercise.exercise) catch @panic("upstream correction changed"));
        const native = b.addExecutable(.{ .name = exercise.name, .root_module = b.createModule(.{ .root_source_file = source, .target = target, .optimize = optimize }) });
        const run_exercise = b.addRunArtifact(native);
        run_exercise.expectStdErrEqual(exercise.expected);
        ziglings_upstream.dependOn(&run_exercise.step);
    }
    const ziglings_step = b.step("ziglings", "Run pinned exercises and check initialization and slice contracts");
    ziglings_step.dependOn(ziglings_upstream);
    const ziglings_native = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("examples/ziglings/tests.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "kernels", .module = b.createModule(.{ .root_source_file = b.path("examples/ziglings/ziglings.zig"), .target = target, .optimize = optimize }) },
            .{ .name = "zean", .module = module },
        },
    }) });
    const ziglings_native_run = b.addRunArtifact(ziglings_native);
    ziglings_native_run.has_side_effects = true;
    test_step.dependOn(&ziglings_native_run.step);
    ziglings_step.dependOn(&ziglings_native_run.step);
    const counter_step = b.step("counter", "Check the counter lifecycle, overflow witness and universal u32 proof");
    const counter_run_step = b.step("counter-run", "Run the working byte and u32 tutorial counters");
    var previous_counter_run: ?*std.Build.Step = null;
    for ([_]struct { name: []const u8, module: []const u8, step: u8, wide: bool = false, broken: bool = false }{
        .{ .name = "v1", .module = "V1", .step = 1 },
        .{ .name = "v2", .module = "V2", .step = 2 },
        .{ .name = "broken", .module = "Broken", .step = 2, .broken = true },
        .{ .name = "u32", .module = "Wide", .step = 2, .wide = true },
    }) |example| {
        const source_path = b.fmt("examples/counter/{s}/counter.zig", .{example.name});
        const counter_module = b.createModule(.{ .root_source_file = b.path(source_path), .target = target, .optimize = optimize });
        const example_options = b.addOptions();
        example_options.addOption([]const u8, "version_name", example.name);
        example_options.addOption(u8, "step", example.step);
        example_options.addOption(bool, "wide", example.wide);
        example_options.addOption([]const u8, "source_path", source_path);
        example_options.addOption([]const u8, "generated_path", b.fmt("lean/Compiler/Tutorial/Counter/{s}/Generated.lean", .{example.module}));
        const imports: []const std.Build.Module.Import = &.{
            .{ .name = "counter", .module = counter_module },
            .{ .name = "example_options", .module = example_options.createModule() },
            .{ .name = "zean", .module = module },
        };
        const native = b.addTest(.{ .root_module = b.createModule(.{
            .root_source_file = b.path(if (example.broken) "examples/counter/identity.zig" else "examples/counter/tests.zig"),
            .target = target,
            .optimize = optimize,
            .imports = imports,
        }) });
        const native_run = b.addRunArtifact(native);
        // These tests read source/generated files at runtime, including comment changes.
        native_run.has_side_effects = true;
        test_step.dependOn(&native_run.step);
        counter_step.dependOn(&native_run.step);
        if (example.broken) continue;
        const example_exe = b.addExecutable(.{ .name = b.fmt("counter-{s}", .{example.name}), .root_module = b.createModule(.{
            .root_source_file = b.path("examples/counter/run.zig"),
            .target = target,
            .optimize = optimize,
            .imports = imports,
        }) });
        const example_run = b.addRunArtifact(example_exe);
        if (previous_counter_run) |previous| example_run.step.dependOn(previous);
        counter_run_step.dependOn(&example_run.step);
        previous_counter_run = &example_run.step;
    }
    const buffer_step = b.step("buffer", "Check buffer updates, source identities and memory-safety proofs");
    const buffer_run_step = b.step("buffer-run", "Run the working buffer replacement examples");
    var previous_buffer_run: ?*std.Build.Step = null;
    for ([_]struct { name: []const u8, module: []const u8, broken: bool = false }{
        .{ .name = "v1", .module = "V1" },
        .{ .name = "v2", .module = "V2" },
        .{ .name = "broken", .module = "Broken", .broken = true },
    }) |example| {
        const source_path = b.fmt("examples/buffer/{s}/buffer.zig", .{example.name});
        const buffer_module = b.createModule(.{ .root_source_file = b.path(source_path), .target = target, .optimize = optimize });
        const example_options = b.addOptions();
        example_options.addOption([]const u8, "version_name", example.name);
        example_options.addOption([]const u8, "source_path", source_path);
        example_options.addOption([]const u8, "generated_path", b.fmt("lean/Compiler/Tutorial/Buffer/{s}/Generated.lean", .{example.module}));
        const imports: []const std.Build.Module.Import = &.{
            .{ .name = "buffer", .module = buffer_module },
            .{ .name = "example_options", .module = example_options.createModule() },
            .{ .name = "zean", .module = module },
        };
        const native = b.addTest(.{ .root_module = b.createModule(.{
            .root_source_file = b.path(if (example.broken) "examples/buffer/identity.zig" else "examples/buffer/tests.zig"),
            .target = target,
            .optimize = optimize,
            .imports = imports,
        }) });
        const native_run = b.addRunArtifact(native);
        native_run.has_side_effects = true;
        test_step.dependOn(&native_run.step);
        buffer_step.dependOn(&native_run.step);
        if (example.broken) continue;
        const example_exe = b.addExecutable(.{ .name = b.fmt("buffer-{s}", .{example.name}), .root_module = b.createModule(.{
            .root_source_file = b.path("examples/buffer/run.zig"),
            .target = target,
            .optimize = optimize,
            .imports = imports,
        }) });
        const example_run = b.addRunArtifact(example_exe);
        if (previous_buffer_run) |previous| example_run.step.dependOn(previous);
        buffer_run_step.dependOn(&example_run.step);
        previous_buffer_run = &example_run.step;
    }
    const copy_step = b.step("copy", "Check the copy loop, helper contracts and native controls");
    const copy_module = b.createModule(.{ .root_source_file = b.path("examples/copy/copy.zig"), .target = target, .optimize = optimize });
    const copy_native = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("examples/copy/tests.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "copy", .module = copy_module }, .{ .name = "zean", .module = module } },
    }) });
    const copy_native_run = b.addRunArtifact(copy_native);
    copy_native_run.has_side_effects = true;
    test_step.dependOn(&copy_native_run.step);
    copy_step.dependOn(&copy_native_run.step);
    const calls_step = b.step("calls", "Check captured direct-call contracts and native controls");
    const calls_module = b.createModule(.{ .root_source_file = b.path("examples/calls/calls.zig"), .target = target, .optimize = optimize });
    const calls_native = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("examples/calls/tests.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "calls", .module = calls_module }, .{ .name = "zean", .module = module } },
    }) });
    const calls_native_run = b.addRunArtifact(calls_native);
    calls_native_run.has_side_effects = true;
    calls_step.dependOn(&calls_native_run.step);
    test_step.dependOn(&calls_native_run.step);
    const replace_step = b.step("stdlib-replace", "Check an unchanged standard-library specialization and its proof controls");
    const replace_options = b.addOptions();
    replace_options.addOptionPathUntracked("zig_lib", std.Build.LazyPath.zig_lib);
    const replace_native = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("examples/stdlib_replace/tests.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "component", .module = b.createModule(.{ .root_source_file = b.path("examples/stdlib_replace/replace.zig"), .target = target, .optimize = optimize }) },
            .{ .name = "zean", .module = module },
            .{ .name = "example_options", .module = replace_options.createModule() },
        },
    }) });
    const replace_native_run = b.addRunArtifact(replace_native);
    replace_native_run.has_side_effects = true;
    test_step.dependOn(&replace_native_run.step);
    replace_step.dependOn(&replace_native_run.step);
    const lake = b.option([]const u8, "lake", "Lake executable matching lean-toolchain; default uses the pinned elan toolchain");
    const publication = b.step("atomic-publication", "Run the dispatch-table tests and check the release/acquire proof and counterexamples");
    const publication_check = publicationChecker(b, executable, lake);
    publication_check.addPassthruArgs();
    b.step("atomic-publication-check", "Check that the captured AIR for publish and readEntry matches the dispatch-table model").dependOn(&publication_check.step);
    const publication_tests = b.addRunArtifact(b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("examples/atomic_publication/tests.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "zean", .module = module }},
    }) }));
    publication.dependOn(&publication_tests.step);
    test_step.dependOn(&publication_tests.step);
    publication.dependOn(&leanBuild(b, lake, &.{ "Compiler.Tests.ZigAir.AtomicPublicationControls", "Compiler.ZigAir.CapturedPublication" }).step);
    const lean = if (lake) |path| b.addSystemCommand(&.{ path, "build", "Contract", "Compiler" }) else b.addSystemCommand(&.{ "elan", "run", lean_toolchain, "lake", "build", "Contract", "Compiler" });
    lean.setEnvironmentVariable("LEAN_NUM_THREADS", "2");
    const core_lean = leanBuild(b, lake, &.{"Compiler.ZigAir.Verify.Core"});
    b.step("lean-core", "Check the core finite and loop verifier without optional domains").dependOn(&core_lean.step);
    const selected_lean = leanBuild(b, lake, &.{b.option([]const u8, "lean-module", "Lean module for the lean-module development check") orelse "Compiler.ZigAir.Verify.Core"});
    b.step("lean-module", "Check one Lean module and its dependencies with two workers").dependOn(&selected_lean.step);
    const framework_lean = leanScope(b, lake, &.{"Compiler/ZigAir"}) catch @panic("cannot enumerate Lean framework");
    b.step("lean-framework", "Check all reusable semantics, verification domains and correspondence rules").dependOn(&framework_lean.step);
    const examples_lean = leanScope(b, lake, &.{ "Compiler/Tutorial", "Compiler/Components" }) catch @panic("cannot enumerate Lean examples");
    b.step("lean-examples", "Check tutorial and standard-library proof clients").dependOn(&examples_lean.step);
    const regressions_lean = leanScope(b, lake, &.{ "Compiler/Captures", "Compiler/Cases", "Compiler/Tests", "Compiler/Baselines" }) catch @panic("cannot enumerate Lean regressions");
    b.step("lean-regressions", "Check retained captures, case studies, controls and historical baselines").dependOn(&regressions_lean.step);
    const declaration_source = b.addWriteFiles().add("DeclarationEncodingTests.lean", @import("test/lean/declaration_encoding.zig").source);
    const declaration_checks = if (lake) |path| b.addSystemCommand(&.{ path, "env", "lean" }) else b.addSystemCommand(&.{ "elan", "run", lean_toolchain, "lake", "env", "lean" });
    declaration_checks.addFileArg(declaration_source);
    // Lake manages the imported modules outside Zig's file cache.
    declaration_checks.has_side_effects = true;
    declaration_checks.setEnvironmentVariable("LEAN_NUM_THREADS", "2");
    declaration_checks.step.dependOn(&lean.step);
    b.step("lean", "Check the full Lean library and admission controls with two workers").dependOn(&declaration_checks.step);
    const benchmark = b.addRunArtifact(executable);
    benchmark.addArg("benchmark");
    if (lake) |path| benchmark.addArgs(&.{ "--lake", path });
    benchmark.addPassthruArgs();
    benchmark.has_side_effects = true;
    benchmark.step.dependOn(&declaration_checks.step);
    b.step("benchmark", "Measure serial proof re-elaboration with warm dependencies and retained receipts").dependOn(&benchmark.step);
    const wp_lean = if (lake) |path| b.addSystemCommand(&.{ path, "build", "Compiler.Tests.ZigAir.MemoryFiniteWPControls", "Compiler.Tests.ZigAir.MemoryResourceControls", "Compiler.Tests.ZigAir.MemoryCallControls", "Compiler.Tests.ZigAir.ControlWPControls", "Compiler.Tests.ZigAir.MemoryVerificationControls", "Compiler.Tests.ZigAir.ControlFragmentWPControls" }) else b.addSystemCommand(&.{ "elan", "run", lean_toolchain, "lake", "build", "Compiler.Tests.ZigAir.MemoryFiniteWPControls", "Compiler.Tests.ZigAir.MemoryResourceControls", "Compiler.Tests.ZigAir.MemoryCallControls", "Compiler.Tests.ZigAir.ControlWPControls", "Compiler.Tests.ZigAir.MemoryVerificationControls", "Compiler.Tests.ZigAir.ControlFragmentWPControls" });
    wp_lean.setEnvironmentVariable("LEAN_NUM_THREADS", "2");
    b.step("wp-proofs", "Check interpreter-backed weakest preconditions and fault/effect controls").dependOn(&wp_lean.step);
    // Replay builds the selected client's exact import set. Full release checks
    // still run the complete library and admission controls before fresh captures.
    const regenerate = b.addRunArtifact(executable);
    regenerate.addArg("counter-regenerate");
    if (lake) |path| regenerate.addArgs(&.{ "--lake", path });
    regenerate.addPassthruArgs();
    regenerate.has_side_effects = true;
    b.step("counter-regenerate", "Capture all tutorial stages and replay handwritten proofs in a new evidence bundle").dependOn(&regenerate.step);
    const buffer_regenerate = b.addRunArtifact(executable);
    buffer_regenerate.addArg("buffer-regenerate");
    if (lake) |path| buffer_regenerate.addArgs(&.{ "--lake", path });
    buffer_regenerate.addPassthruArgs();
    buffer_regenerate.has_side_effects = true;
    b.step("buffer-regenerate", "Capture buffer stages and replay safety proofs and negative controls in a new evidence bundle").dependOn(&buffer_regenerate.step);
    const copy_regenerate = b.addRunArtifact(executable);
    copy_regenerate.addArg("copy-regenerate");
    if (lake) |path| copy_regenerate.addArgs(&.{ "--lake", path });
    copy_regenerate.addPassthruArgs();
    copy_regenerate.has_side_effects = true;
    b.step("copy-regenerate", "Capture both copy roots and replay loop and helper contracts in a new evidence bundle").dependOn(&copy_regenerate.step);
    const calls_regenerate = b.addRunArtifact(executable);
    calls_regenerate.addArg("calls-regenerate");
    if (lake) |path| calls_regenerate.addArgs(&.{ "--lake", path });
    calls_regenerate.addPassthruArgs();
    calls_regenerate.has_side_effects = true;
    b.step("calls-regenerate", "Capture the direct-call closure and replay its compositional proof").dependOn(&calls_regenerate.step);
    const replace_regenerate = b.addRunArtifact(executable);
    replace_regenerate.addArg("stdlib-replace-regenerate");
    if (lake) |path| replace_regenerate.addArgs(&.{ "--lake", path });
    replace_regenerate.addPassthruArgs();
    replace_regenerate.has_side_effects = true;
    b.step("stdlib-replace-regenerate", "Capture, certify and verify the unchanged std.mem.replaceScalar(u32) specialization").dependOn(&replace_regenerate.step);
    const ziglings_regenerate = b.addRunArtifact(executable);
    ziglings_regenerate.addArg("ziglings-regenerate");
    if (lake) |path| ziglings_regenerate.addArgs(&.{ "--lake", path });
    ziglings_regenerate.addPassthruArgs();
    ziglings_regenerate.has_side_effects = true;
    b.step("ziglings-regenerate", "Capture Ziglings kernels and replay contracts and rejection controls").dependOn(&ziglings_regenerate.step);
    const emitted_exe = b.addExecutable(.{ .name = "emitted-lean", .root_module = b.createModule(.{
        .root_source_file = b.path("test/native/emitted_lean.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "zean", .module = module }},
    }) });
    const emitted = b.addRunArtifact(emitted_exe);
    emitted.addArgs(if (lake) |path| &.{ path, "env", "lean" } else &.{ "elan", "run", lean_toolchain, "lake", "env", "lean" });
    emitted.has_side_effects = true;
    // Serialize Lean processes, including their two worker pools.
    emitted.step.dependOn(&declaration_checks.step);
    b.step("emitted-lean", "Compile actual emitted AIR, hash, source and layout controls").dependOn(&emitted.step);
    const emitted_control = b.addRunArtifact(emitted_exe);
    emitted_control.addArgs(&.{ "--only", b.option([]const u8, "emitted-control", "Single control for the emitted-control development check") orelse "certificate" });
    emitted_control.addArgs(if (lake) |path| &.{ path, "env", "lean" } else &.{ "elan", "run", lean_toolchain, "lake", "env", "lean" });
    emitted_control.has_side_effects = true;
    emitted_control.step.dependOn(&leanBuild(b, lake, &.{ "Compiler.ZigAir.CapturedScalar", "Compiler.ZigAir.CapturedNestedCalls", "Compiler.ZigAir.CapturedCallMachine" }).step);
    b.step("emitted-control", "Compile one emitted control and its checked decoder dependencies").dependOn(&emitted_control.step);
    const counter_lean = if (lake) |path| b.addSystemCommand(&.{ path, "build", "Compiler.Tutorial.Counter.Comparison" }) else b.addSystemCommand(&.{ "elan", "run", lean_toolchain, "lake", "build", "Compiler.Tutorial.Counter.Comparison" });
    counter_lean.setEnvironmentVariable("LEAN_NUM_THREADS", "2");
    b.step("counter-proofs", "Check the handwritten counter proofs and update comparison").dependOn(&counter_lean.step);
    const stale = rejectExampleProof(b, lake, "examples/counter/StaleProof.lean", &counter_lean.step);
    b.step("counter-stale-proof", "Check that the old counter contract fails for the updated model").dependOn(&stale.step);
    const broken = rejectExampleProof(b, lake, "examples/counter/BrokenProof.lean", &stale.step);
    b.step("counter-broken-proof", "Check that Lean rejects the overflowing intermediate counter").dependOn(&broken.step);
    counter_step.dependOn(&broken.step);
    const buffer_lean = if (lake) |path| b.addSystemCommand(&.{ path, "build", "Compiler.Tutorial.Buffer.Broken.Proofs" }) else b.addSystemCommand(&.{ "elan", "run", lean_toolchain, "lake", "build", "Compiler.Tutorial.Buffer.Broken.Proofs" });
    buffer_lean.setEnvironmentVariable("LEAN_NUM_THREADS", "2");
    b.step("buffer-proofs", "Prove buffer memory safety, functional behavior and the off-by-one counterexamples").dependOn(&buffer_lean.step);
    const buffer_broken = rejectExampleProof(b, lake, "examples/buffer/BrokenProof.lean", &buffer_lean.step);
    const buffer_frame = rejectExampleProof(b, lake, "examples/buffer/FrameProof.lean", &buffer_broken.step);
    buffer_step.dependOn(&buffer_frame.step);
    const copy_lean = if (lake) |path| b.addSystemCommand(&.{ path, "build", "Compiler.Tutorial.Copy.Proofs", "Compiler.Tutorial.Copy.Controls" }) else b.addSystemCommand(&.{ "elan", "run", lean_toolchain, "lake", "build", "Compiler.Tutorial.Copy.Proofs", "Compiler.Tutorial.Copy.Controls" });
    copy_lean.setEnvironmentVariable("LEAN_NUM_THREADS", "2");
    b.step("copy-proofs", "Check generic verification of the copy loop and inline helper").dependOn(&copy_lean.step);
    const copy_init = rejectExampleProof(b, lake, "examples/copy/InitializationProof.lean", &copy_lean.step);
    const copy_bounds = rejectExampleProof(b, lake, "examples/copy/BoundsProof.lean", &copy_init.step);
    const copy_overlap = rejectExampleProof(b, lake, "examples/copy/OverlapProof.lean", &copy_bounds.step);
    copy_step.dependOn(&copy_overlap.step);
    const calls_lean = if (lake) |path| b.addSystemCommand(&.{ path, "build", "Compiler.Tutorial.Calls.Proofs" }) else b.addSystemCommand(&.{ "elan", "run", lean_toolchain, "lake", "build", "Compiler.Tutorial.Calls.Proofs" });
    calls_lean.setEnvironmentVariable("LEAN_NUM_THREADS", "2");
    b.step("calls-proofs", "Check compositional contracts for the captured call chain").dependOn(&calls_lean.step);
    const calls_bounds = rejectExampleProof(b, lake, "examples/calls/BoundsProof.lean", &calls_lean.step);
    calls_step.dependOn(&calls_bounds.step);
    const replace_lean = if (lake) |path| b.addSystemCommand(&.{ path, "build", "Compiler.Components.Replace.Proofs", "Compiler.Components.Replace.Controls" }) else b.addSystemCommand(&.{ "elan", "run", lean_toolchain, "lake", "build", "Compiler.Components.Replace.Proofs", "Compiler.Components.Replace.Controls" });
    replace_lean.setEnvironmentVariable("LEAN_NUM_THREADS", "2");
    b.step("stdlib-replace-proofs", "Check the standard-library loop contract and concrete fault controls").dependOn(&replace_lean.step);
    const replace_init = rejectExampleProof(b, lake, "examples/stdlib_replace/InitializationProof.lean", &replace_lean.step);
    const replace_permission = rejectExampleProof(b, lake, "examples/stdlib_replace/PermissionProof.lean", &replace_init.step);
    replace_step.dependOn(&replace_permission.step);
    const ziglings_lean = if (lake) |path| b.addSystemCommand(&.{ path, "build", "Compiler.Tutorial.Ziglings.Proofs", "Compiler.Tutorial.Ziglings.Controls" }) else b.addSystemCommand(&.{ "elan", "run", lean_toolchain, "lake", "build", "Compiler.Tutorial.Ziglings.Proofs", "Compiler.Tutorial.Ziglings.Controls" });
    ziglings_lean.setEnvironmentVariable("LEAN_NUM_THREADS", "2");
    b.step("ziglings-proofs", "Check the Ziglings initialization and byte-slice proofs").dependOn(&ziglings_lean.step);
    const ziglings_init = rejectExampleProof(b, lake, "examples/ziglings/InitializationProof.lean", &ziglings_lean.step);
    const ziglings_bounds = rejectExampleProof(b, lake, "examples/ziglings/BoundsProof.lean", &ziglings_init.step);
    ziglings_step.dependOn(&ziglings_bounds.step);
    const fmt = b.addFmt(.{ .paths = b.pathList(&.{ "build.zig", "src", "lean/zig_air", "test/native", "test/lean", "examples/counter", "examples/buffer", "examples/copy", "examples/calls", "examples/client", "examples/allocator", "examples/stdlib_replace", "examples/compatibility", "examples/ziglings/upstream.zig", "examples/ziglings/tests.zig", "examples/ziglings/ziglings.zig" }), .check = true });
    b.step("fmt-check", "Check Zig formatting").dependOn(&fmt.step);
    const check = b.step("check", "Run portable release checks, including freshly emitted Lean");
    check.dependOn(&fmt.step);
    check.dependOn(&executable.step);
    check.dependOn(test_step);
    check.dependOn(&emitted.step);
    const check_stale = rejectExampleProof(b, lake, "examples/counter/StaleProof.lean", &emitted.step);
    const check_broken = rejectExampleProof(b, lake, "examples/counter/BrokenProof.lean", &check_stale.step);
    const check_buffer_broken = rejectExampleProof(b, lake, "examples/buffer/BrokenProof.lean", &check_broken.step);
    const check_buffer_frame = rejectExampleProof(b, lake, "examples/buffer/FrameProof.lean", &check_buffer_broken.step);
    const check_copy_init = rejectExampleProof(b, lake, "examples/copy/InitializationProof.lean", &check_buffer_frame.step);
    const check_copy_bounds = rejectExampleProof(b, lake, "examples/copy/BoundsProof.lean", &check_copy_init.step);
    const check_copy_overlap = rejectExampleProof(b, lake, "examples/copy/OverlapProof.lean", &check_copy_bounds.step);
    const check_calls_bounds = rejectExampleProof(b, lake, "examples/calls/BoundsProof.lean", &check_copy_overlap.step);
    const check_replace_init = rejectExampleProof(b, lake, "examples/stdlib_replace/InitializationProof.lean", &check_calls_bounds.step);
    const check_replace_permission = rejectExampleProof(b, lake, "examples/stdlib_replace/PermissionProof.lean", &check_replace_init.step);
    const check_ziglings_init = rejectExampleProof(b, lake, "examples/ziglings/InitializationProof.lean", &check_replace_permission.step);
    const check_ziglings_bounds = rejectExampleProof(b, lake, "examples/ziglings/BoundsProof.lean", &check_ziglings_init.step);
    check.dependOn(&check_ziglings_bounds.step);
    const release_output = b.option([]const u8, "release-output", "New external evidence directory for release-check");
    const compatibility = b.step("compatibility-check", "Check held-out call rejections and certified fixed-length slice admission");
    var compatibility_first: ?*std.Build.Step = null;
    if (toolchain_report != null and release_output != null) {
        const probe = b.addRunArtifact(executable);
        const capture_path = b.fmt("{s}/compatibility/ascii", .{release_output.?});
        probe.addArgs(&.{ "capture", "--toolchain", toolchain_report.?, "--source" });
        probe.addFileArg(b.path("examples/compatibility/ascii_driver.zig"));
        probe.addArgs(&.{ "--root", "ascii_driver.upper", "--root", "ascii_driver.lower", "--output", capture_path });
        probe.has_side_effects = true;
        compatibility_first = &probe.step;
        var previous: *std.Build.Step = &probe.step;
        for ([_][]const u8{ "upper", "lower" }) |name| {
            const rejection = b.addRunArtifact(executable);
            rejection.addArgs(&.{ "translate", "--capture", b.fmt("{s}/report.json", .{capture_path}), "--root", b.fmt("ascii_driver.{s}", .{name}), "--profile", "loops", "--output", b.fmt("{s}/compatibility/{s}-model", .{ release_output.?, name }) });
            rejection.expectExitCode(1);
            rejection.expectStdErrMatch("unsupported AIR operation: call");
            rejection.has_side_effects = true;
            rejection.step.dependOn(previous);
            previous = &rejection.step;
        }
        const fixed_probe = b.addRunArtifact(executable);
        const fixed_capture = b.fmt("{s}/compatibility/ziglings-slice", .{release_output.?});
        fixed_probe.addArgs(&.{ "capture", "--toolchain", toolchain_report.?, "--source" });
        fixed_probe.addFileArg(b.path("examples/compatibility/ziglings_slice.zig"));
        fixed_probe.addArgs(&.{ "--root", "ziglings_slice.select", "--output", fixed_capture });
        fixed_probe.has_side_effects = true;
        fixed_probe.step.dependOn(previous);
        const fixed_translation = b.addRunArtifact(executable);
        fixed_translation.addArgs(&.{ "translate", "--capture", b.fmt("{s}/report.json", .{fixed_capture}), "--root", "ziglings_slice.select", "--profile", "memory", "--output", b.fmt("{s}/compatibility/ziglings-slice-model", .{release_output.?}), "--certify", b.fmt("{s}/compatibility/ziglings-slice-certificate", .{release_output.?}) });
        if (lake) |path| fixed_translation.addArgs(&.{ "--lake", path });
        fixed_translation.has_side_effects = true;
        fixed_translation.step.dependOn(&fixed_probe.step);
        compatibility.dependOn(&fixed_translation.step);
    } else {
        compatibility.dependOn(&b.addFail("compatibility-check requires -Dtoolchain-report and -Drelease-output (a new external directory)").step);
    }
    const release = b.step("release-check", "Check source admission, emitted Lean, fresh native audits and tutorial proof replay");
    if (toolchain_report == null or release_output == null) {
        release.dependOn(&b.addFail("release-check requires -Dtoolchain-report and -Drelease-output; use check for portable checks").step);
    } else {
        const audit = b.addRunArtifact(executable);
        audit.addArgs(&.{ "audit", "--profile", "memory", "--toolchain", toolchain_report.?, "--output", b.fmt("{s}/memory", .{release_output.?}) });
        audit.has_side_effects = true;
        audit.step.dependOn(check);
        const replay = b.addRunArtifact(executable);
        replay.addArgs(&.{ "counter-regenerate", "--toolchain", toolchain_report.?, "--output", b.fmt("{s}/counter", .{release_output.?}), "--check" });
        if (lake) |path| replay.addArgs(&.{ "--lake", path });
        replay.has_side_effects = true;
        replay.step.dependOn(&audit.step);
        const buffer_replay = b.addRunArtifact(executable);
        buffer_replay.addArgs(&.{ "buffer-regenerate", "--toolchain", toolchain_report.?, "--output", b.fmt("{s}/buffer", .{release_output.?}), "--check" });
        if (lake) |path| buffer_replay.addArgs(&.{ "--lake", path });
        buffer_replay.has_side_effects = true;
        buffer_replay.step.dependOn(&replay.step);
        const copy_replay = b.addRunArtifact(executable);
        copy_replay.addArgs(&.{ "copy-regenerate", "--toolchain", toolchain_report.?, "--output", b.fmt("{s}/copy", .{release_output.?}), "--check" });
        if (lake) |path| copy_replay.addArgs(&.{ "--lake", path });
        copy_replay.has_side_effects = true;
        copy_replay.step.dependOn(&buffer_replay.step);
        const calls_replay = b.addRunArtifact(executable);
        calls_replay.addArgs(&.{ "calls-regenerate", "--toolchain", toolchain_report.?, "--output", b.fmt("{s}/calls", .{release_output.?}), "--check" });
        if (lake) |path| calls_replay.addArgs(&.{ "--lake", path });
        calls_replay.has_side_effects = true;
        calls_replay.step.dependOn(&copy_replay.step);
        const recursive = b.addRunArtifact(executable);
        recursive.addArgs(&.{ "verify-client", "--manifest" });
        recursive.addFileArg(b.path("examples/client/recursive/client.json"));
        recursive.addArgs(&.{ "--toolchain", toolchain_report.?, "--output", b.fmt("{s}/recursive", .{release_output.?}) });
        if (lake) |path| recursive.addArgs(&.{ "--lake", path });
        recursive.has_side_effects = true;
        recursive.step.dependOn(&calls_replay.step);
        const replace_replay = b.addRunArtifact(executable);
        replace_replay.addArgs(&.{ "stdlib-replace-regenerate", "--toolchain", toolchain_report.?, "--output", b.fmt("{s}/stdlib-replace", .{release_output.?}), "--check" });
        if (lake) |path| replace_replay.addArgs(&.{ "--lake", path });
        replace_replay.has_side_effects = true;
        replace_replay.step.dependOn(&recursive.step);
        const ziglings_replay = b.addRunArtifact(executable);
        ziglings_replay.addArgs(&.{ "ziglings-regenerate", "--toolchain", toolchain_report.?, "--output", b.fmt("{s}/ziglings", .{release_output.?}), "--check" });
        if (lake) |path| ziglings_replay.addArgs(&.{ "--lake", path });
        ziglings_replay.has_side_effects = true;
        ziglings_replay.step.dependOn(&replace_replay.step);
        compatibility_first.?.dependOn(&ziglings_replay.step);
        const publication_dir = b.fmt("{s}/atomic-publication/capture", .{release_output.?});
        const publication_capture = b.addRunArtifact(executable);
        publication_capture.addArgs(&.{ "capture", "--toolchain", toolchain_report.?, "--source" });
        publication_capture.addFileArg(b.path("examples/atomic_publication/publication.zig"));
        publication_capture.addArgs(&.{ "--root", "publication.publish", "--root", "publication.readEntry", "--output", publication_dir });
        publication_capture.has_side_effects = true;
        publication_capture.step.dependOn(compatibility);
        const publication_replay = publicationChecker(b, executable, lake);
        publication_replay.addArgs(&.{ "--capture", b.fmt("{s}/report.json", .{publication_dir}), "--output", b.fmt("{s}/atomic-publication/proof", .{release_output.?}) });
        publication_replay.step.dependOn(&publication_capture.step);
        release.dependOn(&publication_replay.step);
    }
}

fn publicationChecker(b: *std.Build, executable: *std.Build.Step.Compile, lake: ?[]const u8) *std.Build.Step.Run {
    const run = b.addRunArtifact(executable);
    run.addArg("atomic-publication-check");
    if (lake) |path| run.addArgs(&.{ "--lake", path });
    run.has_side_effects = true;
    return run;
}

fn leanBuild(b: *std.Build, lake: ?[]const u8, modules: []const []const u8) *std.Build.Step.Run {
    const run = if (lake) |path| b.addSystemCommand(&.{ path, "build" }) else b.addSystemCommand(&.{ "elan", "run", lean_toolchain, "lake", "build" });
    run.addArgs(modules);
    run.setEnvironmentVariable("LEAN_NUM_THREADS", "2");
    return run;
}

// Enumerate every module in a development scope, including modules with no
// downstream imports. The full release target retains Lake's complete globs.
fn leanScope(b: *std.Build, lake: ?[]const u8, directories: []const []const u8) !*std.Build.Step.Run {
    const io = b.graph.io;
    var modules: std.ArrayList([]const u8) = .empty;
    for (directories) |directory| {
        const path = try std.fs.path.join(b.allocator, &.{ "lean", directory });
        b.dependOnDirectoryContents(b.path(path));
        var dir = try b.root.openDir(io, path, .{ .iterate = true });
        defer dir.close(io);
        var walker = try dir.walk(b.allocator);
        defer walker.deinit();
        while (try walker.next(io)) |entry| {
            if (entry.kind == .directory) {
                b.dependOnDirectoryContents(b.path(try std.fs.path.join(b.allocator, &.{ path, entry.path })));
            } else if (entry.kind == .file and std.mem.endsWith(u8, entry.path, ".lean")) {
                const name = try std.fs.path.join(b.allocator, &.{ directory, entry.path[0 .. entry.path.len - 5] });
                for (name) |*byte| if (byte.* == '/' or byte.* == '\\') {
                    byte.* = '.';
                };
                try modules.append(b.allocator, name);
            }
        }
    }
    if (modules.items.len == 0) return error.EmptyLeanScope;
    std.mem.sort([]const u8, modules.items, {}, struct {
        fn less(_: void, a: []const u8, c: []const u8) bool {
            return std.mem.lessThan(u8, a, c);
        }
    }.less);
    return leanBuild(b, lake, modules.items);
}

fn rejectExampleProof(b: *std.Build, lake: ?[]const u8, source: []const u8, after: *std.Build.Step) *std.Build.Step.Run {
    const run = if (lake) |path| b.addSystemCommand(&.{ path, "env", "lean" }) else b.addSystemCommand(&.{ "elan", "run", lean_toolchain, "lake", "env", "lean" });
    run.addFileArg(b.path(source));
    run.has_side_effects = true;
    run.setEnvironmentVariable("LEAN_NUM_THREADS", "2");
    run.step.dependOn(after);
    run.expectExitCode(1);
    run.expectStdOutMatch("Tactic `rfl` failed");
    return run;
}

// Sorted path + NUL + lowercase SHA-256 + LF, with '/' path separators.
// These identities are embedded at compilation, including uncommitted changes.
fn treeIdentity(b: *std.Build, directory: []const u8, extra: []const []const u8) !struct { sha256: [64]u8, files: usize } {
    const io = b.graph.io;
    var names: std.ArrayList([]const u8) = .empty;
    try names.appendSlice(b.allocator, extra);
    b.dependOnDirectoryContents(b.path(directory));
    var dir = try b.root.openDir(io, directory, .{ .iterate = true });
    defer dir.close(io);
    var walker = try dir.walk(b.allocator);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        if (entry.kind == .directory) {
            b.dependOnDirectoryContents(b.path(try std.fs.path.join(b.allocator, &.{ directory, entry.path })));
            continue;
        }
        if (entry.kind != .file) return error.UnexpectedIdentityEntry;
        const name = try std.fs.path.join(b.allocator, &.{ directory, entry.path });
        for (name) |*byte| if (byte.* == '\\') {
            byte.* = '/';
        };
        try names.append(b.allocator, name);
    }
    std.mem.sort([]const u8, names.items, {}, struct {
        fn less(_: void, a: []const u8, c: []const u8) bool {
            return std.mem.lessThan(u8, a, c);
        }
    }.less);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    for (names.items) |name| {
        b.dependOnFileContents(b.path(name));
        const bytes = try std.Io.Dir.cwd().readFileAlloc(io, try b.root.joinString(b.allocator, name), b.allocator, .limited(64 * 1024 * 1024));
        var file_hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(bytes, &file_hash, .{});
        hash.update(name);
        hash.update(&.{0});
        hash.update(&std.fmt.bytesToHex(file_hash, .lower));
        hash.update("\n");
        b.allocator.free(bytes);
    }
    return .{ .sha256 = std.fmt.bytesToHex(hash.finalResult(), .lower), .files = names.items.len };
}
