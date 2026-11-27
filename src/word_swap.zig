// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Source-bound u32 swap decoding preserves the original noalias/comptime contract.
const std = @import("std");
const c = @import("common.zig");
const air = @import("air.zig");
const types = @import("types.zig");
const links = @import("specialization.zig");
const files = @import("files.zig");
const translate = @import("translate.zig");
const runtime = @import("runtime.zig");
const z = @import("root.zig");
pub const Decoded = struct { decoder: air.Decoder, program: []const u8, key: []const u8, mapping: []const usize };
pub fn normalized(ctx: *c.Context, record: c.Value) !c.Value {
    var result = try ctx.parse(try ctx.json(record));
    _ = result.object.swapRemove("specialization");
    const signature = result.object.getPtr("signature") orelse return ctx.fail("missing signature", .{});
    try signature.object.put(ctx.allocator, "genericInstance", .{ .bool = false });
    try signature.object.put(ctx.allocator, "noaliasBits", .{ .integer = 0 });
    return result;
}
pub fn decode(ctx: *c.Context, record: c.Value, sources: c.Value) !Decoded {
    try links.identity(ctx, try links.recordIdentity(ctx, record), sources);
    const signature = try links.signature(ctx, record, .word_bytes);
    const mapping = try links.mapping(ctx, record, .word_bytes, sources, null);
    const raw_signature = try ctx.field(record, "signature");
    const specialization = try ctx.field(record, "specialization");
    try ctx.require(c.flag(raw_signature, "genericInstance", true) and c.equal(try ctx.field(raw_signature, "callingConvention"), try ctx.parse("{\"auto\":{}}")) and signature.alias_bits == 3, "unsupported u32 word-swap calling convention or parameter contract");
    try ctx.require(signature.parameters.len == 2 and signature.result.* == .unit and mapping.indices.len == 2 and mapping.indices[0] == 1 and mapping.indices[1] == 2, "unsupported u32 word-swap runtime/source mapping");
    for (signature.parameters) |parameter| {
        try ctx.require(parameter == .stored, "word-swap parameter must have runtime storage");
        const ty = parameter.stored;
        try ctx.require(ty.* == .pointer and ty.pointer.mutable and !ty.pointer.many and ty.pointer.child.isInt(false, 32), "word-swap parameters must be writable single u32 pointers");
    }
    const owner = try ctx.field(specialization, "owner");
    try ctx.require(c.tag(owner, "name", "mem.swap") and c.tag(owner, "sourceFile", "mem.zig") and try ctx.nat(try ctx.field(specialization, "sourceParameterCount"), 3) == 3 and try ctx.nat(try ctx.field(specialization, "sourceComptimeBits"), 1) == 1 and try ctx.nat(try ctx.field(specialization, "sourceNoaliasBits"), 6) == 6, "unsupported u32 word-swap specialization contract");
    const arguments = try ctx.array(try ctx.field(specialization, "arguments"));
    try ctx.require(c.equal(arguments[0], try ctx.parse("{\"kind\":\"type\",\"value\":{\"kind\":\"int\",\"bits\":32,\"signedness\":\"unsigned\"}}")), "word-swap comptime argument must be u32");
    var decoder = try air.Decoder.initWith(ctx, try normalized(ctx, record), .word_byte_loops, .{ .source_parameters = mapping.indices });
    const program = try ctx.fmt("{{ program :=\n  {s} }}", .{try decoder.program()});
    return .{ .decoder = decoder, .program = program, .key = mapping.sha.?, .mapping = mapping.indices };
}
fn indices(ctx: *c.Context, values: []const bool) ![]const usize {
    var result: std.ArrayList(usize) = .empty;
    for (values, 0..) |flag, index| if (flag) try result.append(ctx.allocator, index);
    return result.items;
}
fn inventory(ctx: *c.Context, decoder: air.Decoder) !c.Value {
    var values: c.Value = .{ .array = std.array_list.Managed(c.Value).init(ctx.allocator) };
    var slots: c.Value = .{ .array = std.array_list.Managed(c.Value).init(ctx.allocator) };
    for (decoder.byte_values, decoder.byte_slots, 0..) |value, slot, index| {
        if (value) |origin| try values.array.append(try ctx.parse(try ctx.json(.{ .instruction = index, .origin = origin, .alignment = decoder.byte_alignments[index] })));
        if (slot) |allocation| try slots.array.append(try ctx.parse(try ctx.json(.{ .instruction = index, .allocation = allocation })));
    }
    return ctx.parse(try ctx.json(.{ .values = values, .stackSlots = slots }));
}
pub fn generate(ctx: *c.Context, io: std.Io, report_path: []const u8, root: []const u8, std_mem: []const u8, output: []const u8) !c.Value {
    const captured = try files.readJson(ctx, io, report_path);
    const report = captured.value;
    try ctx.require(c.tag(report, "schema", "oksolc.fresh-air-capture.v1") and c.tag(report, "status", "captured") and c.flag(report, "captureComplete", true) and c.tag(report, "zigVersion", z.version) and c.tag(report, "zigRevision", z.revision), "word-swap capture was not completed with Zig 0.17.1");
    const functions = try ctx.field(report, "functions");
    try ctx.require(c.flag(try ctx.field(functions, root), "requested", true), "word-swap selection requires a requested capture root");
    var records: c.Value = .{ .object = .empty };
    var identities: std.ArrayList(struct { path: []const u8, sha: []const u8 }) = .empty;
    var iter = functions.object.iterator();
    while (iter.next()) |entry| {
        const path = try translate.capturedPath(ctx, io, report_path, entry.value_ptr.*);
        const bytes = try ctx.read(io, path, c.max_json_bytes);
        const sha = try ctx.str(try ctx.field(entry.value_ptr.*, "sha256"));
        try ctx.require(std.mem.eql(u8, &c.digest(bytes), sha), "word-swap captured AIR hash mismatch");
        try records.object.put(ctx.allocator, entry.key_ptr.*, try ctx.parse(bytes));
        try identities.append(ctx.allocator, .{ .path = path, .sha = sha });
    }
    const caller = try ctx.field(records, root);
    const caller_source = try ctx.str(try ctx.field(caller, "sourceFile"));
    try ctx.require(c.equal(try ctx.field(caller, "sourceSha256"), try ctx.field(report, "sourceSha256")) and !std.mem.eql(u8, caller_source, "mem.zig"), "word-swap caller source identity mismatch");
    const mem_hash = try runtime.fileDigest(ctx, io, std_mem);
    var sources: c.Value = .{ .object = .empty };
    try sources.object.put(ctx.allocator, caller_source, try ctx.field(report, "sourceSha256"));
    try sources.object.put(ctx.allocator, "mem.zig", .{ .string = try ctx.allocator.dupe(u8, &mem_hash) });
    const linked = try links.link(ctx, records, &.{root}, sources);
    const edges = try ctx.array(try ctx.field(linked, "edges"));
    try ctx.require(edges.len == 1 and c.tag(edges[0], "caller", root), "word-swap selection requires one direct captured callee");
    const edge = edges[0];
    const callee = try ctx.str(try ctx.field(edge, "callee"));
    const record = try ctx.field(records, callee);
    const decoded = try decode(ctx, record, sources);
    const lean = try ctx.fmt(files.generated_lean_header ++ "/-\n// Copyright (C) 2026 OKcontract Pte. Ltd.\n// SPDX-License-Identifier: Apache-2.0\nSource/backend preservation remains open.\n-/\nimport Compiler.ZigAir.MemoryWordPair\n\nnamespace Compiler.ZigAir.GeneratedMemory\nopen MemoryAir\n\ndef fn_swap_u32 : WordPairProgram :=\n{s}\n\nend Compiler.ZigAir.GeneratedMemory\n", .{decoded.program});
    var visited: usize = 0;
    for (decoded.decoder.visited) |flag| if (flag) {
        visited += 1;
    };
    var guards: usize = 0;
    for (decoded.decoder.guard_seen) |flag| if (flag) {
        guards += 1;
    };
    const manifest = try ctx.parse(try ctx.json(.{ .schema = "oksolc.word-swap-generation.v1", .proofScope = "zigFreshAirUnderWordPairContract", .captureReportSha256 = &c.digest(captured.bytes), .leanSha256 = &c.digest(lean), .selectedCall = edge, .links = linked, .airSha256 = try ctx.field(try ctx.field(functions, callee), "sha256"), .specialization = try ctx.field(record, "specialization"), .specializationSha256 = decoded.key, .signature = try ctx.field(record, "signature"), .runtimeParameterIndices = decoded.mapping, .entryContract = "initialized-writable-disjoint-u32-pair-v1", .bodyInstructions = visited, .sourceGuards = guards, .wordByteViews = try inventory(ctx, decoded.decoder), .loops = try indices(ctx, decoded.decoder.loop_ids), .repeatTargets = try indices(ctx, decoded.decoder.repeats), .executionModel = "resumableMemoryAir", .bodyDecoded = true, .specializationSemanticsVerified = false, .bodyFootprintVerified = false, .capturedSwapLoopVerified = false, .nativeNoaliasVerified = false, .sourceSafetyVerified = false, .nativeBackendVerified = false, .wholeCompilerVerified = false }));
    var stamped = manifest;
    try stamped.object.put(ctx.allocator, "provenance", try @import("provenance.zig").identity(ctx));
    try ctx.require(std.mem.eql(u8, captured.bytes, try ctx.read(io, report_path, c.max_json_bytes)) and std.mem.eql(u8, &mem_hash, &(try runtime.fileDigest(ctx, io, std_mem))), "word-swap inputs changed during generation");
    for (identities.items) |entry| try ctx.require(std.mem.eql(u8, entry.sha, &c.digest(try ctx.read(io, entry.path, c.max_json_bytes))), "word-swap record changed during generation");
    try files.publish(ctx, io, output, &.{ .{ .name = "Generated.lean", .bytes = lean }, .{ .name = "manifest.json", .bytes = try ctx.json(stamped) } });
    return stamped;
}
