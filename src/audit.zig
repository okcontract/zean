// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Independent capture-fixture diagnostics, including deliberately unsupported types.
const std = @import("std");
const c = @import("common.zig");
const files = @import("files.zig");
const runtime = @import("runtime.zig");
const capture = @import("capture.zig");
const tc = @import("toolchain.zig");
const air = @import("air.zig");
const eq = std.mem.eql;
const Position = struct { visible: []bool, path: c.Value };

fn put(ctx: *c.Context, object: *c.Value, key: []const u8, value: c.Value) !void {
    try object.object.put(ctx.allocator, key, value);
}
fn list(ctx: *c.Context, values: []const c.Value) !c.Value {
    var result: c.Value = .{ .array = std.json.Array.init(ctx.allocator) };
    try result.array.appendSlice(values);
    return result;
}
fn positions(ctx: *c.Context, record: c.Value) ![]?Position {
    const instructions = try ctx.array(try ctx.field(record, "instructions"));
    try ctx.require(instructions.len > 0 and instructions.len <= 512, "fixture instruction bound");
    const located = try ctx.allocator.alloc(?Position, instructions.len);
    @memset(located, null);
    const visible = try ctx.allocator.alloc(bool, instructions.len);
    @memset(visible, false);
    try walk(ctx, instructions, located, try ctx.field(record, "body"), visible, try list(ctx, &.{}), 0);
    return located;
}
fn walk(ctx: *c.Context, instructions: []const c.Value, located: []?Position, body: c.Value, inherited: []const bool, path: c.Value, depth: usize) anyerror!void {
    try ctx.require(depth <= 128, "fixture control depth bound");
    const visible = try ctx.allocator.dupe(bool, inherited);
    for (try ctx.array(body)) |reference| {
        const index = try ctx.nat(reference, instructions.len - 1);
        try ctx.require(located[index] == null, "duplicate body ownership");
        located[index] = .{ .visible = try ctx.allocator.dupe(bool, visible), .path = path };
        const instruction = instructions[index];
        const tag = try ctx.str(try ctx.field(instruction, "tag"));
        const branches: []const []const u8 = if (c.oneOf(tag, &.{ "block", "loop" })) &.{"body"} else if (eq(u8, tag, "cond_br")) &.{ "thenBody", "elseBody" } else &.{};
        for (branches) |branch| {
            var child_path = try list(ctx, path.array.items);
            const label = if (eq(u8, branch, "thenBody")) "then" else if (eq(u8, branch, "elseBody")) "else" else "body";
            try child_path.array.append(try list(ctx, &.{ .{ .integer = @intCast(index) }, .{ .string = label } }));
            try walk(ctx, instructions, located, try ctx.field(instruction, branch), visible, child_path, depth + 1);
        }
        visible[index] = true;
    }
}
fn referenceType(ctx: *c.Context, instructions: []const c.Value, visible: []const bool, reference: c.Value) !c.Value {
    if (c.tag(reference, "kind", "instruction")) {
        try ctx.fields(reference, "kind index");
        const index = try ctx.nat(try ctx.field(reference, "index"), instructions.len - 1);
        try ctx.require(visible[index], "fixture operand does not dominate instruction");
        return ctx.field(instructions[index], "type");
    }
    if (c.tag(reference, "kind", "constant")) {
        try ctx.fields(reference, "kind type value");
        return ctx.field(reference, "type");
    }
    if (c.tag(reference, "kind", "undefined")) {
        try ctx.fields(reference, "kind type");
        return ctx.field(reference, "type");
    }
    return ctx.fail("unexpected fixture operand", .{});
}
fn child(ctx: *c.Context, ty: c.Value) !c.Value {
    try ctx.require(c.tag(ty, "kind", "pointer"), "memory operand lost pointer type");
    try ctx.fields(ty, "kind flags child layout pointeeLayout sentinel");
    return ctx.field(ty, "child");
}
fn uint(ctx: *c.Context, bits: u64) !c.Value {
    return ctx.parse(try ctx.json(.{ .kind = "int", .bits = bits, .signedness = "unsigned" }));
}
fn abi(ctx: *c.Context, bytes: u64, alignment: u64) !c.Value {
    return ctx.parse(try ctx.json(.{ .kind = "abi", .bytes = bytes, .alignment = alignment }));
}
fn same(ctx: *c.Context, a: c.Value, b: c.Value, diagnostic: []const u8) !void {
    try ctx.require(c.equal(a, b), diagnostic);
}

pub fn inspectMemory(ctx: *c.Context, record: c.Value) !c.Value {
    const instructions = try ctx.array(try ctx.field(record, "instructions"));
    const located = try positions(ctx, record);
    var observed: c.Value = .{ .object = .empty };
    for (located, instructions) |position, instruction| {
        const point = position orelse continue;
        const tag = try ctx.str(try ctx.field(instruction, "tag"));
        if (eq(u8, tag, "alloc")) {
            try ctx.fields(instruction, "index tag payloadVisited type allocationKind");
            _ = try child(ctx, try ctx.field(instruction, "type"));
            try ctx.require(c.tag(instruction, "allocationKind", "stack"), "local allocation lost stack ownership");
        } else if (c.oneOf(tag, &.{ "store", "store_safe" })) {
            try ctx.fields(instruction, "index tag payloadVisited type lhs rhs");
            try same(ctx, try child(ctx, try referenceType(ctx, instructions, point.visible, try ctx.field(instruction, "lhs"))), try referenceType(ctx, instructions, point.visible, try ctx.field(instruction, "rhs")), "store operand type mismatch");
        } else if (c.oneOf(tag, &.{ "ptr_add", "ptr_sub", "ptr_elem_ptr", "slice_elem_ptr", "slice" })) {
            try ctx.fields(instruction, "index tag payloadVisited type lhs rhs");
            const left = try referenceType(ctx, instructions, point.visible, try ctx.field(instruction, "lhs"));
            const pointee = try child(ctx, left);
            const bits = try ctx.nat(try ctx.field(try ctx.field(record, "configuration"), "pointerBits"), 64);
            try same(ctx, try referenceType(ctx, instructions, point.visible, try ctx.field(instruction, "rhs")), try uint(ctx, bits), "pointer offset lost usize type");
            const ty = try ctx.field(instruction, "type");
            if (eq(u8, tag, "slice")) {
                try same(ctx, try child(ctx, ty), pointee, "slice constructor lost element type");
                try ctx.require(c.tag(try ctx.field(ty, "flags"), "size", "slice"), "slice constructor lost slice type");
            } else if (c.oneOf(tag, &.{ "ptr_elem_ptr", "slice_elem_ptr" })) {
                var expected = try ctx.parse(try ctx.json(left));
                const flags = expected.object.getPtr("flags").?;
                try put(ctx, flags, "size", .{ .string = "one" });
                try put(ctx, &expected, "layout", try abi(ctx, 8, 8));
                try ctx.require(c.tag(try ctx.field(left, "flags"), "size", if (eq(u8, tag, "slice_elem_ptr")) "slice" else "many"), "fixture element pointer input changed");
                try same(ctx, ty, expected, "fixture element pointer attributes changed");
            } else try same(ctx, ty, left, "pointer arithmetic changed type");
        } else if (c.oneOf(tag, &.{ "load", "ret_load", "slice_len", "slice_ptr", "ptr_slice_len_ptr", "ptr_slice_ptr_ptr" })) {
            try ctx.fields(instruction, "index tag payloadVisited type operand");
            const ty = try referenceType(ctx, instructions, point.visible, try ctx.field(instruction, "operand"));
            const pointee = try child(ctx, ty);
            if (c.oneOf(tag, &.{ "load", "ret_load" })) {
                try same(ctx, pointee, if (eq(u8, tag, "ret_load")) try ctx.field(try ctx.field(record, "signature"), "returnType") else try ctx.field(instruction, "type"), "loaded value lost pointee type");
            } else if (c.oneOf(tag, &.{ "ptr_slice_len_ptr", "ptr_slice_ptr_ptr" })) {
                _ = try child(ctx, pointee);
                try ctx.require(c.tag(try ctx.field(pointee, "flags"), "size", "slice"), "field projection lost original slice pointer");
                const projected = try child(ctx, try ctx.field(instruction, "type"));
                if (eq(u8, tag, "ptr_slice_len_ptr")) try same(ctx, projected, try uint(ctx, try ctx.nat(try ctx.field(try ctx.field(record, "configuration"), "pointerBits"), 64)), "slice length field has wrong type") else try same(ctx, try child(ctx, projected), try ctx.field(pointee, "child"), "slice pointer field has wrong element type");
            } else try ctx.require(c.tag(try ctx.field(ty, "flags"), "size", "slice"), "slice projection lost original slice");
        } else continue;
        try ctx.require(c.flag(instruction, "payloadVisited", true), "memory payload was not visited");
        const count = if (observed.object.get(tag)) |value| try ctx.nat(value, 512) else 0;
        try put(ctx, &observed, tag, .{ .integer = @intCast(count + 1) });
    }
    return observed;
}
fn boundReference(ctx: *c.Context, instructions: []const c.Value, visible: []const bool, reference: c.Value, integer: bool) !void {
    if (c.tag(reference, "kind", "instruction")) {
        const ty = try referenceType(ctx, instructions, visible, reference);
        if (integer) try ctx.require(c.tag(ty, "kind", "int") and c.tag(ty, "signedness", "unsigned"), "validity bound is not unsigned");
    } else {
        try ctx.require(integer, "fixture original slice must be an AIR value");
        const scalar = try air.constant(ctx, reference, .scalar);
        try ctx.require(scalar.ty.* == .int and !scalar.ty.int.signed, "validity constant is not unsigned");
    }
}
pub fn inspectSlices(ctx: *c.Context, record: c.Value, basename: []const u8, source: []const u8) !c.Value {
    const instructions = try ctx.array(try ctx.field(record, "instructions"));
    const located = try positions(ctx, record);
    var result = try list(ctx, &.{});
    for (try ctx.array(try ctx.field(try ctx.field(record, "sourceValidity"), "slices"))) |item| {
        try ctx.fields(item, "source anchor start end upperBound unsupportedReason");
        const identity = try ctx.field(item, "source");
        try ctx.fields(identity, "file sha256 span");
        try ctx.require(c.tag(identity, "sha256", &c.digest(source)) and c.tag(identity, "file", basename), "validity source hash mismatch");
        const span = try ctx.field(identity, "span");
        try ctx.fields(span, "start end main");
        const start = try ctx.nat(try ctx.field(span, "start"), source.len);
        const end = try ctx.nat(try ctx.field(span, "end"), source.len);
        const main = try ctx.nat(try ctx.field(span, "main"), source.len);
        try ctx.require(start <= main and main < end, "invalid validity source span");
        const anchor = try ctx.field(item, "anchor");
        try ctx.fields(anchor, "kind index inSupportedBody");
        const index = try ctx.nat(try ctx.field(anchor, "index"), instructions.len - 1);
        try ctx.require(c.tag(anchor, "kind", "beforeInstruction") and c.flag(anchor, "inSupportedBody", true) and located[index] != null, "validity anchor outside supported body");
        try ctx.require(c.oneOf(try ctx.str(try ctx.field(instructions[index], "tag")), &.{ "slice", "ptr_cast" }), "validity anchor is not a slice result");
        const point = located[index].?;
        try boundReference(ctx, instructions, point.visible, try ctx.field(item, "start"), true);
        try boundReference(ctx, instructions, point.visible, try ctx.field(item, "end"), true);
        const bound = try ctx.field(item, "upperBound");
        const kind = try ctx.str(try ctx.field(bound, "kind"));
        if (eq(u8, kind, "sliceLength")) {
            try ctx.fields(bound, "kind original");
            try boundReference(ctx, instructions, point.visible, try ctx.field(bound, "original"), false);
        } else if (eq(u8, kind, "arrayLength")) {
            try ctx.fields(bound, "kind value");
            _ = try ctx.nat(try ctx.field(bound, "value"), std.math.maxInt(u64));
        } else if (eq(u8, kind, "unboundedPointer")) {
            try ctx.fields(bound, "kind requiresMemoryValidity");
            try ctx.require(c.flag(bound, "requiresMemoryValidity", true), "unbounded pointer lost memory obligation");
        } else if (eq(u8, kind, "unsupported")) {
            try ctx.fields(bound, "kind");
            try ctx.require(c.oneOf(try ctx.str(try ctx.field(item, "unsupportedReason")), &.{ "sentinel", "c_pointer" }), "missing unsupported validity reason");
        } else return ctx.fail("unknown validity bound", .{});
        if (!eq(u8, kind, "unsupported")) try ctx.require(c.none(item, "unsupportedReason"), "inconsistent unsupported validity marker");
        try result.array.append(try ctx.parse(try ctx.json(.{ .anchor = index, .path = point.path, .bound = kind, .source = source[start..end], .unsupported = try ctx.field(item, "unsupportedReason") })));
    }
    return result;
}

fn pointer(ctx: *c.Context, pointee: c.Value, layout: c.Value, size: []const u8, alignment: ?u64, is_const: bool, is_volatile: bool, allow_zero: bool, host: u64, bit: u64) !c.Value {
    return ctx.parse(try ctx.json(.{ .kind = "pointer", .child = pointee, .sentinel = @as(?u8, null), .layout = try abi(ctx, if (eq(u8, size, "slice")) 16 else 8, 8), .pointeeLayout = layout, .flags = .{ .size = size, .alignment = alignment, .isConst = is_const, .isVolatile = is_volatile, .allowZero = allow_zero, .addressSpace = "generic", .vectorIndex = @as(?u8, null), .hostSizeBytes = host, .bitOffset = bit } }));
}
fn ptr(ctx: *c.Context, pointee: c.Value, layout: c.Value, size: []const u8) !c.Value {
    return pointer(ctx, pointee, layout, size, null, false, false, false, 0, 0);
}
pub const memory_names = [_][]const u8{ "move_back", "load_store", "slice_fields", "buffer_alias", "initialize_slice", "initialize_length", "unaligned_volatile", "allow_zero", "packed_pointer", "opaque_pointer", "undefined_store" };
pub const slice_names = [_][]const u8{ "bounded_slice", "conditional_slice", "array_slice", "constant_length", "unused_slice", "sentinel_slice", "c_pointer_slice", "unbounded_constant_length", "length_form", "bounded_length_form" };
pub fn inspectSignatures(ctx: *c.Context, records: c.Value) !void {
    const u8_ty = try uint(ctx, 8);
    const u32_ty = try uint(ctx, 32);
    const usize_ty = try uint(ctx, 64);
    const slice_ty = try ptr(ctx, u8_ty, try abi(ctx, 1, 1), "slice");
    const word_ptr = try ptr(ctx, u32_ty, try abi(ctx, 4, 4), "one");
    const many_ptr = try ptr(ctx, u32_ty, try abi(ctx, 4, 4), "many");
    const slice_ptr = try ptr(ctx, slice_ty, try abi(ctx, 16, 8), "one");
    const signatures = [_][]const c.Value{
        &.{ many_ptr, usize_ty },                                                                        &.{ word_ptr, u32_ty },                                                                                                                                                       &.{ slice_ptr, usize_ty },                                                            &.{ many_ptr, usize_ty, u32_ty, u32_ty },
        &.{ slice_ptr, try ptr(ctx, u8_ty, try abi(ctx, 1, 1), "many"), usize_ty },                      &.{ slice_ptr, usize_ty },                                                                                                                                                    &.{try pointer(ctx, u32_ty, try abi(ctx, 4, 4), "one", 1, false, true, false, 0, 0)}, &.{try pointer(ctx, u8_ty, try abi(ctx, 1, 1), "one", null, false, false, true, 0, 0)},
        &.{try pointer(ctx, try uint(ctx, 3), try abi(ctx, 1, 1), "one", 1, false, false, false, 1, 3)}, &.{try ptr(ctx, try ctx.parse("{\"kind\":\"unsupported\",\"zigTypeTag\":\"opaque\"}"), try ctx.parse("{\"kind\":\"unsupported\",\"reason\":\"non-scalar-layout\"}"), "one")}, &.{word_ptr},
    };
    for (memory_names, signatures) |name, parameters| try same(ctx, try ctx.field(try ctx.field(try ctx.field(records, name), "signature"), "parameters"), try list(ctx, parameters), "memory fixture signature attributes changed");
}
fn coverage(ctx: *c.Context, observations: c.Value, required: []const []const u8) !void {
    for (required) |tag| {
        var seen = false;
        for (observations.object.values()) |value| if (c.get(value, tag) != null) {
            seen = true;
        };
        try ctx.require(seen, "missing fixture memory operation coverage");
    }
}
fn sliceExpectations(ctx: *c.Context, records: c.Value, observations: c.Value, mode: []const u8, basename: []const u8, source: []const u8) !void {
    const expressions = [_][]const u8{ "original[start..end]", "original[0..end]", "p[start..end]", "original[0..4]", "original[0..end]", "p[0..end]", "p[0..end]", "p[0..4]", "p[start..][0..length]", "p.*[start..][0..length]" };
    for (slice_names, expressions) |name, expression| {
        const values = try ctx.array(try ctx.field(observations, name));
        try ctx.require(values.len > 0 and c.tag(values[values.len - 1], "source", expression), "validity span does not identify its fixture slice");
        const record = try ctx.field(records, name);
        if (c.oneOf(name, &.{ "bounded_slice", "conditional_slice", "constant_length", "unused_slice" })) try ctx.require(values.len == 2 and c.tag(values[0], "bound", "unboundedPointer") and c.tag(values[1], "bound", "sliceLength"), "original slice length was not retained");
        if (eq(u8, name, "unbounded_constant_length")) try ctx.require(values.len == 1 and c.tag(values[0], "bound", "unboundedPointer"), "pointer slice lost its memory obligation");
        if (eq(u8, name, "conditional_slice")) for (values) |value| {
            var reached_then = false;
            for (try ctx.array(try ctx.field(value, "path"))) |part| if (c.stringIs((try ctx.array(part))[1], "then")) {
                reached_then = true;
            };
            try ctx.require(reached_then, "conditional validity lost its branch position");
        };
        if (eq(u8, name, "array_slice")) {
            const slices = try ctx.array(try ctx.field(try ctx.field(record, "sourceValidity"), "slices"));
            try ctx.require(slices.len == 1, "array slice inventory changed");
            try same(ctx, try ctx.field(slices[0], "upperBound"), try ctx.parse("{\"kind\":\"arrayLength\",\"value\":16}"), "static array bound was not retained");
        }
        if (eq(u8, name, "sentinel_slice") or eq(u8, name, "c_pointer_slice")) try ctx.require(values.len == 1 and c.tag(values[0], "unsupported", if (eq(u8, name, "sentinel_slice")) "sentinel" else "c_pointer"), "unmodeled validity requirement disappeared");
        if (eq(u8, name, "length_form")) {
            var length_form = false;
            for (try ctx.array(try ctx.field(record, "sourceOperationTags"))) |tag| if (c.stringIs(tag, "slice_length")) {
                length_form = true;
            };
            try ctx.require(length_form, "length-based slice source operation disappeared");
            if (eq(u8, mode, "ReleaseFast")) {
                if (air.Decoder.init(ctx, record, .memory)) |_| return ctx.fail("unadmitted length-based slice was accepted", .{}) else |err| {
                    if (err != error.InvalidInput) return err;
                }
            }
        }
        if (eq(u8, name, "bounded_length_form")) {
            try ctx.require(values.len == 1 and c.tag(values[0], "bound", "sliceLength"), "bounded length-based slice lost its original extent");
            if (eq(u8, mode, "ReleaseFast")) _ = try air.decode(ctx, record, .memory);
        }
        if (eq(u8, mode, "ReleaseFast")) {
            if (air.Decoder.init(ctx, record, .scalar)) |_| return ctx.fail("scalar decoder erased validity obligations", .{}) else |err| {
                if (err != error.InvalidInput) return err;
            }
        }
    }
    var invalid = try ctx.parse(try ctx.json(try ctx.field(records, "bounded_slice")));
    const slices = invalid.object.getPtr("sourceValidity").?.object.getPtr("slices").?.array.items;
    try put(ctx, &slices[slices.len - 1], "end", try ctx.parse(try ctx.json(.{ .kind = "instruction", .index = (try ctx.array(try ctx.field(invalid, "instructions"))).len - 1 })));
    if (inspectSlices(ctx, invalid, basename, source)) |_| return ctx.fail("invalid source operand was accepted", .{}) else |err| {
        if (err != error.InvalidInput) return err;
    }
}
fn memoryExpectations(ctx: *c.Context, records: c.Value, observations: c.Value, mode: []const u8) !void {
    try inspectSignatures(ctx, records);
    try coverage(ctx, observations, &.{ "alloc", "load", "ptr_sub", "ptr_slice_len_ptr", "ptr_slice_ptr_ptr" });
    const undefined_word = try ctx.parse(try ctx.json(.{ .kind = "undefined", .type = try uint(ctx, 32) }));
    var retained = false;
    for (try ctx.array(try ctx.field(try ctx.field(records, "undefined_store"), "instructions"))) |instruction| if (c.tag(instruction, "tag", if (eq(u8, mode, "Debug")) "store_safe" else "store") and c.equal(c.get(instruction, "rhs") orelse .null, undefined_word)) {
        retained = true;
    };
    try ctx.require(retained, "undefined write lost its safety mode");
    var mutant = try ctx.parse(try ctx.json(records));
    const packed_parameters = mutant.object.getPtr("packed_pointer").?.object.getPtr("signature").?.object.getPtr("parameters").?.array.items;
    try put(ctx, packed_parameters[0].object.getPtr("flags").?, "bitOffset", .{ .integer = 0 });
    if (inspectSignatures(ctx, mutant)) |_| return ctx.fail("packed-pointer attribute erasure was accepted", .{}) else |err| {
        if (err != error.InvalidInput) return err;
    }
}
fn sliceMemory(ctx: *c.Context, records: c.Value, observations: c.Value) !void {
    try coverage(ctx, observations, &.{ "ptr_add", "slice", "slice_ptr", "ptr_slice_len_ptr" });
    for ([_][]const u8{ "array_slice", "sentinel_slice" }) |name| {
        const sentinel = eq(u8, name, "sentinel_slice");
        const layout = try abi(ctx, if (sentinel) 17 else 16, 1);
        const array_ty = try ctx.parse(try ctx.json(.{ .kind = "array", .length = @as(u8, 16), .child = try uint(ctx, 8), .layout = layout, .sentinel = if (sentinel) try ctx.parse(try ctx.json(.{ .kind = "constant", .type = try uint(ctx, 8), .value = @as(u8, 0) })) else c.Value.null }));
        const parameters = try ctx.array(try ctx.field(try ctx.field(try ctx.field(records, name), "signature"), "parameters"));
        try ctx.require(parameters.len > 0, "missing slice fixture parameter");
        try same(ctx, parameters[0], try pointer(ctx, array_ty, layout, "one", null, true, false, false, 0, 0), "array bound or sentinel layout changed");
    }
}
pub const Options = struct { toolchain: []const u8, output: []const u8, profile: enum { memory, validity } };
pub fn run(ctx: *c.Context, io: std.Io, project: []const u8, options: Options) !c.Value {
    const output = try tc.newOutput(ctx, io, options.output);
    var report = try ctx.parse(try ctx.json(.{ .schema = if (options.profile == .memory) "oksolc.memory-air-tests.v1" else "oksolc.source-validity-tests.v1", .status = "failed", .sourceSafetyVerified = false, .memorySafetyVerified = false, .wholeCompilerVerified = false, .modes = c.Value{ .object = .empty } }));
    defer files.write(io, files.join(ctx, &.{ output, "report.json" }) catch unreachable, ctx.json(report) catch "{\"status\":\"failed\"}") catch {};
    return runInto(ctx, io, project, options, output, &report) catch |err| {
        tc.set(ctx, &report, "error", if (err == error.InvalidInput) ctx.diagnostic else @errorName(err)) catch {};
        return err;
    };
}
fn runInto(ctx: *c.Context, io: std.Io, project: []const u8, options: Options, output: []const u8, report: *c.Value) anyerror!c.Value {
    const toolchain = try files.readJson(ctx, io, options.toolchain);
    const bootstrap_record = try ctx.field(toolchain.value, "bootstrap");
    const bootstrap = try ctx.str(try ctx.field(bootstrap_record, "path"));
    try ctx.require(c.tag(bootstrap_record, "sha256", &(try runtime.fileDigest(ctx, io, bootstrap))), "bootstrap identity mismatch");
    var tracked: c.Value = .{ .object = .empty };
    for ([_][]const u8{ "src", "lean/zig_air", "test/lean" }) |directory| {
        var dir = try std.Io.Dir.cwd().openDir(io, try files.join(ctx, &.{ project, directory }), .{ .iterate = true });
        defer dir.close(io);
        var iterator = dir.iterate();
        while (try iterator.next(io)) |entry| if (entry.kind == .file) {
            const relative = try files.join(ctx, &.{ directory, entry.name });
            try put(ctx, &tracked, relative, .{ .string = try ctx.allocator.dupe(u8, &(try runtime.fileDigest(ctx, io, try files.join(ctx, &.{ project, relative })))) });
        };
    }
    try tc.set(ctx, report, "inputs", tracked);
    const filename = if (options.profile == .memory) "zig_air_memory.zig" else "zig_air_validity.zig";
    const source_path = try files.join(ctx, &.{ project, "test/lean", filename });
    const source = try ctx.read(io, source_path, 1024 * 1024);
    const names: []const []const u8 = if (options.profile == .memory) &memory_names else &slice_names;
    const roots = try ctx.allocator.alloc([]const u8, names.len);
    for (names, roots) |name, *root| root.* = try ctx.fmt("{s}.{s}", .{ filename[0 .. filename.len - 4], name });
    for ([_][]const u8{ "ReleaseFast", "Debug" }) |mode| {
        const directory = try files.join(ctx, &.{ output, mode });
        const captured = try capture.run(ctx, io, .{ .toolchain = options.toolchain, .source = source_path, .output = directory, .roots = roots, .mode = mode });
        var records: c.Value = .{ .object = .empty };
        var observations: c.Value = .{ .object = .empty };
        for (names, roots) |name, root| {
            const entry = try ctx.field(try ctx.field(captured, "functions"), root);
            const path = try @import("translate.zig").capturedPath(ctx, io, try files.join(ctx, &.{ directory, "report.json" }), entry);
            const record = try files.readJson(ctx, io, path);
            try ctx.require(c.tag(entry, "sha256", &c.digest(record.bytes)), "fixture capture record changed");
            try put(ctx, &records, name, record.value);
            if (options.profile == .memory) {
                const config = try ctx.field(record.value, "configuration");
                try ctx.require(c.tag(config, "arch", "aarch64") and c.tag(config, "os", "macos") and c.tag(config, "endianness", "little") and try ctx.nat(try ctx.field(config, "pointerBits"), 64) == 64, "fixture oracle requires aarch64-macos");
            }
            try put(ctx, &observations, name, if (options.profile == .memory) try inspectMemory(ctx, record.value) else try inspectSlices(ctx, record.value, filename, source));
        }
        try files.write(io, try files.join(ctx, &.{ directory, "observations.json" }), try ctx.json(observations));
        if (options.profile == .memory) try memoryExpectations(ctx, records, observations, mode) else try sliceExpectations(ctx, records, observations, mode, filename, source);
        const receipt = try files.readJson(ctx, io, try files.join(ctx, &.{ directory, "ordinary.process.json" }));
        const command_values = try ctx.array(try ctx.field(receipt.value, "command"));
        const command = try ctx.allocator.alloc([]const u8, command_values.len);
        for (command_values, command, 0..) |value, *argument, index| {
            const text = try ctx.str(value);
            argument.* = if (index == 0) bootstrap else if (std.mem.startsWith(u8, text, "-femit-bin=")) try ctx.fmt("-femit-bin={s}/bootstrap.o", .{directory}) else if (index > 0 and c.stringIs(command_values[index - 1], "--cache-dir")) try files.join(ctx, &.{ directory, "bootstrap-cache" }) else text;
        }
        try (runtime.Runner{ .ctx = ctx, .io = io, .output = directory }).run("bootstrap", command, .{});
        const object_hash = try ctx.str(try ctx.field(try ctx.field(captured, "objects"), "captured"));
        for ([_][]const u8{ "ordinary.o", "captured.o", "bootstrap.o" }) |name| try ctx.require(eq(u8, object_hash, &(try runtime.fileDigest(ctx, io, try files.join(ctx, &.{ directory, name })))), "fixture capture changed native code");
        const modes = report.object.getPtr("modes").?;
        try put(ctx, modes, mode, try ctx.parse(try ctx.json(.{ .status = "passed", .objectSha256 = object_hash, .observations = observations, .captureReportSha256 = &(try runtime.fileDigest(ctx, io, try files.join(ctx, &.{ directory, "report.json" }))) })));
    }
    if (options.profile == .memory) {
        const slice_output = try files.join(ctx, &.{ output, "slices" });
        _ = try run(ctx, io, project, .{ .toolchain = options.toolchain, .output = slice_output, .profile = .validity });
        var slice_observations: c.Value = .{ .object = .empty };
        for ([_][]const u8{ "ReleaseFast", "Debug" }) |mode| {
            const directory = try files.join(ctx, &.{ slice_output, mode });
            const captured = try files.readJson(ctx, io, try files.join(ctx, &.{ directory, "report.json" }));
            var records: c.Value = .{ .object = .empty };
            var observations: c.Value = .{ .object = .empty };
            for (slice_names) |name| {
                const entry = try ctx.field(try ctx.field(captured.value, "functions"), try ctx.fmt("zig_air_validity.{s}", .{name}));
                const raw = try files.readJson(ctx, io, try @import("translate.zig").capturedPath(ctx, io, try files.join(ctx, &.{ directory, "report.json" }), entry));
                try ctx.require(c.tag(entry, "sha256", &c.digest(raw.bytes)), "slice fixture record changed");
                try put(ctx, &records, name, raw.value);
                try put(ctx, &observations, name, try inspectMemory(ctx, raw.value));
            }
            try files.write(io, try files.join(ctx, &.{ directory, "memory-observations.json" }), try ctx.json(observations));
            try sliceMemory(ctx, records, observations);
            try put(ctx, &slice_observations, mode, observations);
        }
        try tc.set(ctx, report, "slices", .{ .reportSha256 = &(try runtime.fileDigest(ctx, io, try files.join(ctx, &.{ slice_output, "report.json" }))), .observations = slice_observations });
    }
    var iterator = tracked.object.iterator();
    while (iterator.next()) |entry| try ctx.require(eq(u8, entry.value_ptr.string, &(try runtime.fileDigest(ctx, io, try files.join(ctx, &.{ project, entry.key_ptr.* })))), "fixture gate input changed");
    try ctx.require(c.tag(bootstrap_record, "sha256", &(try runtime.fileDigest(ctx, io, bootstrap))) and eq(u8, &c.digest(toolchain.bytes), &(try runtime.fileDigest(ctx, io, options.toolchain))), "fixture toolchain changed");
    try tc.set(ctx, report, "status", "passed");
    return report.*;
}
