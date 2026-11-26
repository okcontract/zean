// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");
const f = @import("fixtures.zig");
const shared = @import("cases/shared.zig");
const source_sha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

const unit = f.obj(&.{.{ "kind", f.s("void") }});
const never = f.obj(&.{.{ "kind", f.s("noreturn") }});
const identity = f.obj(&.{
    .{ "name", f.s("fixture.child") },
    .{ "sourceFile", f.s("fixture.zig") },
    .{ "sourceSha256", f.repeat('a', 64) },
});
const leaf = f.derive(&shared.air_memory_program_2_input_13, &.{
    f.set("/name", f.s("fixture.child")),
    f.set("/signature/parameters", f.arr(&.{})),
    f.set("/signature/returnType", unit),
    f.set("/sourceValidity/slices", f.arr(&.{})),
    f.set("/body", f.arr(&.{f.n("0")})),
    f.set("/instructions", f.arr(&.{f.obj(&.{
        .{ "index", f.n("0") }, .{ "tag", f.s("ret") },                              .{ "payloadVisited", f.b(true) },
        .{ "type", never },     .{ "operand", f.obj(&.{.{ "kind", f.s("unit") }}) },
    })})),
});
const caller = f.derive(&leaf, &.{
    f.set("/name", f.s("fixture.parent")),
    f.set("/body", f.arr(&.{ f.n("0"), f.n("1") })),
    f.set("/instructions", f.arr(&.{
        f.obj(&.{
            .{ "index", f.n("0") }, .{ "tag", f.s("call") },                                                             .{ "payloadVisited", f.b(true) },
            .{ "type", unit },      .{ "callee", f.obj(&.{ .{ "kind", f.s("function") }, .{ "identity", identity } }) }, .{ "arguments", f.arr(&.{}) },
        }),
        f.obj(&.{
            .{ "index", f.n("1") }, .{ "tag", f.s("ret") },                                                               .{ "payloadVisited", f.b(true) },
            .{ "type", never },     .{ "operand", f.obj(&.{ .{ "kind", f.s("instruction") }, .{ "index", f.n("0") } }) },
        }),
    })),
});
const recursive_caller = f.derive(&caller, &.{f.set("/instructions/0/callee/identity/name", f.s("fixture.parent"))});
const generic_leaf = f.derive(&leaf, &.{
    f.set("/name", f.s("fixture.child__func_1")),
    f.set("/signature/genericInstance", f.b(true)),
    f.add("/specialization", f.obj(&.{
        .{ "schema", f.s("oksolc.generic-instance.v1") },
        .{ "owner", identity },
        .{ "sourceNoaliasBits", f.n("0") },
        .{ "sourceComptimeBits", f.n("1") },
        .{ "sourceParameterCount", f.n("1") },
        .{ "arguments", f.arr(&.{f.obj(&.{
            .{ "kind", f.s("type") },
            .{ "value", f.obj(&.{ .{ "kind", f.s("int") }, .{ "signedness", f.s("unsigned") }, .{ "bits", f.n("8") } }) },
        })}) },
    })),
});
const generic_caller = f.derive(&caller, &.{f.set("/instructions/0/callee/identity/name", f.s("fixture.child__func_1"))});

fn genericIdentity(comptime ty: f.Value) f.Value {
    return f.derive(&generic_leaf, &.{
        f.set("/signature/parameters", f.arr(&.{ty})),
        f.set("/signature/returnType", ty),
        f.set("/specialization/arguments/0/value", ty),
        f.set("/specialization/sourceParameterCount", f.n("2")),
        f.add("/specialization/arguments/1", f.obj(&.{ .{ "kind", f.s("runtime") }, .{ "runtimeIndex", f.n("0") } })),
        f.set("/body", f.arr(&.{ f.n("0"), f.n("1") })),
        f.set("/instructions", f.arr(&.{
            f.obj(&.{ .{ "index", f.n("0") }, .{ "tag", f.s("arg") }, .{ "payloadVisited", f.b(true) }, .{ "type", ty }, .{ "zirParameterIndex", f.n("1") } }),
            f.obj(&.{ .{ "index", f.n("1") }, .{ "tag", f.s("ret") }, .{ "payloadVisited", f.b(true) }, .{ "type", never }, .{ "operand", f.obj(&.{ .{ "kind", f.s("instruction") }, .{ "index", f.n("0") } }) } }),
        })),
    });
}

fn identityCaller(comptime ty: f.Value, comptime argument: f.Value) f.Value {
    return f.derive(&generic_caller, &.{
        f.set("/signature/returnType", ty),
        f.set("/instructions/0/type", ty),
        f.set("/instructions/0/arguments", f.arr(&.{argument})),
    });
}
const method_name = "fixture.Factory(u8).child__func_0";
const method_caller = f.derive(&caller, &.{f.set("/instructions/0/callee/identity/name", f.s(method_name))});
const method_leaf = f.derive(&generic_leaf, &.{
    f.set("/name", f.s(method_name)),
    f.set("/specialization/owner/name", f.s("fixture.Factory(u8).child")),
    f.set("/specialization/arguments/0/value/bits", f.n("16")),
    f.add("/sourceDeclarationNode", f.n("8")),
});
const method_source = "fn Factory(comptime T: type) type { _ = T; return struct { noinline fn child(comptime U: type) void { _ = U; } }; } export fn parent() void { Factory(u8).child(u16); }";
const nested_method_name = "fixture.Factory(u8).Nested(u32).child__func_0";
const nested_method_leaf = f.derive(&method_leaf, &.{
    f.set("/name", f.s(nested_method_name)),
    f.set("/specialization/owner/name", f.s("fixture.Factory(u8).Nested(u32).child")),
    f.set("/sourceDeclarationNode", f.n("15")),
});
const loop_leaf = f.derive(&leaf, &.{
    f.set("/instructions", f.arr(&.{
        f.obj(&.{ .{ "index", f.n("0") }, .{ "tag", f.s("loop") }, .{ "payloadVisited", f.b(true) }, .{ "type", never }, .{ "body", f.arr(&.{f.n("1")}) } }),
        f.obj(&.{
            .{ "index", f.n("1") },                                                                                                                .{ "tag", f.s("cond_br") },           .{ "payloadVisited", f.b(true) },     .{ "type", never },
            .{ "condition", f.obj(&.{ .{ "kind", f.s("constant") }, .{ "type", f.obj(&.{.{ "kind", f.s("bool") }}) }, .{ "value", f.n("0") } }) }, .{ "thenBody", f.arr(&.{f.n("2")}) }, .{ "elseBody", f.arr(&.{f.n("3")}) },
        }),
        f.obj(&.{ .{ "index", f.n("2") }, .{ "tag", f.s("repeat") }, .{ "payloadVisited", f.b(true) }, .{ "type", never }, .{ "target", f.n("0") } }),
        f.obj(&.{ .{ "index", f.n("3") }, .{ "tag", f.s("ret") }, .{ "payloadVisited", f.b(true) }, .{ "type", never }, .{ "operand", f.obj(&.{.{ "kind", f.s("unit") }}) } }),
    })),
});

const nested_leaf = f.derive(&leaf, &.{
    f.set("/name", f.s("nested.fixture.child")),
    f.set("/sourceFile", f.s("nested/fixture.zig")),
});
const block_leaf = f.derive(&leaf, &.{
    f.set("/body", f.arr(&.{ f.n("0"), f.n("2") })),
    f.set("/instructions", f.arr(&.{
        f.obj(&.{ .{ "index", f.n("0") }, .{ "tag", f.s("block") }, .{ "payloadVisited", f.b(true) }, .{ "type", unit }, .{ "body", f.arr(&.{f.n("1")}) } }),
        f.obj(&.{ .{ "index", f.n("1") }, .{ "tag", f.s("br") }, .{ "payloadVisited", f.b(true) }, .{ "type", never }, .{ "target", f.n("0") }, .{ "operand", f.obj(&.{.{ "kind", f.s("unit") }}) } }),
        f.obj(&.{ .{ "index", f.n("2") }, .{ "tag", f.s("ret") }, .{ "payloadVisited", f.b(true) }, .{ "type", never }, .{ "operand", f.obj(&.{ .{ "kind", f.s("instruction") }, .{ "index", f.n("0") } }) } }),
    })),
});
const nested_caller = f.derive(&caller, &.{
    f.set("/name", f.s("nested.fixture.parent")),
    f.set("/sourceFile", f.s("nested/fixture.zig")),
    f.set("/instructions/0/callee/identity/name", f.s("nested.fixture.child")),
    f.set("/instructions/0/callee/identity/sourceFile", f.s("nested/fixture.zig")),
});

const word = f.obj(&.{ .{ "kind", f.s("int") }, .{ "signedness", f.s("unsigned") }, .{ "bits", f.n("64") } });
const zero_layout = f.obj(&.{ .{ "kind", f.s("abi") }, .{ "bytes", f.n("0") }, .{ "alignment", f.n("1") } });
const tag_type = f.obj(&.{
    .{ "kind", f.s("enum") },
    .{ "identity", f.derive(&identity, &.{f.set("/name", f.s("fixture.Tag"))}) },
    .{ "layout", zero_layout },
    .{ "backingType", f.derive(&word, &.{f.set("/bits", f.n("0"))}) },
    .{ "nonexhaustive", f.b(false) },
    .{ "fields", f.arr(&.{f.obj(&.{ .{ "index", f.n("0") }, .{ "name", f.s("only") }, .{ "value", f.n("0") } })}) },
});
const singleton_type = f.obj(&.{
    .{ "kind", f.s("struct") },
    .{ "identity", f.derive(&identity, &.{f.set("/name", f.s("fixture.Token"))}) },
    .{ "layout", zero_layout },
    .{ "containerLayout", f.s("auto") },
    .{ "fields", f.arr(&.{f.obj(&.{
        .{ "index", f.n("0") },          .{ "name", f.s("tag") }, .{ "offset", f.n("0") },
        .{ "explicitAlignment", .null }, .{ "type", tag_type },
    })}) },
});
const token = f.obj(&.{
    .{ "kind", f.s("aggregate") },
    .{ "type", singleton_type },
    .{ "fields", f.arr(&.{f.obj(&.{ .{ "kind", f.s("enumTag") }, .{ "value", f.n("0") }, .{ "type", tag_type } })}) },
});

fn wordConstant(number: []const u8) f.Value {
    return f.obj(&.{ .{ "kind", f.s("constant") }, .{ "type", word }, .{ "value", f.n(number) } });
}

fn runtimeArgument(index: []const u8, source_index: []const u8) f.Value {
    return f.obj(&.{
        .{ "index", f.n(index) }, .{ "tag", f.s("arg") },                      .{ "payloadVisited", f.b(true) },
        .{ "type", word },        .{ "zirParameterIndex", f.n(source_index) },
    });
}

const singleton_leaf = f.derive(&leaf, &.{
    f.set("/signature/parameters", f.arr(&.{ word, singleton_type, word })),
    f.set("/signature/returnType", word),
    f.set("/body", f.arr(&.{ f.n("0"), f.n("1"), f.n("2") })),
    f.add("/instructions/0", runtimeArgument("0", "0")),
    f.add("/instructions/1", runtimeArgument("1", "2")),
    f.set("/instructions/2/index", f.n("2")),
    f.set("/instructions/2/operand", f.obj(&.{ .{ "kind", f.s("instruction") }, .{ "index", f.n("1") } })),
});
const singleton_caller = f.derive(&caller, &.{
    f.set("/signature/returnType", word),
    f.set("/instructions/0/type", word),
    f.set("/instructions/0/arguments", f.arr(&.{ wordConstant("11"), token, wordConstant("29") })),
});
const wrong_token = f.derive(&singleton_caller, &.{f.set("/instructions/0/arguments/1/type/identity/name", f.s("fixture.Other"))});
const wrong_tag = f.derive(&singleton_caller, &.{f.set("/instructions/0/arguments/1/fields/0/value", f.n("1"))});

fn singletonControls(ctx: *z.common.Context) !void {
    const child = try f.load(ctx.allocator, singleton_leaf);
    const children = [_]z.air.Callee{.{ .record = child, .declaration = "child", .machine_index = 0 }};
    const caller_raw = try f.load(ctx.allocator, singleton_caller);
    var decoder = try z.air.Decoder.initWith(ctx, caller_raw, .calls, .{ .call_machine = true, .callees = &children });
    const program = try decoder.program();
    try std.testing.expect(std.mem.indexOf(u8, program, "(.call 0 [(.constant (.scalar (.int false 64 (11)))), (.constant (.scalar (.int false 64 (29))))])") != null);
    const child_code = try z.air.decode(ctx, child, .calls);
    try std.testing.expect(std.mem.indexOf(u8, child_code, "(.argument 1)") != null);
    try std.testing.expectError(error.InvalidInput, z.air.decode(ctx, child, .memory));
    for ([_]f.Value{
        wrong_token,
        wrong_tag,
        f.derive(&singleton_caller, &.{f.remove("/instructions/0/arguments/1")}),
        f.derive(&singleton_caller, &.{f.set("/instructions/0/arguments/1/kind", f.s("undefined"))}),
    }) |input| {
        var rejected = try z.air.Decoder.initWith(ctx, try f.load(ctx.allocator, input), .calls, .{
            .call_machine = true,
            .callees = &children,
        });
        try std.testing.expectError(error.InvalidInput, rejected.program());
    }
    const wrong_prefix = f.derive(&singleton_leaf, &.{f.set("/instructions/1/zirParameterIndex", f.n("1"))});
    try std.testing.expectError(error.InvalidInput, z.air.decode(ctx, try f.load(ctx.allocator, wrong_prefix), .calls));
    const multiple_tags = f.derive(&singleton_leaf, &.{f.set("/signature/parameters/1/fields/0/type/nonexhaustive", f.b(true))});
    try std.testing.expectError(error.InvalidInput, z.air.decode(ctx, try f.load(ctx.allocator, multiple_tags), .calls));
}

pub fn controls() !void {
    {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var ctx: z.common.Context = .{ .allocator = arena.allocator() };
        try singletonControls(&ctx);
    }
    const definition = "pub fn child() void {} pub fn parent() void { child(); }";
    const identity_source = "pub fn child(comptime T: type, x: T) T { return x; } ";
    const optional = @import("optional_bytes.zig");
    const errors = @import("scalar_error.zig");
    const cases = [_]struct { input: f.Value = caller, callee: f.Value = leaf, source: []const u8 = definition, filename: []const u8 = "fixture.zig", child_declaration: []const u8 = "fn_child", argument: []const u8 = "", linked: bool = false, profile: z.air.Profile = .calls, imported: bool = false, include: bool = true, extra_root: bool = false, child_root: bool = false, accepted: bool = false }{
        .{
            .input = comptime identityCaller(optional.optional, optional.none),
            .callee = comptime genericIdentity(optional.optional),
            .source = identity_source ++ "pub fn parent() ?u8 { return child(?u8, null); }",
            .child_declaration = "fn_child__func_1",
            .argument = "(.constant (.optionalScalar (.int false 8) none))",
            .accepted = true,
        },
        .{
            .input = comptime identityCaller(errors.result, errors.missing),
            .callee = comptime genericIdentity(errors.result),
            .source = identity_source ++ "pub fn parent() error{InvalidDigit}!u8 { return child(error{InvalidDigit}!u8, error.InvalidDigit); }",
            .child_declaration = "fn_child__func_1",
            .argument = "(.constant (.errorScalar (.int false 8) [\"InvalidDigit\"] (.inl \"InvalidDigit\")))",
            .accepted = true,
        },
        .{ .accepted = true },
        .{
            .input = f.derive(&caller, &.{f.set("/instructions/0/callee/identity/name", f.s("fixture.Helper.parent"))}),
            .callee = f.derive(&leaf, &.{f.set("/name", f.s("fixture.Helper.parent"))}),
            .source = "pub fn parent() void { Helper.parent(); } const Helper = struct { pub fn parent() void {} };",
            .child_declaration = "fn_parent_1",
            .accepted = true,
        },
        .{
            .input = f.derive(&caller, &.{f.set("/instructions/0/callee/identity/name", f.s("fixture.Factory(u8).child"))}),
            // Prototype index captured by the pinned Zig compiler for this source.
            .callee = f.derive(&leaf, &.{ f.set("/name", f.s("fixture.Factory(u8).child")), f.add("/sourceDeclarationNode", f.n("8")) }),
            .source = "fn Factory(comptime T: type) type { _ = T; return struct { noinline fn child() void {} }; } export fn parent() void { Factory(u8).child(); }",
            .accepted = true,
        },
        .{ .input = nested_caller, .callee = nested_leaf, .filename = "nested/fixture.zig", .accepted = true },
        .{ .input = nested_caller, .callee = nested_leaf, .filename = "nested/fixture.zig", .linked = true },
        .{ .input = nested_caller, .callee = nested_leaf, .filename = "nested/fixture.zig", .source = "pub fn parent() void {} const Decoy = struct { pub fn child() void {} };" },
        .{ .input = nested_caller, .callee = leaf, .filename = "nested/fixture.zig" },
        .{ .accepted = true, .imported = true },
        .{ .extra_root = true },
        .{ .input = generic_caller, .callee = generic_leaf, .source = "pub fn child(comptime T: type) void { _ = T; } pub fn parent() void { child(u8); }", .imported = true, .child_root = true },
        .{ .input = generic_caller, .callee = generic_leaf, .source = "pub fn child(comptime T: type) void { _ = T; } pub fn parent() void { child(u8); }", .imported = true, .extra_root = true },
        .{ .extra_root = true, .imported = true, .accepted = true },
        .{ .input = f.derive(&caller, &.{f.set("/instructions/0/tag", f.s("call_never_inline"))}), .accepted = true },
        .{ .include = false },
        .{ .input = f.derive(&caller, &.{f.set("/instructions/0/callee/identity/sourceSha256", f.repeat('b', 64))}) },
        .{ .input = f.derive(&caller, &.{f.set("/instructions/0/callee/identity/sourceFile", f.s("decoy.zig"))}) },
        .{ .input = recursive_caller },
        .{ .input = recursive_caller, .profile = .nested_calls },
        .{ .input = recursive_caller, .profile = .recursive_calls, .source = "pub fn parent() void { parent(); }", .child_declaration = "fn_parent", .include = false, .accepted = true },
        .{ .input = f.derive(&recursive_caller, &.{f.set("/instructions/0/callee/identity/sourceSha256", f.repeat('b', 64))}), .profile = .recursive_calls },
        .{ .input = f.derive(&recursive_caller, &.{f.set("/instructions/0/arguments", f.arr(&.{f.obj(&.{.{ "kind", f.s("unit") }})}))}), .profile = .recursive_calls },
        .{ .input = f.derive(&caller, &.{f.set("/instructions/0/tag", f.s("call_always_tail"))}) },
        .{ .input = f.derive(&caller, &.{f.set("/instructions/0/arguments", f.arr(&.{f.obj(&.{.{ "kind", f.s("unit") }})}))}) },
        .{ .callee = f.derive(&leaf, &.{f.set("/instructions/0/tag", f.s("unreach"))}) },
        .{ .callee = f.derive(&leaf, &.{f.set("/signature/genericInstance", f.b(true))}) },
        .{
            .input = generic_caller,
            .callee = generic_leaf,
            .source = "pub fn child(comptime T: type) void { _ = T; } pub fn parent() void { child(u8); }",
            .child_declaration = "fn_child__func_1",
            .accepted = true,
        },
        .{
            .input = generic_caller,
            .callee = generic_leaf,
            .source = "pub fn child(comptime T: u8) void { _ = T; } pub fn parent() void { child(0); }",
        },
        .{
            .input = f.derive(&caller, &.{f.set("/instructions/0/callee/identity/name", f.s(nested_method_name))}),
            .callee = nested_method_leaf,
            .source = "fn Factory(comptime T: type) type { _ = T; return struct { fn Nested(comptime V: type) type { _ = V; return struct { noinline fn child(comptime U: type) void { _ = U; } }; } }; } export fn parent() void { Factory(u8).Nested(u32).child(u16); }",
            .child_declaration = "fn_child__func_0",
            .accepted = true,
        },
        .{ .input = method_caller, .callee = method_leaf, .source = method_source, .child_declaration = "fn_child__func_0", .accepted = true },
        .{ .input = method_caller, .callee = f.derive(&method_leaf, &.{f.set("/sourceDeclarationNode", f.n("19"))}), .source = method_source },
        .{ .input = method_caller, .callee = f.derive(&method_leaf, &.{f.remove("/sourceDeclarationNode")}), .source = method_source },
        .{ .callee = f.derive(&leaf, &.{f.set("/signature/noaliasBits", f.n("1"))}) },
        .{ .callee = f.derive(&leaf, &.{f.set("/sourceFile", f.s("decoy.zig"))}) },
        .{ .source = "pub fn parent() void {} const Decoy = struct { pub fn child() void {} };" },
        .{ .source = "pub fn child() void {} const Decoy = struct { pub fn parent() void {} };" },
        .{ .imported = true, .source = "pub fn parent() void {} const Decoy = struct { pub fn child() void {} };" },
        .{ .profile = .nested_calls, .accepted = true },
        .{ .callee = loop_leaf },
        .{ .profile = .nested_calls, .callee = loop_leaf, .accepted = true },
        .{ .profile = .nested_calls, .callee = loop_leaf, .source = "pub fn parent() void {} const Decoy = struct { pub fn child() void {} };" },
        .{ .profile = .nested_calls, .callee = loop_leaf, .input = f.derive(&caller, &.{f.set("/instructions/0/callee/identity/sourceSha256", f.repeat('b', 64))}) },
        .{ .profile = .nested_calls, .callee = f.derive(&loop_leaf, &.{f.set("/instructions/2/target", f.n("1"))}) },
    };
    for (cases, 0..) |case, case_index| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var ctx: z.common.Context = .{ .allocator = arena.allocator() };
        var tmp = std.testing.tmpDir(.{});
        defer tmp.cleanup();
        const path = try std.fs.path.resolve(ctx.allocator, &.{ ".zig-cache", "tmp", &tmp.sub_path });
        try tmp.dir.createDir(std.testing.io, "air", .default_dir);
        const sha = try ctx.allocator.dupe(u8, &z.common.digest(case.source));
        var parent_value = try f.load(ctx.allocator, case.input);
        var child_value = try f.load(ctx.allocator, case.callee);
        try parent_value.object.put(ctx.allocator, "sourceSha256", .{ .string = sha });
        try child_value.object.put(ctx.allocator, "sourceSha256", .{ .string = sha });
        if (z.common.get(child_value, "specialization")) |specialization_value| {
            var spec = specialization_value;
            var owner = try ctx.field(spec, "owner");
            try owner.object.put(ctx.allocator, "sourceSha256", .{ .string = sha });
            try spec.object.put(ctx.allocator, "owner", owner);
            try child_value.object.put(ctx.allocator, "specialization", spec);
        }
        const instructions = try ctx.array(try ctx.field(parent_value, "instructions"));
        var target = try ctx.field(try ctx.field(instructions[0], "callee"), "identity");
        if (z.common.tag(target, "sourceSha256", source_sha)) try target.object.put(ctx.allocator, "sourceSha256", .{ .string = sha });
        var callee = try ctx.field(instructions[0], "callee");
        try callee.object.put(ctx.allocator, "identity", target);
        var instruction = instructions[0];
        try instruction.object.put(ctx.allocator, "callee", callee);
        var table = try ctx.field(parent_value, "instructions");
        table.array.items[0] = instruction;
        try parent_value.object.put(ctx.allocator, "instructions", table);
        const parent = try ctx.json(parent_value);
        const child = try ctx.json(child_value);
        if (case.linked) {
            try tmp.dir.createDir(std.testing.io, "actual", .default_dir);
            try tmp.dir.symLink(std.testing.io, "actual", "nested", .{ .is_directory = true });
        } else if (std.fs.path.dirname(case.filename)) |directory| try tmp.dir.createDirPath(std.testing.io, directory);
        try tmp.dir.writeFile(std.testing.io, .{ .sub_path = case.filename, .data = case.source });
        try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "air/parent.json", .data = parent });
        try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "air/child.json", .data = child });
        var functions: z.common.Value = .{ .object = .empty };
        const parent_name = try ctx.str(try ctx.field(parent_value, "name"));
        const child_name = try ctx.str(try ctx.field(child_value, "name"));
        try functions.object.put(ctx.allocator, parent_name, try ctx.parse(try ctx.json(.{ .requested = !case.imported, .file = "parent.json", .sha256 = &z.common.digest(parent) })));
        if (case.include) try functions.object.put(ctx.allocator, child_name, try ctx.parse(try ctx.json(.{ .requested = false, .file = "child.json", .sha256 = &z.common.digest(child) })));
        var source_files: z.common.Value = .{ .object = .empty };
        try source_files.object.put(ctx.allocator, case.filename, .{ .string = sha });
        const report = try ctx.json(.{
            .schema = "oksolc.fresh-air-capture.v1",
            .status = "captured",
            .captureComplete = true,
            .zigVersion = z.version,
            .zigRevision = z.revision,
            .sourceSha256 = if (case.imported) source_sha else sha,
            .sourceFiles = source_files,
            .functions = functions,
        });
        try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "report.json", .data = report });
        const options: z.translate.Options = .{
            .capture = try ctx.fmt("{s}/report.json", .{path}),
            .roots = if (case.child_root) &.{child_name} else if (case.extra_root) &.{ parent_name, child_name } else &.{parent_name},
            .output = try ctx.fmt("{s}/output", .{path}),
            .profile = case.profile,
            .declaration_source = if (case.imported) try ctx.fmt("{s}/fixture.zig", .{path}) else null,
        };
        if (case.accepted) {
            _ = z.translate.run(&ctx, std.testing.io, options) catch |err| {
                std.debug.print("call admission case {d}: {s}\n", .{ case_index, ctx.diagnostic });
                return err;
            };
            const generated = try ctx.read(std.testing.io, try ctx.fmt("{s}/Generated.lean", .{options.output}), 16384);
            try std.testing.expect(std.mem.indexOf(u8, generated, try ctx.fmt("(.call FunctionId.{s} [{s}])", .{ case.child_declaration, case.argument })) != null);
            if (std.mem.indexOfScalar(u8, child_name, '(') != null) {
                try std.testing.expect(std.mem.indexOf(u8, generated, "-- Zig declaration: fixture.Factory(") == null);
                try std.testing.expect(std.mem.indexOf(u8, generated, "-- Zig declaration: fixture.parent\n") != null);
            }
            if (case.profile != .recursive_calls)
                try std.testing.expect(std.mem.indexOf(u8, generated, try ctx.fmt("def {s} :", .{case.child_declaration})).? < std.mem.indexOf(u8, generated, "def fn_parent :").?);
        } else {
            try std.testing.expectError(error.InvalidInput, z.translate.run(&ctx, std.testing.io, options));
            try std.testing.expectError(error.FileNotFound, tmp.dir.statFile(std.testing.io, "output", .{}));
        }
        var machine_options = options;
        machine_options.call_machine = true;
        machine_options.output = try ctx.fmt("{s}/machine", .{path});
        if (case.accepted) {
            const summary = try z.translate.run(&ctx, std.testing.io, machine_options);
            try std.testing.expect(z.common.tag(summary, "executionModel", "call-machine"));
            const generated = try ctx.read(std.testing.io, try ctx.fmt("{s}/Generated.lean", .{machine_options.output}), 16384);
            try std.testing.expect(std.mem.indexOf(u8, generated, try ctx.fmt("(.call FunctionId.{s} [{s}])", .{ case.child_declaration, case.argument })) != null);
            try std.testing.expect(std.mem.indexOf(u8, generated, try ctx.fmt("def FunctionId.{s} : Nat := 0", .{case.child_declaration})) != null);
            try std.testing.expect(std.mem.indexOf(u8, generated, " <|\n      (.ret (.local 0))") != null);
            if (case.profile == .recursive_calls) {
                try std.testing.expect(std.mem.indexOf(u8, generated, "def functions : Program := [fn_parent]") != null);
            } else {
                try std.testing.expect(std.mem.indexOf(u8, generated, "def FunctionId.fn_parent : Nat := 1") != null);
                try std.testing.expect(std.mem.indexOf(u8, generated, try ctx.fmt("def functions : Program := [{s}, fn_parent]", .{case.child_declaration})) != null);
            }
            try std.testing.expect(std.mem.indexOf(u8, generated, ".target") == null);
            try std.testing.expectEqualStrings(generated, try ctx.read(std.testing.io, try ctx.fmt("{s}/Generated.lean", .{options.output}), 16384));
        } else {
            try std.testing.expectError(error.InvalidInput, z.translate.run(&ctx, std.testing.io, machine_options));
            try std.testing.expectError(error.FileNotFound, tmp.dir.statFile(std.testing.io, "machine", .{}));
        }
    }
}

pub fn singletonEmitted(ctx: *z.common.Context) ![]const u8 {
    const child = try f.load(ctx.allocator, singleton_leaf);
    const parent = try f.load(ctx.allocator, singleton_caller);
    var callee = try z.air.Decoder.initWith(ctx, child, .calls, .{ .call_machine = true });
    var machine = try z.air.Decoder.initWith(ctx, parent, .calls, .{
        .call_machine = true,
        .callees = &.{.{ .record = child, .declaration = "child", .machine_index = 0 }},
    });
    return ctx.fmt(
        \\import Compiler.ZigAir.CapturedCallMachine
        \\open Compiler.ZigAir Compiler.ZigAir.MemoryCallMachine
        \\def child : Function :=
        \\{s}
        \\def parent : Function :=
        \\{s}
        \\def rawChild : Captured.Raw := {s}
        \\def rawParent : Captured.Raw := {s}
        \\def wrongToken : Captured.Raw := {s}
        \\def wrongTag : Captured.Raw := {s}
        \\example : CapturedCallMachine.decode [rawChild, rawParent] = some [child, parent] := rfl
        \\example : CapturedCallMachine.decode [rawChild, wrongToken] = none := rfl
        \\example : CapturedCallMachine.decode [rawChild, wrongTag] = none := rfl
        \\example : run [child, parent] 8 1 [] {{}} = .finished (.ok (.scalar (.int false 64 29))) {{}} := rfl
        \\
    , .{
        try callee.program(),                                                   try machine.program(),
        try z.certificate.lift(ctx, child, 0),                                  try z.certificate.lift(ctx, parent, 0),
        try z.certificate.lift(ctx, try f.load(ctx.allocator, wrong_token), 0), try z.certificate.lift(ctx, try f.load(ctx.allocator, wrong_tag), 0),
    });
}

pub fn emitted(ctx: *z.common.Context) ![]const u8 {
    const child = try f.load(ctx.allocator, leaf);
    const parent = try f.load(ctx.allocator, caller);
    const child_text = try z.air.decode(ctx, child, .calls);
    var finite = try z.air.Decoder.initWith(ctx, parent, .calls, .{ .callees = &.{.{ .record = child, .declaration = "child" }} });
    var looping = try z.air.Decoder.initWith(ctx, parent, .call_loops, .{ .callees = &.{.{ .record = child, .declaration = "child" }} });
    const previous = try ctx.fmt(
        \\import Compiler.ZigAir.CapturedCalls
        \\open Compiler.ZigAir.MemoryCall
        \\def child : Program :=
        \\{s}
        \\def parent : Program :=
        \\{s}
        \\def resumable : Program true :=
        \\{s}
        \\{s}
        \\{s}
        \\{s}
        \\example : parent.run [] {{}} = (.ok (.scalar .unit), {{}}) := rfl
        \\example : resumable.runFuel 8 [] {{}} = .finished (.ok (.scalar .unit)) {{}} := rfl
        \\open Compiler.ZigAir
        \\example : CapturedCalls.decode 64 false [] parent_captured = none := rfl
        \\example : CapturedCalls.decode 64 false [child_captured, child_captured] parent_captured = none := rfl
        \\def replaceIdentity (raw : Captured.Raw) : Captured.Raw := match raw with
        \\  | .object fields => .object (fields.map fun (key, value) => (key, if key == "sourceSha256" then .string "different" else value))
        \\  | value => value
        \\example : CapturedCalls.decode 64 false [replaceIdentity child_captured] parent_captured = none := rfl
        \\example : CapturedCalls.decode 0 false [child_captured] parent_captured = none := rfl
        \\
    , .{ child_text, try finite.program(), try looping.program(), try z.certificate.callDeclaration(ctx, child, "child", false, &.{}), try z.certificate.callDeclaration(ctx, parent, "parent", false, &.{.{ .record = child, .declaration = "child" }}), try z.certificate.callDeclaration(ctx, parent, "resumable", true, &.{.{ .record = child, .declaration = "child" }}) });
    const loop_child = try f.load(ctx.allocator, loop_leaf);
    const targets = [_]z.air.Callee{.{ .record = loop_child, .declaration = "loopChild", .profile = .call_loops }};
    var partial = try z.air.Decoder.initWith(ctx, parent, .nested_calls, .{ .callees = &targets });
    var machine = try z.air.Decoder.initWith(ctx, parent, .calls, .{ .call_machine = true, .callees = &.{.{ .record = child, .declaration = "child", .machine_index = 0 }} });
    const self_call = try f.load(ctx.allocator, recursive_caller);
    var recursive = try z.air.Decoder.initWith(ctx, self_call, .recursive_calls, .{
        .call_machine = true,
        .callees = &.{.{ .record = self_call, .declaration = "recursiveBody", .profile = .recursive_calls, .machine_index = 0 }},
    });
    var machine_loop = try z.air.Decoder.initWith(ctx, loop_child, .call_loops, .{ .call_machine = true });
    const block_child = try f.load(ctx.allocator, block_leaf);
    var machine_block = try z.air.Decoder.initWith(ctx, block_child, .calls, .{ .call_machine = true });
    return ctx.fmt(
        \\import Compiler.ZigAir.CapturedCallMachine
        \\import Compiler.ZigAir.CapturedNestedCalls
        \\{s}
        \\def loopChild : Compiler.ZigAir.MemoryCall.Program true :=
        \\{s}
        \\{s}
        \\def partialCaller : Compiler.ZigAir.MemoryPartialCall.Program :=
        \\{s}
        \\{s}
        \\example : partialCaller.observe 10 [] {{}} = .finished (.ok (.scalar .unit)) {{}} := rfl
        \\example : partialCaller.observe 0 [] {{}} = .pending {{}} := rfl
        \\example : CapturedNestedCalls.decode 64 [] partialCaller_captured = none := rfl
        \\example : CapturedNestedCalls.decode 64 [loopChild_captured, loopChild_captured] partialCaller_captured = none := rfl
        \\example : CapturedNestedCalls.decode 64 [replaceIdentity loopChild_captured] partialCaller_captured = none := rfl
        \\example : CapturedNestedCalls.decode 0 [loopChild_captured] partialCaller_captured = none := rfl
        \\def machineChild : MemoryCallMachine.Function :=
        \\{s}
        \\def machineParent : MemoryCallMachine.Function :=
        \\{s}
        \\example : CapturedCallMachine.decode [child_captured, parent_captured] = some [machineChild, machineParent] := rfl
        \\example : CapturedCallMachine.decode [parent_captured, child_captured] = none := rfl
        \\example : CapturedCallMachine.decode [child_captured, child_captured] = none := rfl
        \\example : CapturedCallMachine.decode [replaceIdentity child_captured, parent_captured] = none := rfl
        \\def recursiveBody : MemoryCallMachine.Function :=
        \\{s}
        \\def recursiveCaptured : Captured.Raw := {s}
        \\example : CapturedCallMachine.decodeRecursive [recursiveCaptured] = some [recursiveBody] := rfl
        \\example : CapturedCallMachine.decode [recursiveCaptured] = none := rfl
        \\def forwardParent : MemoryCallMachine.Function :=
        \\  ⟨[], .scalar .unit, .bind 0 (.scalar .unit) (.call 1 []) (.ret (.local 0))⟩
        \\example : CapturedCallMachine.decodeRecursive [parent_captured, child_captured] =
        \\    some [forwardParent, machineChild] := rfl
        \\def omitField (raw : Captured.Raw) (key : String) : Captured.Raw := match raw with
        \\  | .object fields => .object (fields.filter (fun field => field.1 != key))
        \\  | value => value
        \\example : CapturedCallMachine.decodeRecursive [omitField child_captured "name"] = none := rfl
        \\example : CapturedCallMachine.decodeRecursive [omitField child_captured "sourceFile"] = none := rfl
        \\example : CapturedCallMachine.decode [omitField child_captured "sourceSha256"] = none := rfl
        \\example : CapturedCallMachine.decodeRecursive [replaceIdentity child_captured] = none := rfl
        \\example : CapturedCallMachine.decodeRecursive [parent_captured, parent_captured, child_captured] = none := rfl
        \\example : CapturedCallMachine.decodeRecursive [parent_captured, replaceIdentity child_captured] = none := rfl
        \\example : MemoryCallMachine.run [machineChild, machineParent] 3 1 [] {{}} = .finished (.ok (.scalar .unit)) {{}} := rfl
        \\def machineLoopChild : MemoryCallMachine.Function :=
        \\{s}
        \\example : CapturedCallMachine.decode [loopChild_captured] = some [machineLoopChild] := rfl
        \\example : MemoryCallMachine.run [machineLoopChild] 4 0 [] {{}} = .finished (.ok (.scalar .unit)) {{}} := rfl
        \\def machineBlockChild : MemoryCallMachine.Function :=
        \\{s}
        \\def blockCaptured : Captured.Raw := {s}
        \\example : CapturedCallMachine.decode [blockCaptured] = some [machineBlockChild] := rfl
        \\example : MemoryCallMachine.run [machineBlockChild] 3 0 [] {{}} = .finished (.ok (.scalar .unit)) {{}} := rfl
        \\
    , .{ previous, try z.air.decode(ctx, loop_child, .call_loops), try z.certificate.callDeclaration(ctx, loop_child, "loopChild", true, &.{}), try partial.program(), try z.certificate.nestedDeclaration(ctx, parent, "partialCaller", &targets), child_text, try machine.program(), try recursive.program(), try z.certificate.lift(ctx, self_call, 0), try machine_loop.program(), try machine_block.program(), try z.certificate.lift(ctx, block_child, 0) });
}
