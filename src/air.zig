// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Trusted, fail-closed decoding of the admitted Zig AIR fragments.
const std = @import("std");
const c = @import("common.zig");
const types = @import("types.zig");
pub const Profile = types.Profile;
pub const Ty = types.Ty;
const Context = c.Context;
const Value = c.Value;
const Error = c.Error;
const eq = std.mem.eql;
const maximum_instructions = 1024;
pub const Extension = enum { none, assertion, hash_update, scalar_view, slice_view };
pub const Options = struct {
    source_parameters: ?[]const usize = null,
    explicit_type_specialization: bool = false,
    instruction_limit: usize = 512,
    extension: Extension = .none,
    assertion: ?Value = null,
    view_alignment: u64 = 1,
    view_count: u64 = 0,
    callees: []const Callee = &.{},
    call_machine: bool = false,
};
pub const Callee = struct { record: Value, declaration: []const u8, profile: Profile = .calls, machine_index: ?usize = null, machine_label: ?[]const u8 = null };

pub const Reference = struct { ty: *const Ty, text: []const u8 };
const Label = union(enum) { block: *const Ty, loop };
const Prefix = struct { kind: []const u8 = "bind", id: usize, ty: []const u8, child: []const u8 };
const Env = []?*const Ty;
const Labels = []?Label;
const Cell = struct { offset: u64, text: []const u8 };

pub fn constant(ctx: *Context, value: Value, profile: Profile) Error!Reference {
    if (profile == .aggregate and (c.tag(value, "kind", "aggregate") or c.tag(value, "kind", "undefined"))) {
        const ty = try types.parse(ctx, try ctx.field(value, "type"), profile, 0);
        try ctx.require(ty.* == .structure, "undefined scalar/array cannot be an evaluated register");
        var cells: std.ArrayList(Cell) = .empty;
        try leaves(ctx, value, ty, 0, &cells);
        var texts: std.ArrayList([]const u8) = .empty;
        var index = cells.items.len;
        while (index > 0) {
            index -= 1;
            const cell = cells.items[index];
            try texts.append(ctx.allocator, try ctx.fmt("({d}, {s})", .{ cell.offset, cell.text }));
        }
        return .{ .ty = ty, .text = try ctx.fmt("(.constant (.aggregate {s} [{s}]))", .{ try ty.lean(ctx, .memory), try std.mem.join(ctx.allocator, ", ", texts.items) }) };
    }
    const result = try scalarConstant(ctx, value);
    if (profile == .scalar) return result;
    const body = result.text["(.constant ".len .. result.text.len - 1];
    return .{ .ty = result.ty, .text = if (profile == .aggregate) try ctx.fmt("(.constant (.value (.scalar {s})))", .{body}) else try ctx.fmt("(.constant (.scalar {s}))", .{body}) };
}

fn scalarConstant(ctx: *Context, value: Value) Error!Reference {
    if (c.tag(value, "kind", "unit")) {
        try ctx.fields(value, "kind");
        return .{ .ty = try ctx.make(Ty, .unit), .text = "(.constant .unit)" };
    }
    try ctx.fields(value, "kind type value");
    try ctx.require(c.tag(value, "kind", "constant"), "unsupported or malformed AIR constant");
    const ty = try types.parse(ctx, try ctx.field(value, "type"), .scalar, 0);
    const number = try ctx.integer(try ctx.field(value, "value"));
    if (ty.* == .boolean) {
        try ctx.require(number == 0 or number == 1, "invalid boolean constant");
        return .{ .ty = ty, .text = try ctx.fmt("(.constant (.bool {s}))", .{c.boolText(number == 1)}) };
    }
    try ctx.require(ty.* == .int, "unsupported constant type");
    const integer = ty.int;
    const shift: u10 = @intCast(if (integer.signed and integer.bits > 0) integer.bits - 1 else integer.bits);
    const upper = @as(i1024, 1) << shift;
    const lower = if (integer.signed and integer.bits > 0) -upper else 0;
    try ctx.require(number >= lower and number < upper, "AIR constant outside declared type");
    return .{ .ty = ty, .text = try ctx.fmt("(.constant (.int {s} {d} ({d})))", .{ c.boolText(integer.signed), integer.bits, number }) };
}
fn leaves(ctx: *Context, value: Value, expected: *const Ty, offset: u64, cells: *std.ArrayList(Cell)) Error!void {
    if (c.tag(value, "kind", "undefined")) {
        try ctx.fields(value, "kind type");
        try ctx.require(Ty.same(try types.parse(ctx, try ctx.field(value, "type"), .aggregate, 0), expected), "undefined field changes type");
        return;
    }
    if (c.tag(value, "kind", "aggregate")) {
        try ctx.fields(value, "kind type fields");
        try ctx.require(expected.* == .structure and Ty.same(try types.parse(ctx, try ctx.field(value, "type"), .aggregate, 0), expected), "aggregate constant changes type");
        const values = try ctx.array(try ctx.field(value, "fields"));
        try ctx.require(values.len == expected.structure.fields.len, "incomplete aggregate constant");
        for (expected.structure.fields, values) |field, item| try leaves(ctx, item, field.ty, offset + field.offset, cells);
        return;
    }
    const leaf = try constant(ctx, value, .memory);
    try ctx.require(Ty.same(leaf.ty, expected), "aggregate leaf changes type");
    try cells.append(ctx.allocator, .{ .offset = offset, .text = leaf.text["(.constant ".len .. leaf.text.len - 1] });
}

pub const Decoder = struct {
    ctx: *Context,
    profile: Profile,
    record: Value,
    parameters: []*const Ty,
    result: *const Ty,
    instructions: []const Value,
    visited: []bool,
    loop_ids: []bool,
    repeats: []bool,
    arguments: usize = 0,
    guards: []?Value,
    guard_positions: []usize,
    guard_seen: []bool,
    byte_values: []?usize,
    byte_slots: []?usize,
    byte_alignments: []u64,
    options: Options = .{},
    empty_constants: usize = 0,

    pub fn init(ctx: *Context, record: Value, profile: Profile) Error!Decoder {
        return initWith(ctx, record, profile, .{});
    }
    pub fn initWith(ctx: *Context, record: Value, profile: Profile, options: Options) Error!Decoder {
        try ctx.fields(record, if (options.explicit_type_specialization) "schema capturePoint name sourceFile sourceSha256 configuration signature specialization sourceOperationTags sourceValidityConditionsPreserved sourceValidity body bodyTraversal instructions" else "schema capturePoint name sourceFile sourceSha256 configuration signature sourceOperationTags sourceValidityConditionsPreserved sourceValidity body bodyTraversal instructions");
        try ctx.require(c.tag(record, "schema", "oksolc.fresh-air.v3") and c.tag(record, "capturePoint", "after-sema-before-legalize") and c.tag(record, "bodyTraversal", "supported-structured-containers-only") and c.flag(record, "sourceValidityConditionsPreserved", false), "wrong AIR schema, phase or source-validity claim");
        const config = try ctx.field(record, "configuration");
        _ = try @import("target.zig").admit(ctx, config, profile.capabilities().memory);
        const signature = try ctx.field(record, "signature");
        try ctx.fields(signature, "callingConvention genericInstance varArgs noaliasBits parameters returnType");
        try ctx.require(c.flag(signature, "genericInstance", options.explicit_type_specialization) and (!options.explicit_type_specialization or options.source_parameters != null) and c.flag(signature, "varArgs", false) and try ctx.nat(try ctx.field(signature, "noaliasBits"), std.math.maxInt(u64)) == 0, "unsupported function specialization or parameter contract");
        const params = try ctx.array(try ctx.field(signature, "parameters"));
        try ctx.require(params.len <= 512, "malformed or oversized parameter list");
        const parameters = try ctx.allocator.alloc(*const Ty, params.len);
        if (options.source_parameters) |mapping| try ctx.require(mapping.len == params.len, "runtime/source parameter mapping has the wrong length");
        for (params, parameters) |value, *target| target.* = try types.parse(ctx, value, profile, 0);
        const result = try types.parse(ctx, try ctx.field(signature, "returnType"), profile, 0);
        for (parameters) |ty| _ = try ty.lean(ctx, profile);
        _ = try result.lean(ctx, profile);
        if (profile != .scalar) {
            for (parameters) |ty| try ctx.require(ty.* != .array, "array values are not implemented in memory AIR");
            try ctx.require(result.* != .array, "array values are not implemented in memory AIR");
        }
        if (profile.hasBytes()) {
            for (parameters) |ty| {
                try ctx.require(!ty.hasAlignment(), "aligned signature needs an external memory contract");
                try ctx.require(ty.* == .int or ty.* == .boolean or ty.* == .unit or (ty.* == .pointer and ty.pointer.child.isInt(false, 32)), "byte profile parameters require scalar or u32-pointer types");
            }
            try ctx.require(!result.hasAlignment(), "aligned signature needs an external memory contract");
        }
        const instructions = try ctx.array(try ctx.field(record, "instructions"));
        try ctx.require(instructions.len > 0 and instructions.len <= options.instruction_limit and options.instruction_limit <= maximum_instructions, "scalar AIR instruction resource limit");
        for (instructions, 0..) |inst, index| {
            try ctx.require(try ctx.nat(try ctx.field(inst, "index"), maximum_instructions) == index, "invalid AIR instruction table");
            _ = try ctx.str(try ctx.field(inst, "tag"));
        }
        var decoder: Decoder = .{ .ctx = ctx, .profile = profile, .record = record, .parameters = parameters, .result = result, .instructions = instructions, .options = options, .visited = try ctx.allocator.alloc(bool, maximum_instructions), .loop_ids = try ctx.allocator.alloc(bool, maximum_instructions), .repeats = try ctx.allocator.alloc(bool, maximum_instructions), .guards = try ctx.allocator.alloc(?Value, maximum_instructions), .guard_positions = try ctx.allocator.alloc(usize, maximum_instructions), .guard_seen = try ctx.allocator.alloc(bool, maximum_instructions), .byte_values = try ctx.allocator.alloc(?usize, maximum_instructions), .byte_slots = try ctx.allocator.alloc(?usize, maximum_instructions), .byte_alignments = try ctx.allocator.alloc(u64, maximum_instructions) };
        @memset(decoder.visited, false);
        @memset(decoder.loop_ids, false);
        @memset(decoder.repeats, false);
        @memset(decoder.guards, null);
        @memset(decoder.guard_seen, false);
        @memset(decoder.byte_values, null);
        @memset(decoder.byte_slots, null);
        @memset(decoder.byte_alignments, 0);
        try decoder.readValidity();
        return decoder;
    }

    fn readValidity(self: *Decoder) Error!void {
        const ctx = self.ctx;
        const validity = try ctx.field(self.record, "sourceValidity");
        try ctx.fields(validity, "schema coverage complete slices");
        const slices = try ctx.array(try ctx.field(validity, "slices"));
        try ctx.require(c.tag(validity, "schema", "oksolc.source-validity.v1") and c.tag(validity, "coverage", "runtime-slice-results") and c.flag(validity, "complete", false), "unsupported source-validity obligations");
        const tags = try ctx.array(try ctx.field(self.record, "sourceOperationTags"));
        var length_slices = false;
        if (self.profile != .scalar and self.options.extension != .hash_update) for (tags) |value| {
            length_slices = length_slices or c.stringIs(value, "slice_length");
        };
        if (self.profile == .scalar or (self.profile == .aggregate and self.options.extension != .hash_update and self.options.extension != .slice_view)) return ctx.require(slices.len == 0 and !length_slices, "unsupported source-validity obligations in scalar AIR");
        try ctx.require(slices.len <= 512, "unsupported memory source-validity inventory");
        if (length_slices) try ctx.require(slices.len > 0, "length-based slice lost its source guard");
        for (slices, 0..) |item, position| {
            try ctx.fields(item, "source anchor start end upperBound unsupportedReason");
            const source = try ctx.field(item, "source");
            try ctx.fields(source, "file sha256 span");
            try ctx.require(c.equal(try ctx.field(source, "sha256"), try ctx.field(self.record, "sourceSha256")) and c.equal(try ctx.field(source, "file"), try ctx.field(self.record, "sourceFile")), "source guard identity mismatch");
            const span = try ctx.field(source, "span");
            try ctx.fields(span, "start end main");
            const start = try ctx.nat(try ctx.field(span, "start"), std.math.maxInt(u32));
            const main = try ctx.nat(try ctx.field(span, "main"), std.math.maxInt(u32));
            const end = try ctx.nat(try ctx.field(span, "end"), std.math.maxInt(u32));
            try ctx.require(start <= main and main < end, "invalid source guard span");
            const anchor = try ctx.field(item, "anchor");
            try ctx.fields(anchor, "kind index inSupportedBody");
            const index = try ctx.nat(try ctx.field(anchor, "index"), maximum_instructions - 1);
            try ctx.require(c.tag(anchor, "kind", "beforeInstruction") and c.flag(anchor, "inSupportedBody", true) and self.guards[index] == null, "source guard lost its unique body position");
            try ctx.require(c.none(item, "unsupportedReason"), "unsupported source guard semantics");
            if (length_slices) try self.lengthGuard(item, index);
            self.guards[index] = item;
            self.guard_positions[index] = position;
        }
    }

    // A fused bounded slice must retain the original view, shifted pointer,
    // requested length and nonwrapping start+length operation. Other length
    // forms still reject; normal body decoding checks all types and dominance.
    fn lengthGuard(self: *Decoder, guard: Value, anchor: usize) Error!void {
        const ctx = self.ctx;
        try ctx.require(anchor < self.instructions.len, "length-based slice anchor is outside AIR");
        const slice = self.instructions[anchor];
        const upper = try ctx.field(guard, "upperBound");
        try ctx.require(c.tag(slice, "tag", "slice") and c.tag(upper, "kind", "sliceLength"), "unsupported length-based slice bound");
        const end = (try self.refId(try ctx.field(guard, "end"))) orelse return ctx.fail("length-based slice lost its computed end", .{});
        const shifted = (try self.refId(try ctx.field(slice, "lhs"))) orelse return ctx.fail("length-based slice lost its shifted pointer", .{});
        const addition = self.instructions[end];
        const pointer = self.instructions[shifted];
        try ctx.require(c.oneOf(try ctx.str(try ctx.field(addition, "tag")), &.{ "add", "add_safe" }) and c.tag(pointer, "tag", "ptr_add"), "length-based slice lost its address or overflow obligations");
        const start = try ctx.field(guard, "start");
        try ctx.require(c.equal(try ctx.field(addition, "lhs"), start) and c.equal(try ctx.field(addition, "rhs"), try ctx.field(slice, "rhs")) and c.equal(try ctx.field(pointer, "rhs"), start), "length-based slice guard disagrees with its result");
        const base = (try self.refId(try ctx.field(pointer, "lhs"))) orelse return ctx.fail("length-based slice lost its original view", .{});
        try ctx.require(c.tag(self.instructions[base], "tag", "slice_ptr") and c.equal(try ctx.field(self.instructions[base], "operand"), try ctx.field(upper, "original")), "length-based slice changed its original extent");
    }
    pub fn reference(self: *Decoder, value: Value, env: Env, scalar_only: bool) Error!Reference {
        const ctx = self.ctx;
        if (c.tag(value, "kind", "instruction")) {
            try ctx.fields(value, "kind index");
            const index = try ctx.nat(try ctx.field(value, "index"), self.instructions.len - 1);
            const ty = env[index] orelse return ctx.fail("AIR reference is not dominated by its definition", .{});
            return .{ .ty = ty, .text = try ctx.fmt("(.local {d})", .{index}) };
        }
        if (self.options.extension == .slice_view and c.tag(value, "kind", "emptySlice")) {
            try ctx.fields(value, "kind type length origin");
            try ctx.require(try ctx.nat(try ctx.field(value, "length"), 0) == 0, "empty slice has data");
            const ty = try types.parse(ctx, try ctx.field(value, "type"), .aggregate, 0);
            try ctx.require(ty.* == .slice and !ty.slice.mutable and ty.slice.child.isInt(false, 8), "empty slice changes result type");
            const origin = try ctx.field(value, "origin");
            try ctx.fields(origin, "kind byteOffset objectType pointerType");
            try ctx.require(c.tag(origin, "kind", "unnamedConstant") and try ctx.nat(try ctx.field(origin, "byteOffset"), 0) == 0, "empty slice lacks anonymous zero-offset storage");
            const object = try types.parse(ctx, try ctx.field(origin, "objectType"), .aggregate, 0);
            const pointer = try types.parse(ctx, try ctx.field(origin, "pointerType"), .aggregate, 0);
            try ctx.require(object.* == .array and object.array.len == 0 and object.array.child.isInt(false, 8) and isPointer(pointer, false, false, object), "empty slice origin is not a zero-byte array");
            self.empty_constants += 1;
            return .{ .ty = ty, .text = "(.constant .emptyBytes)" };
        }
        return constant(ctx, value, if (scalar_only) .scalar else self.profile);
    }
    fn memoryReference(self: *Decoder, value: Value, env: Env) Error!Reference {
        if (self.profile == .aggregate and !c.tag(value, "kind", "instruction")) return constant(self.ctx, value, .memory);
        return self.reference(value, env, false);
    }
    fn scalarPrimitive(self: *Decoder, text: []const u8) Error![]const u8 {
        if (self.options.extension == .hash_update) return self.ctx.fmt("(.primitive (.memory (.scalar {s})))", .{text});
        return switch (self.profile) {
            .scalar => text,
            .aggregate => self.ctx.fmt("(.memory (.scalar {s}))", .{text}),
            else => self.ctx.fmt("(.scalar {s})", .{text}),
        };
    }
    fn before(self: *Decoder, index: usize, env: Env, prefixes: *std.ArrayList(Prefix)) Error!void {
        const item = self.guards[index] orelse return;
        const ctx = self.ctx;
        const tag = try ctx.str(try ctx.field(self.instructions[index], "tag"));
        try ctx.require(c.oneOf(tag, &.{ "slice", "ptr_cast" }), "source guard does not precede a slice result");
        const start = try self.memoryReference(try ctx.field(item, "start"), env);
        const end = try self.memoryReference(try ctx.field(item, "end"), env);
        try ctx.require(start.ty.isInt(false, 64) and Ty.same(start.ty, end.ty), "source guard does not use usize bounds");
        const bound = try ctx.field(item, "upperBound");
        const upper = blk: {
            if (c.tag(bound, "kind", "sliceLength")) {
                try ctx.fields(bound, "kind original");
                const original = try self.memoryReference(try ctx.field(bound, "original"), env);
                try ctx.require(original.ty.* == .slice, "source guard lost the original slice value");
                break :blk try ctx.fmt("(.slice {s})", .{original.text});
            }
            if (c.tag(bound, "kind", "arrayLength")) {
                try ctx.fields(bound, "kind value");
                break :blk try ctx.fmt("(.array {d})", .{try ctx.nat(try ctx.field(bound, "value"), std.math.maxInt(u64))});
            }
            if (c.tag(bound, "kind", "unboundedPointer")) {
                try ctx.fields(bound, "kind requiresMemoryValidity");
                try ctx.require(c.flag(bound, "requiresMemoryValidity", true), "unbounded slice lost its memory obligation");
                break :blk ".unbounded";
            }
            return ctx.fail("unsupported source guard bound", .{});
        };
        self.guard_seen[index] = true;
        var primitive = try ctx.fmt("(.checkBounds {s} {s} {s})", .{ start.text, end.text, upper });
        if (self.profile.hasCalls()) primitive = try ctx.fmt("(.memory {s})", .{primitive});
        if (self.options.extension == .hash_update) primitive = try ctx.fmt("(.primitive (.memory {s}))", .{primitive}) else if (self.options.extension == .slice_view) primitive = try ctx.fmt("(.memory {s})", .{primitive});
        try prefixes.append(ctx.allocator, .{ .id = self.instructions.len + self.guard_positions[index], .ty = "(.scalar .unit)", .child = primitive });
    }

    fn callPrimitive(self: *Decoder, inst: Value, ty: *const Ty, env: Env) Error![]const u8 {
        const ctx = self.ctx;
        try ctx.fields(inst, "index tag payloadVisited type callee arguments");
        const function = try ctx.field(inst, "callee");
        try ctx.fields(function, "kind identity");
        try ctx.require(c.tag(function, "kind", "function"), "indirect or unsupported callee");
        const identity = try ctx.field(function, "identity");
        try ctx.fields(identity, "name sourceFile sourceSha256");
        for (self.options.callees) |callee| {
            if (!c.equal(try ctx.field(identity, "name"), try ctx.field(callee.record, "name"))) continue;
            try ctx.require(c.equal(try ctx.field(identity, "sourceFile"), try ctx.field(callee.record, "sourceFile")) and c.equal(try ctx.field(identity, "sourceSha256"), try ctx.field(callee.record, "sourceSha256")), "callee declaration/source identity mismatch");
            const signature = try ctx.field(callee.record, "signature");
            const parameters = try ctx.array(try ctx.field(signature, "parameters"));
            const arguments = try ctx.array(try ctx.field(inst, "arguments"));
            try ctx.require(arguments.len == parameters.len and Ty.same(ty, try types.parse(ctx, try ctx.field(signature, "returnType"), .memory, 0)), "call signature mismatch");
            var texts: std.ArrayList([]const u8) = .empty;
            for (arguments, parameters) |argument, parameter| {
                const ref = try self.reference(argument, env, false);
                try ctx.require(Ty.same(ref.ty, try types.parse(ctx, parameter, .memory, 0)), "call argument type mismatch");
                try texts.append(ctx.allocator, ref.text);
            }
            const target = if (self.profile == .nested_calls) switch (callee.profile) {
                .calls => try ctx.fmt("(Compiler.ZigAir.MemoryPartialCall.Target.finite {s}.target)", .{callee.declaration}),
                .call_loops => try ctx.fmt("(Compiler.ZigAir.MemoryPartialCall.Target.loop {s})", .{callee.declaration}),
                .nested_calls => try ctx.fmt("{s}.target", .{callee.declaration}),
                else => return ctx.fail("unsupported callee interpreter", .{}),
            } else blk: {
                try ctx.require(callee.profile == .calls, "a looping callee requires nested-calls");
                break :blk try ctx.fmt("{s}.target", .{callee.declaration});
            };
            if (self.options.call_machine) {
                const index = callee.machine_index orelse return ctx.fail("callee has no checked table index", .{});
                const label = callee.machine_label orelse try ctx.fmt("{d}", .{index});
                return ctx.fmt("(.call {s} [{s}])", .{ label, try std.mem.join(ctx.allocator, ", ", texts.items) });
            }
            return ctx.fmt("(.call {s} [{s}])", .{ target, try std.mem.join(ctx.allocator, ", ", texts.items) });
        }
        return ctx.fail("call target is missing from the admitted closure", .{});
    }

    fn memoryPrimitive(self: *Decoder, inst: Value, ty: *const Ty, env: Env) Error!?[]const u8 {
        const ctx = self.ctx;
        const tag = try ctx.str(try ctx.field(inst, "tag"));
        const base = "index tag payloadVisited type ";
        if (try self.fieldPrimitive(inst, ty, env)) |field| return field;
        if (eq(u8, tag, "not")) {
            try ctx.fields(inst, base ++ "operand");
            const operand = try self.memoryReference(try ctx.field(inst, "operand"), env);
            try ctx.require(ty.* == .boolean and operand.ty.* == .boolean, "unsupported nonboolean complement");
            return try ctx.fmt("(.booleanNot {s})", .{operand.text});
        }
        if (eq(u8, tag, "memcpy")) {
            try ctx.fields(inst, base ++ "lhs rhs");
            const target = try self.memoryReference(try ctx.field(inst, "lhs"), env);
            const input = try self.memoryReference(try ctx.field(inst, "rhs"), env);
            const dest = (target.ty.* == .slice and target.ty.slice.mutable and target.ty.slice.child.isInt(false, 8)) or (target.ty.* == .pointer and target.ty.pointer.mutable and !target.ty.pointer.many and target.ty.pointer.child.* == .array and target.ty.pointer.child.array.child.isInt(false, 8));
            const src = input.ty.* == .pointer and ((input.ty.pointer.many and input.ty.pointer.child.isInt(false, 8)) or (!input.ty.pointer.many and input.ty.pointer.child.* == .array and input.ty.pointer.child.array.child.isInt(false, 8)));
            try ctx.require(dest and src and ty.* == .unit, "unsupported byte-copy operands");
            return try ctx.fmt("(.copyBytes {s} {s})", .{ target.text, input.text });
        }
        if (eq(u8, tag, "alloc")) {
            try ctx.fields(inst, base ++ "allocationKind");
            try ctx.require(ty.* == .pointer and ty.pointer.mutable and !ty.pointer.many and c.tag(inst, "allocationKind", "stack"), "unsupported AIR allocation");
            return try ctx.fmt("(.alloc {s})", .{try ty.pointer.child.lean(ctx, .memory)});
        }
        if (c.oneOf(tag, &.{ "store", "store_safe", "ptr_add", "ptr_sub", "ptr_elem_ptr", "slice_elem_ptr", "slice" })) {
            try ctx.fields(inst, base ++ "lhs rhs");
            const left = try self.memoryReference(try ctx.field(inst, "lhs"), env);
            const right = try self.memoryReference(try ctx.field(inst, "rhs"), env);
            if (eq(u8, tag, "slice_elem_ptr")) {
                try ctx.require(left.ty.* == .slice and right.ty.isInt(false, 64) and (try left.ty.slice.child.layout(ctx))[0] > 0 and isPointer(ty, left.ty.slice.mutable, false, left.ty.slice.child), "indexed slice pointer changed type, extent or permissions");
                return try ctx.fmt("(.sliceElementPointer {s} {s})", .{ left.text, right.text });
            }
            try ctx.require(left.ty.* == .pointer, "memory operation requires a pointer");
            const pointer = left.ty.pointer;
            if (c.oneOf(tag, &.{ "store", "store_safe" })) {
                try ctx.require(ty.* == .unit and pointer.mutable and Ty.same(pointer.child, right.ty), "ill-typed AIR store");
                return try ctx.fmt("(.store {s} {s})", .{ left.text, right.text });
            }
            try ctx.require(right.ty.isInt(false, 64) and pointer.many and (try pointer.child.layout(ctx))[0] > 0, "unsupported memory element/offset type");
            if (eq(u8, tag, "slice")) {
                try ctx.require(ty.* == .slice and ty.slice.mutable == pointer.mutable and Ty.same(ty.slice.child, pointer.child), "ill-typed slice construction");
                return try ctx.fmt("(.slice {s} {s} {s})", .{ try ty.lean(ctx, .memory), left.text, right.text });
            }
            if (eq(u8, tag, "ptr_elem_ptr")) {
                try ctx.require(isPointer(ty, pointer.mutable, false, pointer.child), "indexed pointer changed element type or permissions");
                return try ctx.fmt("(.elementPointer {s} {s})", .{ left.text, right.text });
            }
            try ctx.require(Ty.same(ty, left.ty), "pointer arithmetic changed type");
            return try ctx.fmt("(.offsetPointer {s} {s} {s})", .{ c.boolText(eq(u8, tag, "ptr_sub")), left.text, right.text });
        }
        if (!c.oneOf(tag, &.{ "load", "ptr_cast", "array_to_slice", "slice_len", "slice_ptr", "ptr_slice_len_ptr", "ptr_slice_ptr_ptr" })) return null;
        try ctx.fields(inst, base ++ "operand");
        const source = try self.memoryReference(try ctx.field(inst, "operand"), env);
        if (eq(u8, tag, "array_to_slice")) {
            try ctx.require(source.ty.* == .pointer and !source.ty.pointer.many and source.ty.pointer.child.* == .array and ty.* == .slice and ty.slice.mutable == source.ty.pointer.mutable and Ty.same(ty.slice.child, source.ty.pointer.child.array.child), "array-to-slice changes type or permissions");
            return try ctx.fmt("(.arrayToSlice {s})", .{source.text});
        }
        if (eq(u8, tag, "ptr_cast")) {
            if (ty.* == .slice) {
                try ctx.require(source.ty.* == .slice and (!ty.slice.mutable or source.ty.slice.mutable) and Ty.same(ty.slice.child, source.ty.slice.child), "unsupported slice cast");
                return try ctx.fmt("(.sliceCast {s} {s})", .{ try ty.lean(ctx, .memory), source.text });
            }
            try ctx.require(source.ty.* == .pointer and ty.* == .pointer and (!ty.pointer.mutable or source.ty.pointer.mutable), "unsupported pointer cast");
            const child = source.ty.pointer.child;
            const dest = ty.pointer.child;
            try ctx.require(Ty.same(child, dest) or (child.* == .array and Ty.same(child.array.child, dest)) or (dest.* == .array and Ty.same(dest.array.child, child)), "unsupported pointer reinterpretation");
            return try ctx.fmt("(.pointerCast {s} {s})", .{ try ty.lean(ctx, .memory), source.text });
        }
        if (eq(u8, tag, "load")) {
            try ctx.require(source.ty.* == .pointer and Ty.same(source.ty.pointer.child, ty) and ty.* != .array, "unsupported or ill-typed AIR load");
            return try ctx.fmt("(.load {s})", .{source.text});
        }
        if (c.oneOf(tag, &.{ "slice_len", "slice_ptr" })) {
            try ctx.require(source.ty.* == .slice, "slice projection lost its slice");
            const expected = if (eq(u8, tag, "slice_len")) ty.isInt(false, 64) else isPointer(ty, source.ty.slice.mutable, true, source.ty.slice.child);
            try ctx.require(expected, "ill-typed slice projection");
            return try ctx.fmt("(.{s} {s})", .{ if (eq(u8, tag, "slice_len")) "sliceLen" else "slicePtr", source.text });
        }
        try ctx.require(source.ty.* == .pointer and source.ty.pointer.child.* == .slice, "slice field projection lost its owner");
        const child = source.ty.pointer.child.slice;
        try ctx.require(ty.* == .pointer and ty.pointer.mutable == source.ty.pointer.mutable and !ty.pointer.many, "ill-typed slice field projection");
        try ctx.require(if (eq(u8, tag, "ptr_slice_len_ptr")) ty.pointer.child.isInt(false, 64) else isPointer(ty.pointer.child, child.mutable, true, child.child), "ill-typed slice field projection");
        return try ctx.fmt("(.pointerField {s} {s})", .{ c.boolText(eq(u8, tag, "ptr_slice_len_ptr")), source.text });
    }
    fn fieldPrimitive(self: *Decoder, inst: Value, ty: *const Ty, env: Env) Error!?[]const u8 {
        const ctx = self.ctx;
        const tag = try ctx.str(try ctx.field(inst, "tag"));
        if (!eq(u8, tag, "struct_field_ptr") and !std.mem.startsWith(u8, tag, "struct_field_ptr_index_")) return null;
        try ctx.fields(inst, "index tag payloadVisited type operand fieldIndex");
        const owner = try self.reference(try ctx.field(inst, "operand"), env, false);
        try ctx.require(owner.ty.* == .pointer and owner.ty.pointer.child.* == .structure, "field pointer lacks complete declaration");
        const fields = owner.ty.pointer.child.structure.fields;
        try ctx.require(fields.len > 0, "field pointer has no declared field");
        const index = try ctx.nat(try ctx.field(inst, "fieldIndex"), fields.len - 1);
        if (!eq(u8, tag, "struct_field_ptr")) try ctx.require(c.oneOf(tag, &.{ "struct_field_ptr_index_0", "struct_field_ptr_index_1", "struct_field_ptr_index_2", "struct_field_ptr_index_3" }) and tag[tag.len - 1] - '0' == index, "fixed field pointer changes index");
        try ctx.require(isPointer(ty, owner.ty.pointer.mutable, false, fields[index].ty), "field pointer changes type or permissions");
        return try ctx.fmt("(.fieldPointer {s} {d})", .{ owner.text, fields[index].offset });
    }
    fn aggregatePrimitive(self: *Decoder, inst: Value, ty: *const Ty, env: Env) Error!?[]const u8 {
        const ctx = self.ctx;
        const tag = try ctx.str(try ctx.field(inst, "tag"));
        const base = "index tag payloadVisited type ";
        if (eq(u8, tag, "load")) {
            try ctx.fields(inst, base ++ "operand");
            const source = try self.reference(try ctx.field(inst, "operand"), env, false);
            try ctx.require(source.ty.* == .pointer and Ty.same(source.ty.pointer.child, ty) and ty.* != .array, "unsupported aggregate AIR load");
            return try ctx.fmt("(.load {s})", .{source.text});
        }
        if (c.oneOf(tag, &.{ "store", "store_safe" })) {
            try ctx.fields(inst, base ++ "lhs rhs");
            const left = try self.reference(try ctx.field(inst, "lhs"), env, false);
            const right = try self.reference(try ctx.field(inst, "rhs"), env, false);
            try ctx.require(left.ty.* == .pointer and left.ty.pointer.mutable and Ty.same(left.ty.pointer.child, right.ty) and ty.* == .unit, "ill-typed aggregate AIR store");
            return try ctx.fmt("(.store {s} {s})", .{ left.text, right.text });
        }
        if (try self.fieldPrimitive(inst, ty, env)) |field| return field;
        if (eq(u8, tag, "ptr_elem_ptr")) {
            const source = try self.reference(try ctx.field(inst, "lhs"), env, false);
            if (source.ty.* == .pointer and !source.ty.pointer.many and source.ty.pointer.child.* == .array) {
                try ctx.fields(inst, base ++ "lhs rhs");
                const index = try self.reference(try ctx.field(inst, "rhs"), env, false);
                try ctx.require(index.ty.isInt(false, 64) and isPointer(ty, source.ty.pointer.mutable, false, source.ty.pointer.child.array.child), "array element pointer changes type");
                return try ctx.fmt("(.arrayElementPointer {s} {s})", .{ source.text, index.text });
            }
        }
        const prim = try self.memoryPrimitive(inst, ty, env) orelse return null;
        return try ctx.fmt("(.memory {s})", .{prim});
    }

    fn refId(self: *Decoder, value: Value) Error!?usize {
        if (!c.tag(value, "kind", "instruction")) return null;
        return @intCast(try self.ctx.nat(try self.ctx.field(value, "index"), self.instructions.len - 1));
    }
    fn mark(self: *Decoder, index: usize, origin: usize, ty: *const Ty) Error!void {
        self.byte_values[index] = origin;
        self.byte_alignments[index] = try ty.alignment(self.ctx);
    }
    fn bytePrimitive(self: *Decoder, inst: Value, ty: *const Ty, env: Env) Error!?[]const u8 {
        const ctx = self.ctx;
        const tag = try ctx.str(try ctx.field(inst, "tag"));
        const index: usize = @intCast(try ctx.nat(try ctx.field(inst, "index"), self.instructions.len - 1));
        const raw = ty.raw();
        const base = "index tag payloadVisited type ";
        if (eq(u8, tag, "alloc") and ty.hasAlignment()) {
            try ctx.fields(inst, base ++ "allocationKind");
            try ctx.require(ty.* == .pointer and ty.pointer.mutable and !ty.pointer.many and ty.pointer.child.* == .aligned and ty.pointer.child.raw().* == .slice and c.tag(inst, "allocationKind", "stack"), "byte view storage must be a fresh stack slice slot");
            self.byte_slots[index] = index;
            return try ctx.fmt("(.alloc {s})", .{try ty.pointer.child.lean(ctx, .memory)});
        }
        if (c.oneOf(tag, &.{ "ptr_cast", "load", "slice_len", "slice_ptr" })) {
            try ctx.fields(inst, base ++ "operand");
            const operand = try ctx.field(inst, "operand");
            const source = try self.reference(operand, env, false);
            const parent = try self.refId(operand);
            const src = source.ty.raw();
            if (eq(u8, tag, "ptr_cast") and raw.* == .pointer and raw.pointer.child.isInt(false, 8) and src.* == .pointer and src.pointer.child.isInt(false, 32)) {
                const alignment = try ty.alignment(ctx);
                try ctx.require(!src.pointer.many and (!raw.pointer.mutable or src.pointer.mutable) and (alignment == 1 or alignment == 2 or alignment == 4), "unsupported word-to-byte cast contract");
                try self.mark(index, index, ty);
                return try ctx.fmt("(.wordByteCast {s} {s} {d} {s})", .{ c.boolText(raw.pointer.mutable), c.boolText(raw.pointer.many), alignment, source.text });
            }
            if (parent) |p| {
                if (eq(u8, tag, "ptr_cast") and self.byte_slots[p] != null) {
                    try ctx.require(source.ty.* == .pointer and isPointer(ty, false, false, source.ty.pointer.child), "byte slice slot cast changes storage or permissions");
                    self.byte_slots[index] = self.byte_slots[p];
                    return try ctx.fmt("(.pointerCast {s} {s})", .{ try ty.lean(ctx, .memory), source.text });
                }
                if (eq(u8, tag, "load") and self.byte_slots[p] != null) {
                    try ctx.require(source.ty.* == .pointer and Ty.same(source.ty.pointer.child, ty), "byte slice slot load changes its stored type");
                    try self.mark(index, self.byte_slots[p].?, ty);
                    return try ctx.fmt("(.load {s})", .{source.text});
                }
                if (eq(u8, tag, "load") and self.byte_values[p] != null) {
                    try ctx.require(src.* == .pointer and ty.isInt(false, 8), "byte view load changes its element type");
                    return try ctx.fmt("(.wordByteLoad .little {s})", .{source.text});
                }
                if (c.oneOf(tag, &.{ "slice_len", "slice_ptr" }) and self.byte_values[p] != null) {
                    try ctx.require(src.* == .slice, "byte slice projection loses alignment or type");
                    const expected = if (eq(u8, tag, "slice_len")) raw.isInt(false, 64) else raw.* == .pointer and raw.pointer.mutable == src.slice.mutable and raw.pointer.many and raw.pointer.child.isInt(false, 8);
                    try ctx.require(expected and (eq(u8, tag, "slice_len") or try ty.alignment(ctx) == try source.ty.alignment(ctx)), "byte slice projection loses alignment or type");
                    if (eq(u8, tag, "slice_ptr")) try self.mark(index, self.byte_values[p].?, ty);
                    return try ctx.fmt("(.{s} {s})", .{ if (eq(u8, tag, "slice_len")) "sliceLen" else "slicePtr", source.text });
                }
                try ctx.require(self.byte_values[p] == null and self.byte_slots[p] == null and !source.ty.hasAlignment() and !ty.hasAlignment(), "unsupported byte view propagation");
            } else try ctx.require(!source.ty.hasAlignment() and !ty.hasAlignment(), "unsupported byte view propagation");
        }
        if (c.oneOf(tag, &.{ "slice", "slice_elem_ptr", "store", "store_safe" })) {
            try ctx.fields(inst, base ++ "lhs rhs");
            const lhs = try ctx.field(inst, "lhs");
            const rhs = try ctx.field(inst, "rhs");
            const left = try self.reference(lhs, env, false);
            const right = try self.reference(rhs, env, false);
            const parent = try self.refId(lhs);
            const value = try self.refId(rhs);
            const src = left.ty.raw();
            if (parent) |p| {
                if (eq(u8, tag, "slice") and self.byte_values[p] != null) {
                    try ctx.require(raw.* == .slice and raw.slice.child.isInt(false, 8) and src.* == .pointer and src.pointer.mutable == raw.slice.mutable and src.pointer.many and src.pointer.child.isInt(false, 8) and try ty.alignment(ctx) == try left.ty.alignment(ctx) and right.ty.isInt(false, 64), "byte slice must retain its four-byte extent and alignment");
                    try ctx.require(c.tag(rhs, "kind", "constant") and try ctx.integer(try ctx.field(rhs, "value")) == 4, "byte slice must retain its four-byte extent and alignment");
                    try self.mark(index, self.byte_values[p].?, ty);
                    return try ctx.fmt("(.slice {s} {s} {s})", .{ try ty.lean(ctx, .memory), left.text, right.text });
                }
                if (eq(u8, tag, "slice_elem_ptr") and self.byte_values[p] != null) {
                    try ctx.require(src.* == .slice and raw.* == .pointer and raw.pointer.mutable == src.slice.mutable and !raw.pointer.many and raw.pointer.child.isInt(false, 8) and try ty.alignment(ctx) == 1 and right.ty.isInt(false, 64), "byte element loses type, alignment or permissions");
                    try self.mark(index, self.byte_values[p].?, ty);
                    return try ctx.fmt("(.sliceElementPointer {s} {s})", .{ left.text, right.text });
                }
                if (c.oneOf(tag, &.{ "store", "store_safe" }) and self.byte_slots[p] != null) {
                    try ctx.require(ty.* == .unit and left.ty.* == .pointer and left.ty.pointer.mutable and Ty.same(left.ty.pointer.child, right.ty) and value != null and self.byte_values[value.?] != null, "byte slice slot store lost its checked origin");
                    return try ctx.fmt("(.store {s} {s})", .{ left.text, right.text });
                }
                if (c.oneOf(tag, &.{ "store", "store_safe" }) and self.byte_values[p] != null) {
                    try ctx.require(ty.* == .unit and src.* == .pointer and src.pointer.mutable and right.ty.isInt(false, 8), "ill-typed byte view store");
                    return try ctx.fmt("(.wordByteStore .little {s} {s})", .{ left.text, right.text });
                }
            }
            try ctx.require((parent == null or (self.byte_values[parent.?] == null and self.byte_slots[parent.?] == null)) and (value == null or (self.byte_values[value.?] == null and self.byte_slots[value.?] == null)) and !ty.hasAlignment() and !left.ty.hasAlignment() and !right.ty.hasAlignment(), "byte view or stack slot escaped checked storage");
        }
        for ([_][]const u8{ "operand", "lhs", "rhs" }) |key| if (c.get(inst, key)) |operand| {
            const reference_value = try self.reference(operand, env, false);
            const id = try self.refId(operand);
            if ((id != null and (self.byte_values[id.?] != null or self.byte_slots[id.?] != null)) or reference_value.ty.hasAlignment()) return ctx.fail("byte provenance cannot escape through {s}", .{tag});
        };
        try ctx.require(!ty.hasAlignment(), "aligned result has no checked byte origin");
        return self.memoryPrimitive(inst, ty, env);
    }

    fn extraPrimitive(self: *Decoder, inst: Value, ty: *const Ty, env: Env) Error!?[]const u8 {
        const ctx = self.ctx;
        const tag = try ctx.str(try ctx.field(inst, "tag"));
        const base = "index tag payloadVisited type ";
        if (self.options.extension == .assertion and eq(u8, tag, "not")) {
            try ctx.fields(inst, base ++ "operand");
            const source = try self.reference(try ctx.field(inst, "operand"), env, false);
            try ctx.require(source.ty.* == .boolean and ty.* == .boolean, "assert not must be boolean");
            return try ctx.fmt("(.booleanNot {s})", .{source.text});
        }
        if (self.options.extension == .scalar_view and eq(u8, tag, "ptr_cast")) {
            try ctx.fields(inst, base ++ "operand");
            const source = try self.reference(try ctx.field(inst, "operand"), env, false);
            try ctx.require(source.ty.* == .pointer and !source.ty.pointer.mutable and !source.ty.pointer.many and source.ty.pointer.child.isInt(false, @intCast(self.options.view_count * 8)) and ty.* == .pointer and !ty.pointer.mutable and !ty.pointer.many and ty.pointer.child.* == .array and ty.pointer.child.array.len == self.options.view_count and ty.pointer.child.array.child.isInt(false, 8), "asBytes cast changed");
            return try ctx.fmt("(.scalarByteArray false {d} {d} {s})", .{ self.options.view_alignment, self.options.view_count, source.text });
        }
        if (self.options.extension == .slice_view and eq(u8, tag, "ptr_cast")) {
            try ctx.fields(inst, base ++ "operand");
            const source = try self.reference(try ctx.field(inst, "operand"), env, false);
            if (source.ty.* == .pointer and !source.ty.pointer.mutable and source.ty.pointer.many and source.ty.pointer.child.isInt(false, 32)) {
                try ctx.require(ty.* == .pointer and !ty.pointer.mutable and ty.pointer.many and ty.pointer.child.isInt(false, 8), "word-to-byte pointer contract changed");
                return try ctx.fmt("(.memory (.wordByteCast false true 4 {s}))", .{source.text});
            }
        }
        if (self.options.extension != .hash_update) return null;
        if (eq(u8, tag, "memcpy")) {
            try ctx.fields(inst, base ++ "lhs rhs");
            const target = try self.reference(try ctx.field(inst, "lhs"), env, false);
            const source = try self.reference(try ctx.field(inst, "rhs"), env, false);
            const dest = (target.ty.* == .slice and target.ty.slice.mutable and target.ty.slice.child.isInt(false, 8)) or (target.ty.* == .pointer and target.ty.pointer.mutable and !target.ty.pointer.many and target.ty.pointer.child.* == .array and target.ty.pointer.child.array.child.isInt(false, 8));
            const src = source.ty.* == .pointer and ((source.ty.pointer.many and source.ty.pointer.child.isInt(false, 8)) or (!source.ty.pointer.many and source.ty.pointer.child.* == .array and source.ty.pointer.child.array.child.isInt(false, 8)));
            try ctx.require(dest and src and ty.* == .unit, "unsupported memcpy operands");
            return try ctx.fmt("(.copyBytes {s} {s})", .{ target.text, source.text });
        }
        if (eq(u8, tag, "call")) {
            try ctx.fields(inst, base ++ "callee arguments");
            const callee = try ctx.field(inst, "callee");
            try ctx.fields(callee, "kind identity");
            const assertion = self.options.assertion orelse return ctx.fail("missing assertion record", .{});
            var identity: Value = .{ .object = .empty };
            for ([_][]const u8{ "name", "sourceFile", "sourceSha256" }) |key| try identity.object.put(ctx.allocator, key, try ctx.field(assertion, key));
            try ctx.require(c.tag(callee, "kind", "function") and c.equal(try ctx.field(callee, "identity"), identity), "update callee identity changed");
            const arguments = try ctx.array(try ctx.field(inst, "arguments"));
            try ctx.require(arguments.len == 1 and ty.* == .unit, "assert call shape changed");
            const argument = try self.reference(arguments[0], env, false);
            try ctx.require(argument.ty.* == .boolean, "assert argument is not boolean");
            return try ctx.fmt("(.invoke assertion [{s}])", .{argument.text});
        }
        if (eq(u8, tag, "load") and ty.* == .array) {
            try ctx.fields(inst, base ++ "operand");
            const source = try self.reference(try ctx.field(inst, "operand"), env, false);
            try ctx.require(ty.array.len == 8 and ty.array.child.isInt(false, 8) and source.ty.* == .pointer and !source.ty.pointer.many and Ty.same(source.ty.pointer.child, ty), "unsupported byte-array load");
            return try ctx.fmt("(.primitive (.loadBytes {s}))", .{source.text});
        }
        if (eq(u8, tag, "bit_cast")) {
            try ctx.fields(inst, base ++ "operand");
            const source = try self.reference(try ctx.field(inst, "operand"), env, false);
            if (source.ty.* == .array) {
                try ctx.require(source.ty.array.len == 8 and source.ty.array.child.isInt(false, 8) and ty.isInt(false, 64), "byte-array bitcast changed width");
                return try ctx.fmt("(.primitive (.bytesToWord {s}))", .{source.text});
            }
        }
        if (eq(u8, tag, "array_to_slice")) {
            try ctx.fields(inst, base ++ "operand");
            const source = try self.reference(try ctx.field(inst, "operand"), env, false);
            try ctx.require(source.ty.* == .pointer and !source.ty.pointer.many and source.ty.pointer.child.* == .array and ty.* == .slice and ty.slice.mutable == source.ty.pointer.mutable and Ty.same(ty.slice.child, source.ty.pointer.child.array.child), "array-to-slice changes type");
            return try ctx.fmt("(.primitive (.arrayToSlice {s}))", .{source.text});
        }
        return null;
    }

    fn body(self: *Decoder, indices_value: Value, incoming: Env, labels: Labels, depth: usize) Error![]const u8 {
        const ctx = self.ctx;
        const indices = try ctx.array(indices_value);
        try ctx.require(indices.len > 0 and depth <= 64, "empty, malformed or too deeply nested AIR body");
        const env = try ctx.allocator.dupe(?*const Ty, incoming);
        var prefixes: std.ArrayList(Prefix) = .empty;
        var terminal: ?[]const u8 = null;
        for (indices, 0..) |raw_index, position| {
            const index: usize = @intCast(try ctx.nat(raw_index, self.instructions.len - 1));
            try ctx.require(!self.visited[index] and terminal == null, "duplicate AIR body ownership or code after terminator");
            self.visited[index] = true;
            const inst = self.instructions[index];
            try ctx.require(c.flag(inst, "payloadVisited", true) and c.get(inst, "unsupportedPayload") == null, "unsupported or unvisited AIR body instruction");
            const tag = try ctx.str(try ctx.field(inst, "tag"));
            try @import("admission.zig").require(ctx, tag);
            const ty = try types.parse(ctx, try ctx.field(inst, "type"), self.profile, 0);
            const base = "index tag payloadVisited type ";
            try self.before(index, env, &prefixes);
            const direct_call = self.profile.hasCalls() and c.oneOf(tag, &.{ "call", "call_never_inline", "call_never_tail" });
            var primitive: ?[]const u8 = if (direct_call) try self.callPrimitive(inst, ty, env) else try self.extraPrimitive(inst, ty, env);
            if (primitive == null and c.oneOf(tag, &.{ "slice_elem_val", "ptr_elem_val" })) {
                try ctx.require(self.profile == .memory or self.profile == .loops or self.profile.hasCalls(), "element reads require the memory vocabulary");
                try ctx.fields(inst, base ++ "lhs rhs");
                const owner = try self.memoryReference(try ctx.field(inst, "lhs"), env);
                const element = try self.memoryReference(try ctx.field(inst, "rhs"), env);
                const slice = eq(u8, tag, "slice_elem_val");
                try ctx.require(element.ty.isInt(false, 64) and ty.isInt(false, 8), "unsupported byte-element result or index type");
                try ctx.require(if (slice) owner.ty.* == .slice and owner.ty.slice.child.isInt(false, 8) else owner.ty.* == .pointer and owner.ty.pointer.many and owner.ty.pointer.child.isInt(false, 8), "byte-element read lost its owner");
                const mutable = if (slice) owner.ty.slice.mutable else owner.ty.pointer.mutable;
                // Temporary IDs are disjoint from captured registers and source guards.
                const temporary = self.instructions.len + (try ctx.array(try ctx.field(try ctx.field(self.record, "sourceValidity"), "slices"))).len + index;
                const select = try ctx.fmt("(.{s} {s} {s})", .{ if (slice) "sliceElementPointer" else "elementPointer", owner.text, element.text });
                try prefixes.append(ctx.allocator, .{ .id = temporary, .ty = try ctx.fmt("(.pointer {s} false (.scalar (.int false 8)))", .{c.boolText(mutable)}), .child = if (self.profile.hasCalls()) try ctx.fmt("(.memory {s})", .{select}) else select });
                primitive = try ctx.fmt("(.load (.local {d}))", .{temporary});
            }
            if (primitive == null) {
                primitive = switch (self.profile) {
                    .scalar => null,
                    .aggregate => try self.aggregatePrimitive(inst, ty, env),
                    .word_bytes, .word_byte_loops => try self.bytePrimitive(inst, ty, env),
                    else => try self.memoryPrimitive(inst, ty, env),
                };
                if (primitive != null and self.options.extension == .hash_update) primitive = try ctx.fmt("(.primitive {s})", .{primitive.?});
            }
            if (primitive != null) {} else if (eq(u8, tag, "arg")) {
                try ctx.fields(inst, base ++ "zirParameterIndex");
                try ctx.require(depth == 0 and position == self.arguments and self.arguments < self.parameters.len, "invalid AIR argument prefix");
                const source_index = if (self.options.source_parameters) |mapping| mapping[self.arguments] else self.arguments;
                try ctx.require(try ctx.nat(try ctx.field(inst, "zirParameterIndex"), 511) == source_index and Ty.same(ty, self.parameters[self.arguments]), "AIR argument disagrees with signature");
                primitive = try ctx.fmt("(.argument {d})", .{self.arguments});
                if (self.options.extension == .hash_update) primitive = try ctx.fmt("(.primitive {s})", .{primitive.?});
                self.arguments += 1;
            } else if (c.oneOf(tag, &.{ "add", "sub", "mul", "add_safe", "sub_safe", "mul_safe", "add_wrap", "sub_wrap", "mul_wrap" })) {
                try ctx.fields(inst, base ++ "lhs rhs");
                const left = try self.reference(try ctx.field(inst, "lhs"), env, self.profile != .scalar);
                const right = try self.reference(try ctx.field(inst, "rhs"), env, self.profile != .scalar);
                try ctx.require(Ty.same(left.ty, right.ty) and Ty.same(left.ty, ty) and ty.* == .int, "ill-typed AIR arithmetic");
                const stop = std.mem.indexOfScalar(u8, tag, '_') orelse tag.len;
                const mode = if (std.mem.endsWith(u8, tag, "_safe")) "checked" else if (std.mem.endsWith(u8, tag, "_wrap")) "wrapping" else "unchecked";
                primitive = try self.scalarPrimitive(try ctx.fmt("(.arithmetic .{s} .{s} {s} {s})", .{ tag[0..stop], mode, left.text, right.text }));
            } else if (c.oneOf(tag, &.{ "bit_and", "xor", "shr" })) {
                try ctx.fields(inst, base ++ "lhs rhs");
                const left = try self.reference(try ctx.field(inst, "lhs"), env, self.profile != .scalar);
                const right = try self.reference(try ctx.field(inst, "rhs"), env, self.profile != .scalar);
                try ctx.require(Ty.same(left.ty, ty) and left.ty.* == .int and !left.ty.int.signed and right.ty.* == .int and !right.ty.int.signed, "unsupported or ill-typed unsigned AIR bit operation");
                if (eq(u8, tag, "shr")) {
                    try ctx.require(left.ty.int.bits > 0, "right shift has an invalid count type");
                    const width: u16 = 16 - @clz(left.ty.int.bits - 1);
                    try ctx.require(right.ty.int.bits == width, "right shift has an invalid count type");
                } else try ctx.require(Ty.same(left.ty, right.ty), "bitwise operation changes operand width");
                primitive = try self.scalarPrimitive(try ctx.fmt("(.{s} {s} {s})", .{ if (eq(u8, tag, "shr")) "shiftRight" else if (eq(u8, tag, "xor")) "bitXor" else "bitAnd", left.text, right.text }));
            } else if (c.oneOf(tag, &.{ "min", "max" })) {
                try ctx.fields(inst, base ++ "lhs rhs");
                const left = try self.reference(try ctx.field(inst, "lhs"), env, self.profile != .scalar);
                const right = try self.reference(try ctx.field(inst, "rhs"), env, self.profile != .scalar);
                try ctx.require(left.ty.* == .int and Ty.same(left.ty, right.ty) and Ty.same(left.ty, ty), "integer extremum changes operand or result type");
                primitive = try self.scalarPrimitive(try ctx.fmt("(.extremum {s} {s} {s})", .{ c.boolText(eq(u8, tag, "max")), left.text, right.text }));
            } else if (c.oneOf(tag, &.{ "cmp_eq", "cmp_neq", "cmp_lt", "cmp_lte", "cmp_gt", "cmp_gte" })) {
                try ctx.fields(inst, base ++ "lhs rhs");
                const left = try self.reference(try ctx.field(inst, "lhs"), env, self.profile != .scalar);
                const right = try self.reference(try ctx.field(inst, "rhs"), env, self.profile != .scalar);
                try ctx.require(Ty.same(left.ty, right.ty) and left.ty.* == .int and ty.* == .boolean, "ill-typed AIR comparison");
                const op = if (eq(u8, tag, "cmp_eq")) "eq" else if (eq(u8, tag, "cmp_neq")) "ne" else if (eq(u8, tag, "cmp_lt")) "lt" else if (eq(u8, tag, "cmp_lte")) "le" else if (eq(u8, tag, "cmp_gt")) "gt" else "ge";
                primitive = try self.scalarPrimitive(try ctx.fmt("(.comparison .{s} {s} {s})", .{ op, left.text, right.text }));
            } else if (c.oneOf(tag, &.{ "int_cast", "int_cast_safe", "bit_cast", "trunc" })) {
                try ctx.fields(inst, base ++ "operand");
                const source = try self.reference(try ctx.field(inst, "operand"), env, self.profile != .scalar);
                try ctx.require(source.ty.* == .int and ty.* == .int, "unsupported AIR cast types");
                if (eq(u8, tag, "bit_cast")) try ctx.require(source.ty.int.bits == ty.int.bits, "bitcast changes width");
                if (eq(u8, tag, "trunc")) try ctx.require(source.ty.int.signed == ty.int.signed and source.ty.int.bits >= ty.int.bits, "invalid truncation");
                primitive = try self.scalarPrimitive(try ctx.fmt("(.cast .{s} {s} {s})", .{ if (eq(u8, tag, "int_cast")) "unchecked" else if (eq(u8, tag, "int_cast_safe")) "checked" else if (eq(u8, tag, "bit_cast")) "bitcast" else "trunc", try ty.lean(ctx, .scalar), source.text }));
            } else if (eq(u8, tag, "block")) {
                try ctx.fields(inst, base ++ "body");
                const nested = try ctx.allocator.dupe(?Label, labels);
                nested[index] = .{ .block = ty };
                try prefixes.append(ctx.allocator, .{ .kind = "block", .id = index, .ty = try ty.lean(ctx, self.profile), .child = try self.body(try ctx.field(inst, "body"), env, nested, depth + 1) });
                env[index] = ty;
            } else if (eq(u8, tag, "loop") and (self.profile.hasLoops() or self.options.extension == .hash_update)) {
                try ctx.fields(inst, base ++ "body");
                try ctx.require(ty.* == .noreturn, "AIR loop must be non-returning");
                self.loop_ids[index] = true;
                const nested = try ctx.allocator.dupe(?Label, labels);
                nested[index] = .loop;
                const child = try self.body(try ctx.field(inst, "body"), env, nested, depth + 1);
                terminal = if (self.options.call_machine) try ctx.fmt(".loop rfl {d} <|\n{s}", .{ index, child }) else try ctx.fmt("(.loop rfl {d}\n  {s})", .{ index, child });
            } else if (eq(u8, tag, "repeat") and (self.profile.hasLoops() or self.options.extension == .hash_update)) {
                try ctx.fields(inst, base ++ "target");
                const target = try ctx.nat(try ctx.field(inst, "target"), self.instructions.len - 1);
                try ctx.require(ty.* == .noreturn and labels[target] != null and labels[target].? == .loop, "AIR repeat must target an enclosing loop");
                self.repeats[target] = true;
                terminal = try ctx.fmt("(.repeat rfl {d})", .{target});
            } else if (eq(u8, tag, "cond_br")) {
                try ctx.fields(inst, base ++ "condition thenBody elseBody");
                const condition = try self.reference(try ctx.field(inst, "condition"), env, false);
                try ctx.require(condition.ty.* == .boolean and ty.* == .noreturn, "ill-typed AIR conditional branch");
                const yes = try self.body(try ctx.field(inst, "thenBody"), env, labels, depth + 1);
                const no = try self.body(try ctx.field(inst, "elseBody"), env, labels, depth + 1);
                terminal = if (self.options.call_machine)
                    try ctx.fmt(".branch {s}\n  (\n{s}\n  )\n  (\n{s}\n  )", .{ condition.text, try indent(ctx, yes, 4), try indent(ctx, no, 4) })
                else
                    try ctx.fmt("(.branch {s}\n  {s}\n  {s})", .{ condition.text, yes, no });
            } else if (eq(u8, tag, "br")) {
                try ctx.fields(inst, base ++ "target operand");
                const target = try ctx.nat(try ctx.field(inst, "target"), self.instructions.len - 1);
                const operand = try self.reference(try ctx.field(inst, "operand"), env, false);
                try ctx.require(labels[target] != null and labels[target].? == .block and Ty.same(labels[target].?.block, operand.ty) and ty.* == .noreturn, "invalid AIR block destination or result");
                terminal = try ctx.fmt("(.jump {d} {s})", .{ target, operand.text });
            } else if (eq(u8, tag, "unreach") and self.options.extension == .assertion) {
                try ctx.fields(inst, "index tag payloadVisited type");
                try ctx.require(ty.* == .noreturn, "unreachable has a result");
                terminal = try ctx.fmt("(.bind {d} (.scalar .unit) .unreachable (.ret (.constant (.value (.scalar .unit)))))", .{index});
            } else if (eq(u8, tag, "unreach") and (self.profile == .memory or self.profile == .loops or self.profile.hasCalls())) {
                try ctx.fields(inst, "index tag payloadVisited type");
                try ctx.require(ty.* == .noreturn, "unreachable has a result");
                terminal = try ctx.fmt("(.bind {d} (.scalar .unit) {s} (.ret (.constant (.scalar .unit))))", .{ index, if (self.profile.hasCalls()) "(.memory .unreachable)" else ".unreachable" });
            } else if (c.oneOf(tag, &.{ "ret", "ret_safe" })) {
                try ctx.fields(inst, base ++ "operand");
                const operand = try self.reference(try ctx.field(inst, "operand"), env, false);
                try ctx.require(Ty.same(operand.ty, self.result) and ty.* == .noreturn, "AIR return disagrees with signature");
                terminal = try ctx.fmt("(.ret {s})", .{operand.text});
            } else if (c.oneOf(tag, &.{ "dbg_stmt", "dbg_var_val", "dbg_var_ptr", "dbg_arg_inline" })) {
                try ctx.fields(inst, base ++ "debugOnly");
                try ctx.require(ty.* == .unit and c.flag(inst, "debugOnly", true), "invalid debug-only instruction");
            } else return ctx.fail("unsupported AIR operation: {s}", .{tag});
            if (primitive) |text| {
                try prefixes.append(ctx.allocator, .{ .id = index, .ty = try ty.lean(ctx, self.profile), .child = if (self.profile.hasCalls() and !direct_call) try ctx.fmt("(.memory {s})", .{text}) else text });
                env[index] = ty;
            }
        }
        var result = terminal orelse return ctx.fail("AIR body has no terminator", .{});
        var next = prefixes.items.len;
        while (next > 0) {
            next -= 1;
            const prefix = prefixes.items[next];
            result = if (!self.options.call_machine)
                try ctx.fmt("(.{s} {d} {s}\n  {s}\n  {s})", .{ prefix.kind, prefix.id, prefix.ty, prefix.child, result })
            else if (eq(u8, prefix.kind, "block"))
                try ctx.fmt(".block {d} {s} (\n{s}\n) <|\n{s}", .{ prefix.id, prefix.ty, try indent(ctx, prefix.child, 2), result })
            else
                try ctx.fmt(".bind {d} {s} {s} <|\n{s}", .{ prefix.id, prefix.ty, prefix.child, result });
        }
        return result;
    }

    pub fn program(self: *Decoder) Error![]const u8 {
        const ctx = self.ctx;
        const env = try ctx.allocator.alloc(?*const Ty, self.instructions.len);
        @memset(env, null);
        const labels = try ctx.allocator.alloc(?Label, self.instructions.len);
        @memset(labels, null);
        const code = try self.body(try ctx.field(self.record, "body"), env, labels, 0);
        for (self.loop_ids, self.repeats) |loop_id, repeat| try ctx.require(loop_id == repeat, "AIR loop has no repeat instruction");
        try ctx.require(self.arguments == self.parameters.len, "AIR argument prefix is incomplete");
        for (self.instructions, 0..) |inst, index| if (!self.visited[index]) {
            try ctx.fields(inst, "index tag payloadVisited unsupportedPayload reason");
            try ctx.require(c.flag(inst, "payloadVisited", false) and c.flag(inst, "unsupportedPayload", true) and c.tag(inst, "reason", "outside-decoded-body-closure"), "unaccounted AIR body entry");
        };
        for (self.guards, self.guard_seen) |guard, seen| try ctx.require(guard == null or seen, "source guard was not executed by the decoded body");
        if (self.options.extension == .slice_view) try ctx.require(self.empty_constants == 1, "sliceAsBytes must retain its empty return");
        var parameters: std.ArrayList([]const u8) = .empty;
        for (self.parameters) |ty| try parameters.append(ctx.allocator, try ty.lean(ctx, self.profile));
        if (self.options.call_machine) return ctx.fmt("  {{ parameters := [{s}],\n    returnType := {s},\n    body :=\n{s}\n  }}", .{ try std.mem.join(ctx.allocator, ", ", parameters.items), try self.result.lean(ctx, self.profile), try indent(ctx, code, 6) });
        return ctx.fmt("{{ parameters := [{s}], returnType := {s}, body :=\n  {s} }}", .{ try std.mem.join(ctx.allocator, ", ", parameters.items), try self.result.lean(ctx, self.profile), code });
    }
};

// Indent nested control bodies, while sequential binds remain at one level.
// This only lays out constructor terms; it never rewrites the decoded program.
fn indent(ctx: *Context, text: []const u8, width: usize) Error![]const u8 {
    var output: std.ArrayList(u8) = .empty;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (output.items.len > 0) try output.append(ctx.allocator, '\n');
        try output.appendNTimes(ctx.allocator, ' ', width);
        try output.appendSlice(ctx.allocator, line);
    }
    return output.toOwnedSlice(ctx.allocator);
}

fn isPointer(ty: *const Ty, mutable: bool, many: bool, child: *const Ty) bool {
    return ty.* == .pointer and ty.pointer.mutable == mutable and ty.pointer.many == many and Ty.same(ty.pointer.child, child);
}
pub fn decode(ctx: *Context, record: Value, profile: Profile) Error![]const u8 {
    var decoder = try Decoder.init(ctx, record, profile);
    return decoder.program();
}
