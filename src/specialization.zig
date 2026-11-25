// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Direct-call source identity and explicit-comptime provenance. Not body refinement.
const std = @import("std");
const c = @import("common.zig");
const types = @import("types.zig");
const air = @import("air.zig");
const capture = @import("capture.zig");
const declaration_source = @import("declaration_source.zig");
const eq = std.mem.eql;
const Parameter = union(enum) { stored: *const types.Ty, singleton: c.Value };
const Signature = struct { parameters: []Parameter, result: *const types.Ty, alias_bits: u64 };
pub const Mapping = struct { indices: []const usize, sha: ?[]const u8 };
pub fn identity(ctx: *c.Context, value: c.Value, sources: c.Value) c.Error!void {
    try ctx.fields(value, "name sourceFile sourceSha256");
    const name = try ctx.str(try ctx.field(value, "name"));
    const file = try ctx.str(try ctx.field(value, "sourceFile"));
    const sha = try ctx.str(try ctx.field(value, "sourceSha256"));
    try ctx.require(name.len > 0 and name.len <= 1024 and c.isDigest(sha) and c.tag(sources, file, sha), "function identity is outside the pinned source inventory");
}
pub fn recordIdentity(ctx: *c.Context, record: c.Value) c.Error!c.Value {
    var value: c.Value = .{ .object = .empty };
    for ([_][]const u8{ "name", "sourceFile", "sourceSha256" }) |key| try value.object.put(ctx.allocator, key, try ctx.field(record, key));
    return value;
}
pub fn signature(ctx: *c.Context, record: c.Value, profile: types.Profile) c.Error!Signature {
    const value = try ctx.field(record, "signature");
    try ctx.fields(value, "callingConvention genericInstance varArgs noaliasBits parameters returnType");
    try ctx.require(c.get(value, "genericInstance").? == .bool and c.flag(value, "varArgs", false), "unsupported specialization or variadic signature");
    const parameters = try ctx.array(try ctx.field(value, "parameters"));
    try ctx.require(parameters.len <= 32, "unsupported signature parameter count");
    const alias_bits = try ctx.nat(try ctx.field(value, "noaliasBits"), (@as(u64, 1) << @intCast(parameters.len)) - 1);
    const parsed = try ctx.allocator.alloc(Parameter, parameters.len);
    for (parameters, parsed, 0..) |parameter, *out, index| {
        if (try types.isSingletonParameter(ctx, parameter)) {
            try ctx.require(alias_bits & (@as(u64, 1) << @intCast(index)) == 0, "singleton argument cannot have a noalias contract");
            out.* = .{ .singleton = parameter };
        } else out.* = .{ .stored = try types.parse(ctx, parameter, profile, 0) };
    }
    return .{ .parameters = parsed, .result = try types.parse(ctx, try ctx.field(value, "returnType"), profile, 0), .alias_bits = alias_bits };
}
pub fn mapping(ctx: *c.Context, record: c.Value, profile: types.Profile, sources: c.Value, retained: ?*declaration_source.Retained) c.Error!Mapping {
    const sig = try signature(ctx, record, profile);
    const signature_record = try ctx.field(record, "signature");
    if (c.flag(signature_record, "genericInstance", false)) {
        try ctx.require(c.get(record, "specialization") == null, "nongeneric function has specialization metadata");
        const indices = try ctx.allocator.alloc(usize, sig.parameters.len);
        for (indices, 0..) |*entry, index| entry.* = index;
        return .{ .indices = indices, .sha = null };
    }
    const spec = try ctx.field(record, "specialization");
    try ctx.fields(spec, "schema owner sourceNoaliasBits sourceComptimeBits sourceParameterCount arguments");
    try ctx.require(c.tag(spec, "schema", "oksolc.generic-instance.v1"), "unsupported specialization schema");
    const owner = try ctx.field(spec, "owner");
    try identity(ctx, owner, sources);
    try ctx.require(c.equal(try ctx.field(owner, "sourceFile"), try ctx.field(record, "sourceFile")) and c.equal(try ctx.field(owner, "sourceSha256"), try ctx.field(record, "sourceSha256")), "generic owner and instance source disagree");
    const count = try ctx.nat(try ctx.field(spec, "sourceParameterCount"), 32);
    const mask = (@as(u64, 1) << @intCast(count)) - 1;
    const alias_bits = try ctx.nat(try ctx.field(spec, "sourceNoaliasBits"), mask);
    const comptime_bits = try ctx.nat(try ctx.field(spec, "sourceComptimeBits"), mask);
    const arguments = try ctx.array(try ctx.field(spec, "arguments"));
    try ctx.require(arguments.len == count, "specialization argument count disagrees with owner");
    var indices: std.ArrayList(usize) = .empty;
    var remapped: u64 = 0;
    for (arguments, 0..) |arg, index| {
        const bit = @as(u64, 1) << @intCast(index);
        if (c.tag(arg, "kind", "runtime") or c.tag(arg, "kind", "runtimeAnytype")) {
            try ctx.fields(arg, "kind runtimeIndex");
            try ctx.require(try ctx.nat(try ctx.field(arg, "runtimeIndex"), 31) == indices.items.len and comptime_bits & bit == 0, "runtime/source parameter mapping disagrees");
            if (alias_bits & bit != 0) remapped |= @as(u64, 1) << @intCast(indices.items.len);
            try indices.append(ctx.allocator, index);
        } else {
            try ctx.fields(arg, "kind value");
            try ctx.require(comptime_bits & bit != 0 and alias_bits & bit == 0, "implicit comptime or comptime alias_bits is outside the metadata profile");
            const value = try ctx.field(arg, "value");
            if (c.tag(arg, "kind", "type") or c.tag(arg, "kind", "anytypeType")) {
                _ = try types.parse(ctx, value, profile, 0);
            } else if (c.tag(arg, "kind", "value")) {
                if (c.tag(value, "kind", "function")) {
                    try ctx.fields(value, "kind identity");
                    const callback = try ctx.field(value, "identity");
                    try identity(ctx, callback, sources);
                    const declarations = retained orelse return ctx.fail("comptime callback requires retained source", .{});
                    const path = try ctx.str(try ctx.field(callback, "sourceFile"));
                    const file = declarations.get(path) catch |err| switch (err) {
                        error.InvalidInput, error.OutOfMemory => |e| return e,
                        else => return ctx.fail("cannot read callback source {s}: {s}", .{ path, @errorName(err) }),
                    };
                    const name = try ctx.str(try ctx.field(callback, "name"));
                    try ctx.require(c.tag(callback, "sourceSha256", &file.sha) and std.mem.startsWith(u8, name, file.prefix), "callback source identity mismatch");
                    var buffer: [1]std.zig.Ast.Node.Index = undefined;
                    _ = try declaration_source.functionProto(ctx, callback, &file.declarations, name[file.prefix.len..], &buffer);
                } else _ = try air.constant(ctx, value, profile);
            } else return ctx.fail("unsupported compile-time argument", .{});
        }
    }
    try ctx.require(indices.items.len == sig.parameters.len and remapped == sig.alias_bits, "specialization lost runtime parameters or alias_bits bits");
    return .{ .indices = indices.items, .sha = try c.fingerprint(ctx, try ctx.parse(try ctx.json(.{ .specialization = spec, .signature = signature_record, .configuration = try ctx.field(record, "configuration") }))) };
}
pub fn link(ctx: *c.Context, records: c.Value, roots: []const []const u8, sources: c.Value) c.Error!c.Value {
    try capture.uniqueRoots(ctx, roots);
    try ctx.require(records == .object, "expected captured function table");
    for (roots) |name| try ctx.require(records.object.contains(name), "missing requested link root");
    const configuration = try ctx.field(records.object.get(roots[0]).?, "configuration");
    try ctx.require(c.tag(configuration, "optimize", "ReleaseFast") and c.flag(configuration, "useLlvm", true) and c.flag(configuration, "isTest", false), "unsupported link build configuration");
    var pending: std.ArrayList([]const u8) = .empty;
    try pending.appendSlice(ctx.allocator, roots);
    var functions: c.Value = .{ .object = .empty };
    var edges: std.ArrayList(c.Value) = .empty;
    while (pending.pop()) |name| {
        if (functions.object.contains(name)) continue;
        const record = try ctx.field(records, name);
        try ctx.require(c.tag(record, "name", name) and c.tag(record, "schema", "oksolc.fresh-air.v3") and c.tag(record, "capturePoint", "after-sema-before-legalize") and c.equal(try ctx.field(record, "configuration"), configuration), "linked function identity, phase or configuration mismatch");
        try identity(ctx, try recordIdentity(ctx, record), sources);
        const sig = try signature(ctx, record, .word_bytes);
        const spec = try mapping(ctx, record, .word_bytes, sources, null);
        const instructions = try ctx.array(try ctx.field(record, "instructions"));
        const body = try ctx.array(try ctx.field(record, "body"));
        try ctx.require(instructions.len > 0 and instructions.len <= 512, "invalid linked instruction inventory");
        var unsupported: c.Value = .{ .array = std.array_list.Managed(c.Value).init(ctx.allocator) };
        var unvisited: usize = 0;
        for (instructions, 0..) |inst, index| {
            try ctx.require(try ctx.nat(try ctx.field(inst, "index"), 511) == index and (try ctx.field(inst, "payloadVisited")) == .bool, "invalid linked instruction index");
            _ = try ctx.str(try ctx.field(inst, "tag"));
            if (!c.flag(inst, "payloadVisited", true)) unvisited += 1 else if (c.flag(inst, "unsupportedPayload", true)) try unsupported.array.append(try ctx.parse(try ctx.json(.{ .index = index, .tag = try ctx.field(inst, "tag") })));
        }
        var position: usize = 0;
        for (spec.indices, sig.parameters) |source_index, parameter| {
            if (parameter == .singleton) continue;
            try ctx.require(position < body.len, "missing linked argument prefix");
            const instruction = instructions[try ctx.nat(body[position], instructions.len - 1)];
            try ctx.require(c.tag(instruction, "tag", "arg") and c.flag(instruction, "payloadVisited", true) and try ctx.nat(try ctx.field(instruction, "zirParameterIndex"), 31) == source_index and types.Ty.same(try types.parse(ctx, try ctx.field(instruction, "type"), .word_bytes, 0), parameter.stored), "linked AIR arguments disagree with runtime/source mapping");
            position += 1;
        }
        try functions.object.put(ctx.allocator, name, try ctx.parse(try ctx.json(.{ .recordSha256 = try c.fingerprint(ctx, record), .specializationSha256 = spec.sha, .runtimeParameterIndices = spec.indices, .noaliasBits = sig.alias_bits, .unsupportedBodyInstructions = unsupported, .unvisitedInstructions = unvisited })));
        for (instructions) |inst| {
            if (!c.flag(inst, "payloadVisited", true) or !c.oneOf(try ctx.str(try ctx.field(inst, "tag")), &.{ "call", "call_always_tail", "call_never_tail", "call_never_inline" })) continue;
            try ctx.fields(inst, "index tag payloadVisited type callee arguments");
            const callee = try ctx.field(inst, "callee");
            try ctx.fields(callee, "kind identity");
            try ctx.require(c.tag(callee, "kind", "function"), "indirect or unsupported function reference");
            const target = try ctx.field(callee, "identity");
            try identity(ctx, target, sources);
            const target_name = try ctx.str(try ctx.field(target, "name"));
            const target_record = try ctx.field(records, target_name);
            try ctx.require(c.equal(target, try recordIdentity(ctx, target_record)), "call reference and captured callee disagree");
            const expected = try signature(ctx, target_record, .word_bytes);
            const args = try ctx.array(try ctx.field(inst, "arguments"));
            try ctx.require(args.len == expected.parameters.len, "call runtime argument count disagrees with callee");
            for (args, expected.parameters) |arg, wanted| {
                if (wanted == .singleton) {
                    try types.checkSingletonValue(ctx, arg, wanted.singleton);
                    continue;
                }
                const actual = if (c.tag(arg, "kind", "instruction")) blk: {
                    try ctx.fields(arg, "kind index");
                    const instruction = instructions[try ctx.nat(try ctx.field(arg, "index"), instructions.len - 1)];
                    try ctx.require(c.flag(instruction, "payloadVisited", true), "call uses an unvisited argument");
                    break :blk try types.parse(ctx, try ctx.field(instruction, "type"), .word_bytes, 0);
                } else (try air.constant(ctx, arg, .memory)).ty;
                try ctx.require(types.Ty.same(actual, wanted.stored), "call runtime argument type disagrees with callee");
            }
            try ctx.require(types.Ty.same(try types.parse(ctx, try ctx.field(inst, "type"), .word_bytes, 0), expected.result), "call return type disagrees with callee");
            try edges.append(ctx.allocator, try ctx.parse(try ctx.json(.{ .caller = name, .instruction = try ctx.field(inst, "index"), .tag = try ctx.field(inst, "tag"), .callee = target_name, .arguments = args })));
            try pending.append(ctx.allocator, target_name);
        }
    }
    std.mem.sort(c.Value, edges.items, ctx, struct {
        fn less(context: *c.Context, a: c.Value, b: c.Value) bool {
            const left = c.get(a, "caller").?.string;
            const right = c.get(b, "caller").?.string;
            return if (eq(u8, left, right)) (context.nat(c.get(a, "instruction").?, 511) catch unreachable) < (context.nat(c.get(b, "instruction").?, 511) catch unreachable) else std.mem.lessThan(u8, left, right);
        }
    }.less);
    return ctx.parse(try ctx.json(.{ .schema = "oksolc.specialization-links.v1", .exportedCallLinksChecked = true, .bodyCoverageVerified = false, .argumentDominanceVerified = false, .specializationSemanticsVerified = false, .noaliasVerified = false, .sourceSafetyVerified = false, .nativeBackendVerified = false, .wholeCompilerVerified = false, .roots = roots, .sources = sources, .configuration = configuration, .functions = try c.ordered(ctx, functions), .edges = edges.items }));
}
