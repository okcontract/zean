// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const c = @import("common.zig");
const Context = c.Context;
const Value = c.Value;
const Error = c.Error;
const target = @import("target.zig");

pub const Capabilities = struct {
    memory: bool,
    loops: bool = false,
    calls: bool = false,
    looping_callees: bool = false,
    recursive_calls: bool = false,
    byte_views: bool = false,
    correspondence: bool = true,
};

pub const Profile = enum {
    scalar,
    memory,
    loops,
    aggregate,
    word_bytes,
    word_byte_loops,
    calls,
    call_loops,
    nested_calls,
    recursive_calls,
    pub fn parse(value: []const u8) ?Profile {
        inline for (std.meta.tags(Profile)) |item| {
            if (std.mem.eql(u8, value, item.name())) return item;
        }
        return null;
    }
    pub fn name(self: Profile) []const u8 {
        return switch (self) {
            .word_bytes => "word-bytes",
            .word_byte_loops => "word-byte-loops",
            .call_loops => "call-loops",
            .nested_calls => "nested-calls",
            .recursive_calls => "recursive-calls",
            else => @tagName(self),
        };
    }
    pub fn hasLoops(self: Profile) bool {
        return self.capabilities().loops;
    }
    pub fn hasCalls(self: Profile) bool {
        return self.capabilities().calls;
    }
    pub fn hasBytes(self: Profile) bool {
        return self.capabilities().byte_views;
    }
    pub fn capabilities(self: Profile) Capabilities {
        return switch (self) {
            .scalar => .{ .memory = false },
            .memory => .{ .memory = true },
            .aggregate => .{ .memory = true, .correspondence = false },
            .loops => .{ .memory = true, .loops = true },
            .word_bytes => .{ .memory = true, .byte_views = true, .correspondence = false },
            .word_byte_loops => .{ .memory = true, .byte_views = true, .loops = true, .correspondence = false },
            .calls => .{ .memory = true, .calls = true },
            .call_loops => .{ .memory = true, .calls = true, .loops = true },
            .nested_calls => .{ .memory = true, .calls = true, .loops = true, .looping_callees = true },
            .recursive_calls => .{ .memory = true, .calls = true, .loops = true, .looping_callees = true, .recursive_calls = true },
        };
    }
    pub fn module(self: Profile) []const u8 {
        return switch (self) {
            .scalar => "Scalar",
            .aggregate => "AggregateAir",
            .loops, .word_byte_loops => "MemoryExecution",
            .calls, .call_loops, .nested_calls, .recursive_calls => "MemoryCallMachine",
            else => "MemoryAir",
        };
    }
    pub fn vocabulary(self: Profile) []const u8 {
        return switch (self) {
            .loops, .word_byte_loops => "MemoryAir",
            else => self.module(),
        };
    }
};
pub const Ty = union(enum) {
    int: struct { signed: bool, bits: u16 },
    boolean,
    unit,
    noreturn,
    pointer: struct { mutable: bool, many: bool, child: *const Ty },
    slice: struct { mutable: bool, child: *const Ty },
    array: struct { len: u64, child: *const Ty },
    aligned: struct { alignment: u64, child: *const Ty },
    // Opaque storage for inactive enum fields. Runtime enum values and their
    // loads, stores and conversions remain outside this vocabulary.
    enumeration: struct { declaration: Value, name: []const u8, size: u64, alignment: u64 },
    structure: struct { name: []const u8, source: []const u8, sha: []const u8, size: u64, alignment: u64, fields: []const Field },
    pub const Field = struct { name: []const u8, offset: u64, ty: *const Ty };
    pub fn same(a: *const Ty, b: *const Ty) bool {
        if (std.meta.activeTag(a.*) != std.meta.activeTag(b.*)) return false;
        return switch (a.*) {
            .int => |v| v.signed == b.int.signed and v.bits == b.int.bits,
            .boolean, .unit, .noreturn => true,
            .pointer => |v| v.mutable == b.pointer.mutable and v.many == b.pointer.many and same(v.child, b.pointer.child),
            .slice => |v| v.mutable == b.slice.mutable and same(v.child, b.slice.child),
            .array => |v| v.len == b.array.len and same(v.child, b.array.child),
            .aligned => |v| v.alignment == b.aligned.alignment and same(v.child, b.aligned.child),
            .enumeration => |v| c.equal(v.declaration, b.enumeration.declaration),
            .structure => |v| blk: {
                const w = b.structure;
                if (!std.mem.eql(u8, v.name, w.name) or !std.mem.eql(u8, v.source, w.source) or !std.mem.eql(u8, v.sha, w.sha) or v.size != w.size or v.alignment != w.alignment or v.fields.len != w.fields.len) break :blk false;
                for (v.fields, w.fields) |x, y| if (!std.mem.eql(u8, x.name, y.name) or x.offset != y.offset or !same(x.ty, y.ty)) break :blk false;
                break :blk true;
            },
        };
    }
    pub fn isInt(self: *const Ty, signed: bool, bits: u16) bool {
        return self.* == .int and self.int.signed == signed and self.int.bits == bits;
    }
    pub fn raw(self: *const Ty) *const Ty {
        return if (self.* == .aligned) self.aligned.child else self;
    }
    pub fn hasAlignment(self: *const Ty) bool {
        return switch (self.*) {
            .aligned => true,
            .pointer => |p| p.child.hasAlignment(),
            .slice => |p| p.child.hasAlignment(),
            .array => |p| p.child.hasAlignment(),
            else => false,
        };
    }
    pub fn layout(self: *const Ty, ctx: *Context) Error![2]u64 {
        return switch (self.*) {
            .unit => .{ 0, 1 },
            .boolean => .{ 1, 1 },
            .int => |v| if (c.oneOf(try ctx.fmt("{d}", .{v.bits}), &.{ "8", "16", "32", "64" })) .{ v.bits / 8, v.bits / 8 } else if (!v.signed and v.bits == 256) .{ 32, 16 } else ctx.fail("unsupported memory layout", .{}),
            .pointer => .{ target.pointer_bytes, target.pointer_alignment },
            .slice => .{ 2 * target.pointer_bytes, target.pointer_alignment },
            .aligned => |v| v.child.layout(ctx),
            .array => |v| blk: {
                const child = try v.child.layout(ctx);
                break :blk .{ std.math.mul(u64, child[0], v.len) catch return ctx.fail("invalid or unsupported memory extent", .{}), child[1] };
            },
            .structure => |v| .{ v.size, v.alignment },
            .enumeration => |v| .{ v.size, v.alignment },
            else => ctx.fail("unsupported memory layout", .{}),
        };
    }
    pub fn alignment(self: *const Ty, ctx: *Context) Error!u64 {
        if (self.* == .aligned) return self.aligned.alignment;
        return switch (self.*) {
            .pointer => |v| (try v.child.layout(ctx))[1],
            .slice => |v| (try v.child.layout(ctx))[1],
            else => ctx.fail("byte value has no pointee alignment", .{}),
        };
    }
    pub fn lean(self: *const Ty, ctx: *Context, profile: Profile) Error![]const u8 {
        return switch (self.*) {
            .int => |v| if (profile == .scalar) ctx.fmt("(.int {s} {d})", .{ c.boolText(v.signed), v.bits }) else ctx.fmt("(.scalar (.int {s} {d}))", .{ c.boolText(v.signed), v.bits }),
            .boolean => if (profile == .scalar) ".bool" else "(.scalar .bool)",
            .unit => if (profile == .scalar) ".unit" else "(.scalar .unit)",
            .noreturn => ctx.fail("noreturn cannot be a runtime value type", .{}),
            .pointer => |v| ctx.fmt("(.pointer {s} {s} {s})", .{ c.boolText(v.mutable), c.boolText(v.many), try v.child.lean(ctx, .memory) }),
            .slice => |v| ctx.fmt("(.slice {s} {s})", .{ c.boolText(v.mutable), try v.child.lean(ctx, .memory) }),
            .array => |v| ctx.fmt("(.array {d} {s})", .{ v.len, try v.child.lean(ctx, .memory) }),
            .aligned => |v| v.child.lean(ctx, profile),
            .enumeration => |v| ctx.fmt("(.record {s} ⟨{d}, {d}⟩)", .{ try ctx.json(try ctx.fmt("enum:{s}", .{v.name})), v.size, v.alignment }),
            .structure => |v| blk: {
                const ordered = try ctx.allocator.dupe(Field, v.fields);
                std.mem.sort(Field, ordered, {}, struct {
                    fn less(_: void, a: Field, b: Field) bool {
                        return a.offset < b.offset;
                    }
                }.less);
                var pieces: std.ArrayList([]const u8) = .empty;
                for (ordered) |field| {
                    const child = try field.ty.lean(ctx, .memory);
                    const term = if (field.ty.* == .int or field.ty.* == .unit or field.ty.* == .boolean) child else try ctx.fmt("(.object {s})", .{child});
                    try pieces.append(ctx.allocator, try ctx.fmt("({d}, {s})", .{ field.offset, term }));
                }
                break :blk ctx.fmt("(.aggregate {s} ⟨{d}, {d}⟩ [{s}])", .{ try ctx.json(v.name), v.size, v.alignment, try std.mem.join(ctx.allocator, ", ", pieces.items) });
            },
        };
    }
};

pub fn parse(ctx: *Context, value: Value, profile: Profile, depth: usize) Error!*const Ty {
    if (depth > 16 or value != .object) return ctx.fail("type depth or shape", .{});
    if (c.tag(value, "kind", "int")) {
        try ctx.fields(value, "kind bits signedness");
        const signedness = try ctx.str(try ctx.field(value, "signedness"));
        try ctx.require(c.oneOf(signedness, &.{ "signed", "unsigned" }), "unknown integer signedness");
        return ctx.make(Ty, .{ .int = .{ .signed = std.mem.eql(u8, signedness, "signed"), .bits = @intCast(try ctx.nat(try ctx.field(value, "bits"), 512)) } });
    }
    if (profile != .scalar and c.tag(value, "kind", "pointer")) {
        try ctx.fields(value, "kind flags child layout pointeeLayout sentinel");
        const flags = try ctx.field(value, "flags");
        try ctx.fields(flags, "size alignment isConst isVolatile allowZero addressSpace vectorIndex hostSizeBytes bitOffset");
        const size = try ctx.str(try ctx.field(flags, "size"));
        const constant = try ctx.field(flags, "isConst");
        try ctx.require(c.oneOf(size, &.{ "one", "many", "slice" }) and constant == .bool and c.flag(flags, "isVolatile", false) and c.flag(flags, "allowZero", false) and c.tag(flags, "addressSpace", "generic") and c.none(flags, "vectorIndex") and c.none(value, "sentinel"), "unsupported memory pointer attributes");
        try ctx.require(try ctx.nat(try ctx.field(flags, "hostSizeBytes"), std.math.maxInt(u64)) == 0 and try ctx.nat(try ctx.field(flags, "bitOffset"), std.math.maxInt(u64)) == 0, "unsupported memory pointer attributes");
        const child = try parse(ctx, try ctx.field(value, "child"), profile, depth + 1);
        var result = try ctx.make(Ty, if (std.mem.eql(u8, size, "slice")) .{ .slice = .{ .mutable = !constant.bool, .child = child } } else .{ .pointer = .{ .mutable = !constant.bool, .many = std.mem.eql(u8, size, "many"), .child = child } });
        try checkLayout(ctx, try ctx.field(value, "layout"), try result.layout(ctx));
        try checkLayout(ctx, try ctx.field(value, "pointeeLayout"), try child.layout(ctx));
        const alignment = try ctx.field(flags, "alignment");
        if (alignment != .null) {
            const amount = try ctx.nat(alignment, 4);
            try ctx.require(profile.hasBytes() and (amount == 1 or amount == 2 or amount == 4) and child.isInt(false, 8), "unsupported explicit byte alignment");
            result = try ctx.make(Ty, .{ .aligned = .{ .alignment = amount, .child = result } });
        }
        return result;
    }
    if (profile != .scalar and c.tag(value, "kind", "array")) {
        try ctx.fields(value, "kind length child layout sentinel");
        try ctx.require(c.none(value, "sentinel"), "unsupported memory array sentinel");
        const result = try ctx.make(Ty, .{ .array = .{ .len = try ctx.nat(try ctx.field(value, "length"), std.math.maxInt(u64)), .child = try parse(ctx, try ctx.field(value, "child"), profile, depth + 1) } });
        try checkLayout(ctx, try ctx.field(value, "layout"), try result.layout(ctx));
        return result;
    }
    if (profile != .scalar and depth > 0 and c.tag(value, "kind", "enum")) {
        try ctx.fields(value, "kind identity backingType layout nonexhaustive fields");
        const identity = try ctx.field(value, "identity");
        try ctx.fields(identity, "name sourceFile sourceSha256");
        const name = try ctx.str(try ctx.field(identity, "name"));
        try ctx.require(name.len > 0 and (try ctx.str(try ctx.field(identity, "sourceFile"))).len > 0 and c.isDigest(try ctx.str(try ctx.field(identity, "sourceSha256"))), "unsupported enum identity");
        const backing = try parse(ctx, try ctx.field(value, "backingType"), .scalar, depth + 1);
        try ctx.require(backing.* == .int and !backing.int.signed and backing.int.bits > 0 and backing.int.bits <= 64 and c.flag(value, "nonexhaustive", false), "unsupported opaque enum backing type");
        const bits = backing.int.bits;
        const size: u64 = if (bits <= 8) 1 else if (bits <= 16) 2 else if (bits <= 32) 4 else 8;
        try checkLayout(ctx, try ctx.field(value, "layout"), .{ size, size });
        const fields = try ctx.array(try ctx.field(value, "fields"));
        try ctx.require(fields.len > 0 and fields.len <= 256, "unsupported enum tag count");
        for (fields, 0..) |field, index| {
            try ctx.fields(field, "index name value");
            const tag_name = try ctx.str(try ctx.field(field, "name"));
            const tag_value = try ctx.nat(try ctx.field(field, "value"), std.math.maxInt(u64));
            try ctx.require(try ctx.nat(try ctx.field(field, "index"), 255) == index and tag_name.len > 0 and tag_value < (@as(u128, 1) << @intCast(bits)), "invalid enum tag");
            for (fields[0..index]) |previous| try ctx.require(!c.equal(try ctx.field(previous, "name"), try ctx.field(field, "name")) and !c.equal(try ctx.field(previous, "value"), try ctx.field(field, "value")), "duplicate enum tag");
        }
        return ctx.make(Ty, .{ .enumeration = .{ .declaration = value, .name = name, .size = size, .alignment = size } });
    }
    // Memory registers carry scalar values, pointers and slices. Complete record
    // layouts are also needed behind those pointers, without admitting records
    // as evaluated values outside the aggregate vocabulary.
    if ((profile == .aggregate or (profile != .scalar and depth > 0)) and c.tag(value, "kind", "struct")) {
        try ctx.fields(value, "kind identity containerLayout layout fields");
        const identity = try ctx.field(value, "identity");
        try ctx.fields(identity, "name sourceFile sourceSha256");
        const name = try ctx.str(try ctx.field(identity, "name"));
        const source = try ctx.str(try ctx.field(identity, "sourceFile"));
        const sha = try ctx.str(try ctx.field(identity, "sourceSha256"));
        try ctx.require(name.len > 0 and source.len > 0 and c.isDigest(sha) and c.oneOf(try ctx.str(try ctx.field(value, "containerLayout")), &.{ "auto", "extern" }), "unsupported aggregate identity or layout");
        const layout = try ctx.field(value, "layout");
        try ctx.fields(layout, "kind bytes alignment");
        const size = try ctx.nat(try ctx.field(layout, "bytes"), std.math.maxInt(u64));
        const alignment = try ctx.nat(try ctx.field(layout, "alignment"), std.math.maxInt(u64));
        try ctx.require(c.tag(layout, "kind", "abi") and size > 0 and alignment > 0 and std.math.isPowerOfTwo(alignment) and size % alignment == 0, "unsupported aggregate geometry");
        const raw_fields = try ctx.array(try ctx.field(value, "fields"));
        try ctx.require(raw_fields.len > 0 and raw_fields.len <= 64, "aggregate field count");
        const result = try ctx.allocator.alloc(Ty.Field, raw_fields.len);
        for (raw_fields, 0..) |field, index| {
            try ctx.fields(field, "index name offset explicitAlignment type");
            const field_name = try ctx.str(try ctx.field(field, "name"));
            try ctx.require(try ctx.nat(try ctx.field(field, "index"), 63) == index and c.none(field, "explicitAlignment") and field_name.len > 0, "unsupported aggregate field declaration");
            const offset = try ctx.nat(try ctx.field(field, "offset"), std.math.maxInt(u64));
            const child = try parse(ctx, try ctx.field(field, "type"), profile, depth + 1);
            const child_layout = try child.layout(ctx);
            try ctx.require(child_layout[0] > 0 and offset <= size and child_layout[0] <= size - offset and offset % child_layout[1] == 0 and alignment % child_layout[1] == 0, "invalid aggregate field geometry");
            for (result[0..index]) |previous| {
                const previous_size = (try previous.ty.layout(ctx))[0];
                try ctx.require(!std.mem.eql(u8, field_name, previous.name) and (offset + child_layout[0] <= previous.offset or previous.offset + previous_size <= offset), "overlapping or duplicate aggregate fields");
            }
            result[index] = .{ .name = field_name, .offset = offset, .ty = child };
        }
        return ctx.make(Ty, .{ .structure = .{ .name = name, .source = source, .sha = sha, .size = size, .alignment = alignment, .fields = result } });
    }
    try ctx.fields(value, "kind");
    const kind = try ctx.str(try ctx.field(value, "kind"));
    if (std.mem.eql(u8, kind, "bool")) return ctx.make(Ty, .boolean);
    if (std.mem.eql(u8, kind, "void")) return ctx.make(Ty, .unit);
    if (std.mem.eql(u8, kind, "noreturn")) return ctx.make(Ty, .noreturn);
    return ctx.fail("unsupported AIR type", .{});
}
pub fn checkLayout(ctx: *Context, value: Value, wanted: [2]u64) Error!void {
    try ctx.fields(value, "kind bytes alignment");
    try ctx.require(c.tag(value, "kind", "abi") and try ctx.nat(try ctx.field(value, "bytes"), std.math.maxInt(u64)) == wanted[0] and try ctx.nat(try ctx.field(value, "alignment"), std.math.maxInt(u64)) == wanted[1], "captured ABI layout disagrees with memory model");
}
