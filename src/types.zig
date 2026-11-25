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
    error_value: ErrorValue,
    optional_byte,
    pointer: struct { mutable: bool, many: bool, child: *const Ty },
    slice: struct { mutable: bool, child: *const Ty },
    array: struct { len: u64, child: *const Ty },
    aligned: struct { alignment: u64, child: *const Ty },
    enumeration: Enumeration,
    structure: struct { name: []const u8, source: []const u8, sha: []const u8, size: u64, alignment: u64, fields: []const Field },

    pub const Enumeration = struct {
        declaration: Value,
        name: []const u8,
        source: []const u8,
        sha: []const u8,
        bits: u16,
        size: u64,
        alignment: u64,
        // Only finite runtime declarations carry evaluated tags. Other enum
        // fields remain opaque nominal storage.
        tags: []const Tag,

        const Tag = struct { name: []const u8, value: u8 };

        pub fn hasTag(self: Enumeration, value: u8) bool {
            for (self.tags) |tag| if (tag.value == value) return true;
            return false;
        }

        pub fn leanDeclaration(self: Enumeration, ctx: *Context) Error![]const u8 {
            const tags = try ctx.allocator.alloc([]const u8, self.tags.len);
            for (self.tags, tags) |tag, *encoded| {
                encoded.* = try ctx.fmt("({s}, {d})", .{ try ctx.json(tag.name), tag.value });
            }
            return ctx.fmt("⟨{s}, {s}, {s}, {d}, [{s}]⟩", .{
                try ctx.json(self.name),                     try ctx.json(self.source), try ctx.json(self.sha), self.bits,
                try std.mem.join(ctx.allocator, ", ", tags),
            });
        }
    };
    pub const ErrorValue = struct {
        result: bool,
        names: []const []const u8,
        payload: ?*const Ty = null,

        pub fn contains(self: ErrorValue, name: []const u8) bool {
            return c.oneOf(name, self.names);
        }

        pub fn includes(self: ErrorValue, other: ErrorValue) bool {
            for (other.names) |name| if (!self.contains(name)) return false;
            return true;
        }

        pub fn leanKind(self: ErrorValue) []const u8 {
            return if (self.result) "result" else "tag";
        }

        fn same(self: ErrorValue, other: ErrorValue) bool {
            if (self.result != other.result or self.names.len != other.names.len) return false;
            if (self.payload) |child| {
                if (!Ty.same(child, other.payload orelse return false)) return false;
            } else if (other.payload != null) return false;
            for (self.names, other.names) |left, right| if (!std.mem.eql(u8, left, right)) return false;
            return true;
        }
    };
    pub const Field = struct {
        name: []const u8,
        offset: u64,
        ty: union(enum) { stored: *const Ty, zero_storage: Value },

        fn same(left: Field, right: Field) bool {
            if (!std.mem.eql(u8, left.name, right.name) or left.offset != right.offset) return false;
            return switch (left.ty) {
                .stored => |ty| right.ty == .stored and Ty.same(ty, right.ty.stored),
                .zero_storage => |declaration| right.ty == .zero_storage and c.equal(declaration, right.ty.zero_storage),
            };
        }
    };
    pub fn same(a: *const Ty, b: *const Ty) bool {
        if (std.meta.activeTag(a.*) != std.meta.activeTag(b.*)) return false;
        return switch (a.*) {
            .int => |v| v.signed == b.int.signed and v.bits == b.int.bits,
            .boolean, .unit, .noreturn, .optional_byte => true,
            .error_value => |v| v.same(b.error_value),
            .pointer => |v| v.mutable == b.pointer.mutable and v.many == b.pointer.many and same(v.child, b.pointer.child),
            .slice => |v| v.mutable == b.slice.mutable and same(v.child, b.slice.child),
            .array => |v| v.len == b.array.len and same(v.child, b.array.child),
            .aligned => |v| v.alignment == b.aligned.alignment and same(v.child, b.aligned.child),
            .enumeration => |v| c.equal(v.declaration, b.enumeration.declaration),
            .structure => |v| blk: {
                const w = b.structure;
                if (!std.mem.eql(u8, v.name, w.name) or !std.mem.eql(u8, v.source, w.source) or !std.mem.eql(u8, v.sha, w.sha) or v.size != w.size or v.alignment != w.alignment or v.fields.len != w.fields.len) break :blk false;
                for (v.fields, w.fields) |x, y| if (!x.same(y)) break :blk false;
                break :blk true;
            },
        };
    }
    pub fn isInt(self: *const Ty, signed: bool, bits: u16) bool {
        return self.* == .int and self.int.signed == signed and self.int.bits == bits;
    }
    pub fn isRuntimeEnum(self: *const Ty) bool {
        return self.* == .enumeration and self.enumeration.tags.len != 0;
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
            .optional_byte => .{ 2, 1 },
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
            .error_value => |v| if (v.payload) |child|
                ctx.fmt("(.errorScalar {s} {s})", .{ try child.lean(ctx, .scalar), try ctx.json(v.names) })
            else
                ctx.fmt("(.errorValue .{s} {s})", .{ v.leanKind(), try ctx.json(v.names) }),
            .optional_byte => "(.optionalScalar (.int false 8))",
            .pointer => |v| ctx.fmt("(.pointer {s} {s} {s})", .{ c.boolText(v.mutable), c.boolText(v.many), try v.child.lean(ctx, .memory) }),
            .slice => |v| ctx.fmt("(.slice {s} {s})", .{ c.boolText(v.mutable), try v.child.lean(ctx, .memory) }),
            .array => |v| ctx.fmt("(.array {d} {s})", .{ v.len, try v.child.lean(ctx, .memory) }),
            .aligned => |v| v.child.lean(ctx, profile),
            .enumeration => |v| if (self.isRuntimeEnum()) blk: {
                const scalar = try ctx.fmt("(.enumeration {s})", .{try v.leanDeclaration(ctx)});
                break :blk if (profile == .scalar) scalar else ctx.fmt("(.scalar {s})", .{scalar});
            } else ctx.fmt("(.record {s} ⟨{d}, {d}⟩)", .{ try ctx.json(try ctx.fmt("enum:{s}", .{v.name})), v.size, v.alignment }),
            .structure => |v| blk: {
                const ordered = try ctx.allocator.dupe(Field, v.fields);
                std.mem.sort(Field, ordered, {}, struct {
                    fn less(_: void, a: Field, b: Field) bool {
                        return a.offset < b.offset;
                    }
                }.less);
                var pieces: std.ArrayList([]const u8) = .empty;
                for (ordered) |field| {
                    if (field.ty != .stored) continue;
                    const ty = field.ty.stored;
                    const child = try ty.lean(ctx, .memory);
                    const term = if (ty.* == .int or ty.* == .unit or ty.* == .boolean or ty.isRuntimeEnum())
                        child
                    else
                        try ctx.fmt("(.object {s})", .{child});
                    try pieces.append(ctx.allocator, try ctx.fmt("({d}, {s})", .{ field.offset, term }));
                }
                break :blk ctx.fmt("(.aggregate {s} ⟨{d}, {d}⟩ [{s}])", .{ try ctx.json(v.name), v.size, v.alignment, try std.mem.join(ctx.allocator, ", ", pieces.items) });
            },
        };
    }
};

// Prove the recorded field has no storage before excluding it from the heap
// layout. A zero extent alone is insufficient evidence.
fn checkZeroStorage(ctx: *Context, raw: Value, depth: usize) Error!void {
    try ctx.require(depth <= 16, "zero-storage type depth limit");
    try checkLayout(ctx, try ctx.field(raw, "layout"), .{ 0, 1 });
    const identity = try ctx.field(raw, "identity");
    try ctx.fields(identity, "name sourceFile sourceSha256");
    try ctx.require((try ctx.str(try ctx.field(identity, "name"))).len > 0 and
        (try ctx.str(try ctx.field(identity, "sourceFile"))).len > 0 and
        c.isDigest(try ctx.str(try ctx.field(identity, "sourceSha256"))), "invalid zero-storage identity");
    const fields = try ctx.array(try ctx.field(raw, "fields"));
    if (c.tag(raw, "kind", "enum")) {
        try ctx.fields(raw, "kind identity backingType layout nonexhaustive fields");
        const backing = try parse(ctx, try ctx.field(raw, "backingType"), .scalar, depth + 1);
        try ctx.require(backing.isInt(false, 0) and c.flag(raw, "nonexhaustive", false) and fields.len == 1, "zero-storage enum must have a single u0 tag");
        const field = fields[0];
        try ctx.fields(field, "index name value");
        try ctx.require(try ctx.nat(try ctx.field(field, "index"), 0) == 0 and
            try ctx.nat(try ctx.field(field, "value"), 0) == 0 and
            (try ctx.str(try ctx.field(field, "name"))).len > 0, "invalid zero-storage enum tag");
        return;
    }
    try ctx.fields(raw, "kind identity containerLayout layout fields");
    try ctx.require(c.tag(raw, "kind", "struct") and c.tag(raw, "containerLayout", "auto") and
        fields.len > 0 and fields.len <= 64, "unsupported zero-storage declaration");
    for (fields, 0..) |field, index| {
        try ctx.fields(field, "index name offset explicitAlignment type");
        const name = try ctx.field(field, "name");
        try ctx.require(try ctx.nat(try ctx.field(field, "index"), 63) == index and
            try ctx.nat(try ctx.field(field, "offset"), 0) == 0 and
            c.none(field, "explicitAlignment") and (try ctx.str(name)).len > 0, "invalid zero-storage field");
        for (fields[0..index]) |previous| try ctx.require(!c.equal(try ctx.field(previous, "name"), name), "duplicate zero-storage field");
        try checkZeroStorage(ctx, try ctx.field(field, "type"), depth + 1);
    }
}

/// Only direct-call admission can erase a by-value singleton parameter.
/// The full declaration is retained for checking the original argument.
pub fn isSingletonParameter(ctx: *Context, raw: Value) Error!bool {
    if (!c.tag(raw, "kind", "enum") and !c.tag(raw, "kind", "struct")) return false;
    const layout = c.get(raw, "layout") orelse return false;
    const bytes = c.get(layout, "bytes") orelse return false;
    if (try ctx.nat(bytes, std.math.maxInt(u64)) != 0) return false;
    try checkZeroStorage(ctx, raw, 0);
    return true;
}

/// The argument must be a defined value of exactly the admitted declaration.
/// A singleton can contain other singleton fields, in declaration order.
pub fn checkSingletonValue(ctx: *Context, value: Value, declaration: Value) Error!void {
    try ctx.require(c.equal(try ctx.field(value, "type"), declaration), "singleton argument declaration mismatch");
    if (c.tag(declaration, "kind", "enum")) {
        try ctx.fields(value, "kind value type");
        try ctx.require(c.tag(value, "kind", "enumTag") and try ctx.nat(try ctx.field(value, "value"), 0) == 0, "singleton enum value is not its sole tag");
        return;
    }
    try ctx.fields(value, "kind type fields");
    try ctx.require(c.tag(value, "kind", "aggregate"), "singleton struct must be a defined aggregate");
    const members = try ctx.array(try ctx.field(value, "fields"));
    const fields = try ctx.array(try ctx.field(declaration, "fields"));
    try ctx.require(members.len == fields.len, "singleton aggregate value has the wrong field count");
    for (members, fields) |member, field| try checkSingletonValue(ctx, member, try ctx.field(field, "type"));
}

fn parsePointer(ctx: *Context, value: Value, profile: Profile, child: *const Ty) Error!*const Ty {
    try ctx.fields(value, "kind flags child layout pointeeLayout sentinel");
    const flags = try ctx.field(value, "flags");
    try ctx.fields(flags, "size alignment isConst isVolatile allowZero addressSpace vectorIndex hostSizeBytes bitOffset");
    const size = try ctx.str(try ctx.field(flags, "size"));
    const constant = try ctx.field(flags, "isConst");
    try ctx.require(c.oneOf(size, &.{ "one", "many", "slice" }) and constant == .bool and c.flag(flags, "isVolatile", false) and c.flag(flags, "allowZero", false) and c.tag(flags, "addressSpace", "generic") and c.none(flags, "vectorIndex") and c.none(value, "sentinel"), "unsupported memory pointer attributes");
    try ctx.require(try ctx.nat(try ctx.field(flags, "hostSizeBytes"), std.math.maxInt(u64)) == 0 and try ctx.nat(try ctx.field(flags, "bitOffset"), std.math.maxInt(u64)) == 0, "unsupported memory pointer attributes");
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

/// Validate a singleton field result using its complete raw declaration and the
/// ABI geometry shared with other pointer types. This only checks the result
/// type of the projection, which does not produce a modeled reference.
pub fn checkSingletonPointer(ctx: *Context, value: Value, declaration: Value, writable: bool) Error!void {
    try ctx.require(c.tag(value, "kind", "pointer") and c.equal(try ctx.field(value, "child"), declaration), "zero-storage field pointer changed declaration");
    const pointer = try parsePointer(ctx, value, .memory, &.unit);
    try ctx.require(pointer.* == .pointer and !pointer.pointer.many and pointer.pointer.mutable == writable, "zero-storage field pointer changed kind or permissions");
}

fn errorNames(ctx: *Context, value: Value) Error![]const []const u8 {
    try ctx.fields(value, "kind names");
    try ctx.require(c.tag(value, "kind", "errorSet"), "expected a concrete error set");
    const raw = try ctx.array(try ctx.field(value, "names"));
    try ctx.require(raw.len <= 64, "error set exceeds the admitted size");
    const names = try ctx.allocator.alloc([]const u8, raw.len);
    for (raw, names, 0..) |item, *name, index| {
        name.* = try ctx.str(item);
        try ctx.require(name.len > 0 and name.len <= 128 and std.unicode.utf8ValidateSlice(name.*) and
            !c.oneOf(name.*, names[0..index]), "invalid or duplicate error name");
        for (name.*) |byte| try ctx.require(!std.ascii.isControl(byte), "unsupported error name control character");
    }
    return names;
}

fn parseEnum(ctx: *Context, value: Value, runtime: bool, depth: usize) Error!*const Ty {
    try ctx.fields(value, "kind identity backingType layout nonexhaustive fields");
    const identity = try ctx.field(value, "identity");
    try ctx.fields(identity, "name sourceFile sourceSha256");
    const name = try ctx.str(try ctx.field(identity, "name"));
    const source = try ctx.str(try ctx.field(identity, "sourceFile"));
    const sha = try ctx.str(try ctx.field(identity, "sourceSha256"));
    try ctx.require(name.len > 0 and source.len > 0 and c.isDigest(sha), "unsupported enum identity");
    if (runtime) {
        try checkEnumText(ctx, name);
        try checkEnumText(ctx, source);
    }
    const backing = try parse(ctx, try ctx.field(value, "backingType"), .scalar, depth + 1);
    try ctx.require(backing.* == .int and !backing.int.signed and backing.int.bits > 0 and backing.int.bits <= 64 and
        c.flag(value, "nonexhaustive", false), "unsupported enum backing type");
    const bits = backing.int.bits;
    if (runtime) try ctx.require(bits >= 2 and bits <= 8, "runtime enum requires a byte-sized backing type");
    const size: u64 = if (bits <= 8) 1 else if (bits <= 16) 2 else if (bits <= 32) 4 else 8;
    try checkLayout(ctx, try ctx.field(value, "layout"), .{ size, size });
    const fields = try ctx.array(try ctx.field(value, "fields"));
    const limit: usize = if (runtime) 64 else 256;
    try ctx.require(fields.len > 0 and fields.len <= limit, "unsupported enum tag count");
    const tags = try ctx.allocator.alloc(Ty.Enumeration.Tag, if (runtime) fields.len else 0);
    for (fields, 0..) |field, index| {
        try ctx.fields(field, "index name value");
        const tag_name = try ctx.str(try ctx.field(field, "name"));
        const tag_value = try ctx.nat(try ctx.field(field, "value"), std.math.maxInt(u64));
        try ctx.require(try ctx.nat(try ctx.field(field, "index"), 255) == index and tag_name.len > 0 and
            tag_value < (@as(u128, 1) << @intCast(bits)), "invalid enum tag");
        for (fields[0..index]) |previous| try ctx.require(!c.equal(try ctx.field(previous, "name"), try ctx.field(field, "name")) and
            !c.equal(try ctx.field(previous, "value"), try ctx.field(field, "value")), "duplicate enum tag");
        if (runtime) {
            try checkEnumText(ctx, tag_name);
            tags[index] = .{ .name = tag_name, .value = @intCast(tag_value) };
        }
    }
    return ctx.make(Ty, .{ .enumeration = .{
        .declaration = value,
        .name = name,
        .source = source,
        .sha = sha,
        .bits = bits,
        .size = size,
        .alignment = size,
        .tags = tags,
    } });
}

fn checkEnumText(ctx: *Context, value: []const u8) Error!void {
    try ctx.require(value.len <= 1024 and std.unicode.utf8ValidateSlice(value), "unsupported enum declaration text");
    for (value) |byte| try ctx.require(!std.ascii.isControl(byte), "unsupported enum declaration control character");
}

pub fn parse(ctx: *Context, value: Value, profile: Profile, depth: usize) Error!*const Ty {
    if (depth > 16 or value != .object) return ctx.fail("type depth or shape", .{});
    if (c.tag(value, "kind", "int")) {
        try ctx.fields(value, "kind bits signedness");
        const signedness = try ctx.str(try ctx.field(value, "signedness"));
        try ctx.require(c.oneOf(signedness, &.{ "signed", "unsigned" }), "unknown integer signedness");
        return ctx.make(Ty, .{ .int = .{ .signed = std.mem.eql(u8, signedness, "signed"), .bits = @intCast(try ctx.nat(try ctx.field(value, "bits"), 512)) } });
    }
    if (profile == .memory or profile == .loops or profile.hasCalls()) {
        if (c.tag(value, "kind", "optionalScalar")) {
            try ctx.fields(value, "kind child layout");
            const child = try parse(ctx, try ctx.field(value, "child"), profile, depth + 1);
            try ctx.require(child.isInt(false, 8), "only byte optional payloads are admitted");
            const ty: Ty = .optional_byte;
            try checkLayout(ctx, try ctx.field(value, "layout"), try ty.layout(ctx));
            return ctx.make(Ty, ty);
        }
        if (c.tag(value, "kind", "errorSet"))
            return ctx.make(Ty, .{ .error_value = .{ .result = false, .names = try errorNames(ctx, value) } });
        if (c.tag(value, "kind", "errorStatus")) {
            try ctx.fields(value, "kind errors");
            return ctx.make(Ty, .{ .error_value = .{ .result = true, .names = try errorNames(ctx, try ctx.field(value, "errors")) } });
        }
        if (c.tag(value, "kind", "errorScalar")) {
            try ctx.fields(value, "kind errors child");
            const child = try parse(ctx, try ctx.field(value, "child"), .scalar, depth + 1);
            try ctx.require(child.* == .int and child.int.bits > 0 and child.int.bits <= 64, "unsupported error union payload");
            return ctx.make(Ty, .{ .error_value = .{
                .result = true,
                .names = try errorNames(ctx, try ctx.field(value, "errors")),
                .payload = child,
            } });
        }
    }
    if (profile != .scalar and c.tag(value, "kind", "pointer")) {
        const child = try parse(ctx, try ctx.field(value, "child"), profile, depth + 1);
        return parsePointer(ctx, value, profile, child);
    }
    if (profile != .scalar and c.tag(value, "kind", "array")) {
        try ctx.fields(value, "kind length child layout sentinel");
        try ctx.require(c.none(value, "sentinel"), "unsupported memory array sentinel");
        const result = try ctx.make(Ty, .{ .array = .{ .len = try ctx.nat(try ctx.field(value, "length"), std.math.maxInt(u64)), .child = try parse(ctx, try ctx.field(value, "child"), profile, depth + 1) } });
        try checkLayout(ctx, try ctx.field(value, "layout"), try result.layout(ctx));
        return result;
    }
    if (c.tag(value, "kind", "finiteEnum")) return parseEnum(ctx, value, true, depth);
    if (profile != .scalar and depth > 0 and c.tag(value, "kind", "enum")) return parseEnum(ctx, value, false, depth);
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
        var has_storage = false;
        for (raw_fields, 0..) |field, index| {
            try ctx.fields(field, "index name offset explicitAlignment type");
            const field_name = try ctx.str(try ctx.field(field, "name"));
            try ctx.require(try ctx.nat(try ctx.field(field, "index"), 63) == index and c.none(field, "explicitAlignment") and field_name.len > 0, "unsupported aggregate field declaration");
            const offset = try ctx.nat(try ctx.field(field, "offset"), std.math.maxInt(u64));
            try ctx.require(offset <= size, "aggregate field lies outside its owner");
            for (result[0..index]) |previous| try ctx.require(!std.mem.eql(u8, field_name, previous.name), "duplicate aggregate field");
            const raw_child = try ctx.field(field, "type");
            if (c.get(c.get(raw_child, "layout") orelse .null, "bytes")) |bytes| {
                if (try ctx.nat(bytes, std.math.maxInt(u64)) == 0) {
                    try checkZeroStorage(ctx, raw_child, depth + 1);
                    result[index] = .{ .name = field_name, .offset = offset, .ty = .{ .zero_storage = raw_child } };
                    continue;
                }
            }
            const child = try parse(ctx, raw_child, profile, depth + 1);
            const child_layout = try child.layout(ctx);
            try ctx.require(child_layout[0] > 0 and child_layout[0] <= size - offset and offset % child_layout[1] == 0 and alignment % child_layout[1] == 0, "invalid aggregate field geometry");
            for (result[0..index]) |previous| {
                if (previous.ty != .stored) continue;
                const previous_size = (try previous.ty.stored.layout(ctx))[0];
                try ctx.require(offset + child_layout[0] <= previous.offset or previous.offset + previous_size <= offset, "overlapping aggregate fields");
            }
            result[index] = .{ .name = field_name, .offset = offset, .ty = .{ .stored = child } };
            has_storage = true;
        }
        try ctx.require(has_storage, "aggregate has no stored field");
        return ctx.make(Ty, .{ .structure = .{ .name = name, .source = source, .sha = sha, .size = size, .alignment = alignment, .fields = result } });
    }
    const kind = try ctx.str(try ctx.field(value, "kind"));
    if (std.mem.eql(u8, kind, "unsupported")) {
        if (c.get(value, "reason")) |reason| {
            try ctx.fields(value, "kind reason");
            return ctx.fail("unsupported Zig AIR type ({s})", .{try ctx.str(reason)});
        }
        try ctx.fields(value, "kind zigTypeTag");
        const tag = try ctx.str(try ctx.field(value, "zigTypeTag"));
        return ctx.fail("unsupported Zig AIR type '{s}'", .{tag});
    }
    try ctx.fields(value, "kind");
    if (std.mem.eql(u8, kind, "bool")) return ctx.make(Ty, .boolean);
    if (std.mem.eql(u8, kind, "void")) return ctx.make(Ty, .unit);
    if (std.mem.eql(u8, kind, "noreturn")) return ctx.make(Ty, .noreturn);
    return ctx.fail("unsupported AIR type kind '{s}'", .{kind});
}
pub fn checkLayout(ctx: *Context, value: Value, wanted: [2]u64) Error!void {
    try ctx.fields(value, "kind bytes alignment");
    try ctx.require(c.tag(value, "kind", "abi") and try ctx.nat(try ctx.field(value, "bytes"), std.math.maxInt(u64)) == wanted[0] and try ctx.nat(try ctx.field(value, "alignment"), std.math.maxInt(u64)) == wanted[1], "captured ABI layout disagrees with memory model");
}
