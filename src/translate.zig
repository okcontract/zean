// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const c = @import("common.zig");
const air = @import("air.zig");
const files = @import("files.zig");
const version = @import("root.zig").version;
const revision = @import("root.zig").revision;

pub const Options = struct { capture: []const u8, roots: []const []const u8, output: []const u8, profile: air.Profile = .scalar, namespace: []const u8 = "Zean.Generated", certify: ?[]const u8 = null, environment: ?*const std.process.Environ.Map = null, lake: ?[]const u8 = null, specialized_source: ?[]const u8 = null, declaration_source: ?[]const u8 = null, call_machine: bool = false };
fn namespaceText(ctx: *c.Context, name: []const u8) c.Error![]const u8 {
    try ctx.require(c.identifier(name, true), "invalid Lean namespace");
    var components: std.ArrayList([]const u8) = .empty;
    var parts = std.mem.splitScalar(u8, name, '.');
    // Escaping every component also covers keywords introduced by imports.
    while (parts.next()) |part| try components.append(ctx.allocator, try ctx.fmt("«{s}»", .{part}));
    return std.mem.join(ctx.allocator, ".", components.items);
}
pub fn run(ctx: *c.Context, io: std.Io, options: Options) !c.Value {
    const lean_namespace = try namespaceText(ctx, options.namespace);
    const call_machine = options.profile.hasCalls();
    try ctx.require(!options.call_machine or call_machine, "call-machine emission requires a call profile");
    if (options.certify != null) try ctx.require(options.profile.capabilities().correspondence and options.environment != null, "certification requires a supported profile and an explicit process environment");
    try ctx.require(options.roots.len > 0, "roots must be nonempty and unique");
    for (options.roots, 0..) |root, index| for (options.roots[0..index]) |previous| try ctx.require(!std.mem.eql(u8, root, previous), "roots must be nonempty and unique");
    try ctx.require(!try files.exists(io, options.output), "output directory already exists; use a new directory");
    const captured = try files.readJson(ctx, io, options.capture);
    const report = captured.value;
    try ctx.require(c.tag(report, "schema", "oksolc.fresh-air-capture.v1") and c.tag(report, "status", "captured") and c.flag(report, "captureComplete", true), "capture was not completed");
    try ctx.require(c.tag(report, "zigVersion", version) and c.tag(report, "zigRevision", revision), "capture must identify the pinned Zig 0.17.1 revision");
    const capture_source_sha = try ctx.str(try ctx.field(report, "sourceSha256"));
    try ctx.require(c.isDigest(capture_source_sha), "capture has no valid source identity");
    try ctx.require(options.specialized_source == null or options.declaration_source == null, "choose ordinary declaration or specialization source, not both");
    const declaration_bytes = if (options.declaration_source) |path| try ctx.read(io, path, 64 * 1024 * 1024) else null;
    const specialized_bytes = if (options.specialized_source) |path| try ctx.read(io, path, 64 * 1024 * 1024) else null;
    if (specialized_bytes != null) try ctx.require(options.roots.len == 1 and (options.profile == .memory or options.profile == .loops), "standalone specialization requires one memory/loops root");
    const source_sha = if (specialized_bytes orelse declaration_bytes) |bytes| try ctx.allocator.dupe(u8, &c.digest(bytes)) else capture_source_sha;
    try ctx.require(c.isDigest(source_sha), "capture has no valid source identity");
    var lines: std.ArrayList([]const u8) = .empty;
    try lines.append(ctx.allocator,
        \\/-
        \\Copyright (C) 2026 OKcontract Pte. Ltd.
        \\SPDX-License-Identifier: Apache-2.0
        \\Generated from admitted AIR; do not edit.
        \\Source validity and native refinement require separate evidence.
        \\-/
        \\
    );
    try lines.append(ctx.allocator, try ctx.fmt("-- Source SHA-256: {s}\n-- Capture report SHA-256: {s}\n", .{ source_sha, &c.digest(captured.bytes) }));
    const module = options.profile.module();
    const vocabulary = options.profile.vocabulary();
    if (options.certify != null) try lines.append(ctx.allocator, if (options.profile == .scalar) "import Compiler.ZigAir.CapturedScalar\n" else if (call_machine) "import Compiler.ZigAir.CapturedCallMachine\n" else "import Compiler.ZigAir.Captured\n");
    try lines.append(ctx.allocator, try ctx.fmt("import Compiler.ZigAir.{s}\n\nnamespace {s}\nopen Compiler.ZigAir.{s}\n\n", .{ module, lean_namespace, vocabulary }));
    var functions: c.Value = .{ .object = .empty };
    var identities: std.ArrayList(struct { path: []const u8, sha: []const u8 }) = .empty;
    const entries = try ctx.field(report, "functions");
    var closure = @import("call_closure.zig").Closure.init(ctx, io, options.capture, report);
    defer closure.deinit();
    closure.root_source = options.declaration_source;
    closure.root_bytes = declaration_bytes;
    closure.allow_recursion = options.profile.capabilities().recursive_calls;
    var callees: std.ArrayList(air.Callee) = .empty;
    var machine_names: std.ArrayList([]const u8) = .empty;
    var machine_records: std.ArrayList([]const u8) = .empty;
    var machine_captures: std.ArrayList([]const u8) = .empty;
    if (options.profile.hasCalls()) {
        for (options.roots) |root| try closure.visit(root, null, 0);
        if (closure.allow_recursion) {
            // All indices are in scope before any body references them.
            for (closure.units.items, 0..) |unit, machine_index| {
                const label = try ctx.fmt("FunctionId.{s}", .{unit.name});
                try lines.append(ctx.allocator, try ctx.fmt("def {s} : Nat := {d}\n", .{ label, machine_index }));
                try callees.append(ctx.allocator, .{ .record = unit.record, .declaration = unit.name, .profile = options.profile, .machine_index = machine_index, .machine_label = label });
            }
            try lines.append(ctx.allocator, "\n");
        }
        for (closure.units.items, 0..) |unit, machine_index| {
            const profile: air.Profile = if (closure.allow_recursion or !unit.called) options.profile else if (options.profile == .nested_calls) try @import("call_closure.zig").interpreter(ctx, unit.record, callees.items) else .calls;
            var decoder = try air.Decoder.initWith(ctx, unit.record, profile, .{
                .source_parameters = unit.source_parameters,
                .explicit_type_specialization = unit.source_parameters != null,
                .callees = callees.items,
                .call_machine = call_machine,
            });
            const program = try decoder.program();
            // Instantiated owner names contain compiler-rendered argument text.
            // The manifest retains the full name for every declaration.
            if (c.identifier(unit.root, true))
                try lines.append(ctx.allocator, try ctx.fmt("-- Zig declaration: {s}\n", .{unit.root}));
            const machine_label = if (closure.allow_recursion) callees.items[machine_index].machine_label.? else try ctx.fmt("FunctionId.{s}", .{unit.name});
            if (!closure.allow_recursion) try lines.append(ctx.allocator, try ctx.fmt("def {s} : Nat := {d}\n\n", .{ machine_label, machine_index }));
            try lines.append(ctx.allocator, try ctx.fmt("-- AIR SHA-256: {s}\ndef {s} : Function :=\n{s}\n\n", .{ unit.sha, unit.name, program }));
            {
                try machine_names.append(ctx.allocator, unit.name);
                if (options.certify != null) {
                    const record_name = try ctx.fmt("CapturedRecords.{s}", .{unit.name});
                    try machine_records.append(ctx.allocator, record_name);
                    try machine_captures.append(ctx.allocator, try ctx.fmt("def {s} : Compiler.ZigAir.Captured.Raw :=\n{s}\n\n", .{ record_name, try @import("certificate.zig").lift(ctx, unit.record, 0) }));
                }
            }
            const summary = try ctx.parse(try ctx.json(.{ .declaration = try ctx.fmt("{s}.{s}", .{ options.namespace, unit.name }), .airSha256 = unit.sha, .sourceSha256 = try ctx.field(unit.record, "sourceSha256"), .callee = unit.called, .interpreter = "call-machine", .machineIndex = machine_index, .configuration = try ctx.field(unit.record, "configuration") }));
            try functions.object.put(ctx.allocator, unit.root, summary);
            try identities.append(ctx.allocator, .{ .path = unit.path, .sha = unit.sha });
            if (!closure.allow_recursion and unit.called) try callees.append(ctx.allocator, .{ .record = unit.record, .declaration = unit.name, .profile = profile, .machine_index = machine_index, .machine_label = machine_label });
        }
        {
            try lines.append(ctx.allocator, try ctx.fmt("def functions : Program := [{s}]\n\n", .{try std.mem.join(ctx.allocator, ", ", machine_names.items)}));
            if (options.certify != null) {
                try lines.append(ctx.allocator, "-- Captured AIR and independent decoding certificate.\n\n");
                try lines.appendSlice(ctx.allocator, machine_captures.items);
            }
            if (options.certify != null) {
                const decoder = if (closure.allow_recursion) "decodeRecursive" else "decode";
                try lines.append(ctx.allocator, try ctx.fmt("set_option maxRecDepth 8192 in\nset_option maxHeartbeats 2000000 in\ntheorem functions_correspondence :\n  Compiler.ZigAir.CapturedCallMachine.{s} [{s}] = some functions := by rfl'\n\n", .{ decoder, try std.mem.join(ctx.allocator, ", ", machine_records.items) }));
            }
        }
    }
    var standalone: std.StringArrayHashMapUnmanaged([]const u8) = .empty;
    if (!options.profile.hasCalls()) for (options.roots) |root| {
        const start = if (std.mem.lastIndexOfScalar(u8, root, '.')) |index| index + 1 else 0;
        const component = root[start..];
        const name = try ctx.fmt("fn_{s}", .{component});
        try ctx.require(c.identifier(component, false) and !standalone.contains(name), "invalid or duplicate generated function name");
        try standalone.put(ctx.allocator, name, root);
    };
    for (standalone.keys(), standalone.values()) |name, root| {
        const entry = try ctx.field(entries, root);
        if (specialized_bytes == null and declaration_bytes == null) try ctx.require(c.flag(entry, "requested", true), "root was not requested in the capture");
        const path = try capturedPath(ctx, io, options.capture, entry);
        const sha = try ctx.str(try ctx.field(entry, "sha256"));
        const record_file = try files.readJson(ctx, io, path);
        try ctx.require(c.isDigest(sha) and std.mem.eql(u8, &c.digest(record_file.bytes), sha), "AIR identity mismatch");
        const record = record_file.value;
        try ctx.require(c.tag(record, "name", root) and c.tag(record, "sourceSha256", source_sha), "AIR root/source identity mismatch");
        if (declaration_bytes) |bytes| try @import("declaration_source.zig").select(ctx, record, try ctx.field(report, "sourceFiles"), std.fs.path.basename(options.declaration_source.?), bytes);
        const mapping = if (specialized_bytes) |bytes| try @import("specialized_source.zig").select(ctx, record, std.fs.path.basename(options.specialized_source.?), bytes) else null;
        var decoder = try air.Decoder.initWith(ctx, record, options.profile, .{ .source_parameters = if (mapping) |mapped| mapped.indices else null, .explicit_type_specialization = mapping != null });
        const program = try decoder.program();
        try lines.append(ctx.allocator, try ctx.fmt("-- AIR SHA-256: {s}\ndef {s} : Program{s} :=\n{s}\n\n", .{ sha, name, if (options.profile.hasLoops()) " true" else "", program }));
        if (options.certify != null) {
            const certificate = if (options.profile == .scalar) try @import("certificate.zig").scalarDeclaration(ctx, record, name) else try @import("certificate.zig").declaration(ctx, record, name, options.profile.hasLoops());
            // Preserve existing certificate names wherever the source leaves them available.
            const collision = standalone.contains(try ctx.fmt("{s}_captured", .{name})) or standalone.contains(try ctx.fmt("{s}_correspondence", .{name}));
            try lines.append(ctx.allocator, if (collision) try ctx.fmt("namespace Certificate.{s}\n{s}\nend Certificate.{s}\n\n", .{ name, certificate, name }) else certificate);
        }
        var body_instructions: usize = 0;
        for (decoder.visited) |visited| if (visited) {
            body_instructions += 1;
        };
        const summary = try ctx.parse(try ctx.json(.{ .declaration = try ctx.fmt("{s}.{s}", .{ options.namespace, name }), .airSha256 = sha, .sourceSha256 = source_sha, .bodyInstructions = body_instructions, .configuration = try ctx.field(record, "configuration") }));
        try functions.object.put(ctx.allocator, root, summary);
        try identities.append(ctx.allocator, .{ .path = path, .sha = sha });
    }
    try lines.append(ctx.allocator, try ctx.fmt("end {s}\n", .{lean_namespace}));
    const lean = try std.mem.concat(ctx.allocator, u8, lines.items);
    if (options.certify) |evidence| try @import("certificate.zig").checkWith(ctx, io, evidence, lean, options.environment.?, options.lake, options.profile, call_machine);
    const manifest = try ctx.parse(try ctx.json(.{
        .schema = "zean.translation.v1",
        .provenance = try @import("provenance.zig").identity(ctx),
        .zigVersion = version,
        .zigRevision = revision,
        .profile = options.profile.name(),
        .executionModel = if (call_machine) "call-machine" else options.profile.vocabulary(),
        .capabilities = options.profile.capabilities(),
        .targetModel = if (options.profile.capabilities().memory) "aarch64_macos_le64" else "scalar",
        .admissionSchema = @import("admission.zig").schema,
        .sourceRequirementsComplete = false,
        .namespace = options.namespace,
        .captureReportSha256 = &c.digest(captured.bytes),
        .captureRootSourceSha256 = capture_source_sha,
        .specializedSourceSha256 = if (specialized_bytes != null) source_sha else null,
        .standaloneCapturedSpecialization = specialized_bytes != null,
        .declarationSourceSha256 = if (declaration_bytes != null) source_sha else null,
        .standaloneCapturedDeclaration = declaration_bytes != null,
        .callDeclarationOwnershipChecked = options.profile.hasCalls(),
        .inputKind = c.get(report, "inputKind") orelse c.Value{ .string = "unclassified" },
        .nativeCaptureVerified = false,
        .airCorrespondenceChecked = options.certify != null,
        .jsonLiftingVerified = false,
        .sourceSafetyVerified = false,
        .nativeRefinementVerified = false,
        .wholeCompilerVerified = false,
        .functions = functions,
        .leanSha256 = &c.digest(lean),
    }));
    const repeated = try ctx.read(io, options.capture, c.max_json_bytes + 1);
    try ctx.require(std.mem.eql(u8, repeated, captured.bytes), "capture inputs changed during translation");
    for (identities.items) |identity| {
        const bytes = try ctx.read(io, identity.path, c.max_json_bytes + 1);
        try ctx.require(std.mem.eql(u8, &c.digest(bytes), identity.sha), "capture inputs changed during translation");
    }
    if (specialized_bytes) |bytes| try ctx.require(std.mem.eql(u8, bytes, try ctx.read(io, options.specialized_source.?, 64 * 1024 * 1024)), "specialization source changed during translation");
    if (options.profile.hasCalls()) {
        try closure.revalidateSources();
    } else if (declaration_bytes) |bytes| try ctx.require(std.mem.eql(u8, bytes, try ctx.read(io, options.declaration_source.?, 64 * 1024 * 1024)), "declaration source changed during translation");
    try files.publish(ctx, io, options.output, &.{ .{ .name = "Generated.lean", .bytes = lean }, .{ .name = "manifest.json", .bytes = try ctx.fmt("{s}\n", .{try ctx.json(manifest)}) } });
    return manifest;
}
pub fn capturedPath(ctx: *c.Context, io: std.Io, report: []const u8, entry: c.Value) ![]const u8 {
    const name = try ctx.str(try ctx.field(entry, "file"));
    try ctx.require(name.len > 0 and std.mem.eql(u8, std.fs.path.basename(name), name) and std.mem.endsWith(u8, name, ".json"), "invalid captured AIR filename");
    const directory = try files.join(ctx, &.{ std.fs.path.dirname(report) orelse ".", "air" });
    const stat = try std.Io.Dir.cwd().statFile(io, directory, .{ .follow_symlinks = false });
    try ctx.require(stat.kind == .directory, "captured AIR directory must be a regular directory");
    const path = try files.join(ctx, &.{ directory, name });
    try files.regular(ctx, io, path);
    return path;
}
