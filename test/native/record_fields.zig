// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
const std = @import("std");
const z = @import("zean");
const f = @import("fixtures.zig");
const shared = @import("cases/shared.zig");

const word = f.obj(&.{ .{ "kind", f.s("int") }, .{ "bits", f.n("64") }, .{ "signedness", f.s("unsigned") } });
const layout = f.obj(&.{ .{ "kind", f.s("abi") }, .{ "bytes", f.n("8") }, .{ "alignment", f.n("8") } });
const pointer = f.obj(&.{
    .{ "kind", f.s("pointer") },                                                                                                .{ "child", f.ref(&shared.struct_38) },
    .{ "flags", f.derive(&shared.air_aggregate_program_4_input_instructions_type_flags_41, &.{f.set("/isConst", f.b(true))}) }, .{ "layout", layout },
    .{ "pointeeLayout", f.derive(&layout, &.{f.set("/bytes", f.n("16"))}) },                                                    .{ "sentinel", .null },
});
const field_pointer = f.derive(&pointer, &.{ f.set("/child", word), f.set("/pointeeLayout", layout) });
const argument = f.obj(&.{ .{ "kind", f.s("instruction") }, .{ "index", f.n("0") } });
const selected = f.derive(&argument, &.{f.set("/index", f.n("1"))});
const read_field = f.derive(&shared.air_memory_program_2_input_13, &.{
    f.set("/signature/parameters", f.arr(&.{pointer})), f.set("/signature/returnType", word),
    f.set("/sourceValidity/slices", f.arr(&.{})),       f.set("/body", f.arr(&.{ f.n("0"), f.n("1"), f.n("2"), f.n("3") })),
    f.set("/instructions", f.arr(&.{
        f.obj(&.{ .{ "index", f.n("0") }, .{ "tag", f.s("arg") }, .{ "payloadVisited", f.b(true) }, .{ "type", pointer }, .{ "zirParameterIndex", f.n("0") } }),
        f.obj(&.{ .{ "index", f.n("1") }, .{ "tag", f.s("struct_field_ptr_index_1") }, .{ "payloadVisited", f.b(true) }, .{ "type", field_pointer }, .{ "operand", argument }, .{ "fieldIndex", f.n("1") } }),
        f.obj(&.{ .{ "index", f.n("2") }, .{ "tag", f.s("load") }, .{ "payloadVisited", f.b(true) }, .{ "type", word }, .{ "operand", selected } }),
        f.obj(&.{ .{ "index", f.n("3") }, .{ "tag", f.s("ret") }, .{ "payloadVisited", f.b(true) }, .{ "type", f.obj(&.{.{ "kind", f.s("noreturn") }}) }, .{ "operand", f.derive(&argument, &.{f.set("/index", f.n("2"))}) } }),
    })),
});

const opaque_enum = f.obj(&.{
    .{ "kind", f.s("enum") },
    .{ "identity", f.obj(&.{
        .{ "name", f.s("fixture.Mode") },                                                             .{ "sourceFile", f.s("fixture.zig") },
        .{ "sourceSha256", f.s("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") },
    }) },
    .{ "backingType", f.obj(&.{ .{ "kind", f.s("int") }, .{ "bits", f.n("2") }, .{ "signedness", f.s("unsigned") } }) },
    .{ "layout", f.derive(&layout, &.{ f.set("/bytes", f.n("1")), f.set("/alignment", f.n("1")) }) },
    .{ "nonexhaustive", f.b(false) },
    .{ "fields", f.arr(&.{
        f.obj(&.{ .{ "index", f.n("0") }, .{ "name", f.s("off") }, .{ "value", f.n("0") } }),
        f.obj(&.{ .{ "index", f.n("1") }, .{ "name", f.s("on") }, .{ "value", f.n("2") } }),
    }) },
});
const enum_owner = f.derive(&read_field, &.{
    f.set("/signature/parameters/0/child/fields/0/type", opaque_enum),
    f.set("/instructions/0/type/child/fields/0/type", opaque_enum),
});
const invalid_enums = [_]f.Value{
    f.derive(&opaque_enum, &.{f.set("/backingType/bits", f.n("0"))}),
    f.derive(&opaque_enum, &.{f.set("/backingType/bits", f.n("65"))}),
    f.derive(&opaque_enum, &.{f.set("/backingType/signedness", f.s("signed"))}),
    f.derive(&opaque_enum, &.{f.set("/layout/bytes", f.n("2"))}),
    f.derive(&opaque_enum, &.{f.set("/nonexhaustive", f.b(true))}),
    f.derive(&opaque_enum, &.{f.set("/fields/1/index", f.n("2"))}),
    f.derive(&opaque_enum, &.{f.set("/fields/1/name", f.s("off"))}),
    f.derive(&opaque_enum, &.{f.set("/fields/1/value", f.n("0"))}),
    f.derive(&opaque_enum, &.{f.set("/fields/1/value", f.n("4"))}),
    f.derive(&opaque_enum, &.{f.set("/identity/sourceSha256", f.s("bad"))}),
};

const bytes_layout = f.derive(&layout, &.{ f.set("/bytes", f.n("3")), f.set("/alignment", f.n("1")) });
const byte = f.derive(&word, &.{f.set("/bits", f.n("8"))});
const array_pointer = f.derive(&pointer, &.{
    f.set("/child", f.obj(&.{ .{ "kind", f.s("array") }, .{ "length", f.n("3") }, .{ "child", byte }, .{ "layout", bytes_layout }, .{ "sentinel", .null } })),
    f.set("/pointeeLayout", bytes_layout),
});
const byte_slice = f.derive(&array_pointer, &.{
    f.set("/child", byte), f.set("/flags/size", f.s("slice")), f.set("/layout/bytes", f.n("16")), f.set("/pointeeLayout/bytes", f.n("1")),
});
const array_slice = f.derive(&read_field, &.{
    f.set("/signature/parameters", f.arr(&.{array_pointer})),  f.set("/signature/returnType", byte_slice),
    f.set("/body", f.arr(&.{ f.n("0"), f.n("1"), f.n("2") })),
    f.set("/instructions", f.arr(&.{
        f.obj(&.{ .{ "index", f.n("0") }, .{ "tag", f.s("arg") }, .{ "payloadVisited", f.b(true) }, .{ "type", array_pointer }, .{ "zirParameterIndex", f.n("0") } }),
        f.obj(&.{ .{ "index", f.n("1") }, .{ "tag", f.s("array_to_slice") }, .{ "payloadVisited", f.b(true) }, .{ "type", byte_slice }, .{ "operand", argument } }),
        f.obj(&.{ .{ "index", f.n("2") }, .{ "tag", f.s("ret") }, .{ "payloadVisited", f.b(true) }, .{ "type", f.obj(&.{.{ "kind", f.s("noreturn") }}) }, .{ "operand", selected } }),
    })),
});
const invalid_arrays = [_]f.Value{
    f.derive(&array_slice, &.{f.set("/instructions/1/type/flags/isConst", f.b(false))}),
    f.derive(&array_slice, &.{ f.set("/signature/parameters/0/flags/size", f.s("many")), f.set("/instructions/0/type/flags/size", f.s("many")) }),
    f.derive(&array_slice, &.{ f.set("/instructions/1/type/child/bits", f.n("16")), f.set("/instructions/1/type/pointeeLayout/bytes", f.n("2")), f.set("/instructions/1/type/pointeeLayout/alignment", f.n("2")) }),
};

pub fn controls() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var ctx: z.common.Context = .{ .allocator = arena.allocator() };
    const decoded = try z.air.decode(&ctx, try f.load(ctx.allocator, read_field), .memory);
    // Declaration index 1 has offset 0: native field order is not byte order.
    try std.testing.expect(std.mem.indexOf(u8, decoded, "(.fieldPointer (.local 0) 0)") != null);
    for ([_]f.Value{
        f.derive(&read_field, &.{f.set("/instructions/1/fieldIndex", f.n("2"))}),
        f.derive(&read_field, &.{f.set("/instructions/1/tag", f.s("struct_field_ptr_index_0"))}),
        f.derive(&read_field, &.{f.set("/instructions/1/type/flags/isConst", f.b(false))}),
        f.derive(&read_field, &.{f.set("/instructions/1/operand/index", f.n("1"))}),
        f.derive(&read_field, &.{
            f.set("/signature/parameters/0/child/fields/0/offset", f.n("0")),
            f.set("/instructions/0/type/child/fields/0/offset", f.n("0")),
        }),
        f.derive(&read_field, &.{
            f.set("/instructions/1/type/child/bits", f.n("32")),
            f.set("/instructions/1/type/pointeeLayout/bytes", f.n("4")),
            f.set("/instructions/1/type/pointeeLayout/alignment", f.n("4")),
        }),
    }) |input| try std.testing.expectError(error.InvalidInput, z.air.decode(&ctx, try f.load(ctx.allocator, input), .memory));
    const record_value = f.derive(&read_field, &.{
        f.set("/signature/parameters/0", f.ref(&shared.struct_38)),
        f.set("/instructions/0/type", f.ref(&shared.struct_38)),
    });
    try std.testing.expectError(error.InvalidInput, z.air.decode(&ctx, try f.load(ctx.allocator, record_value), .memory));
    const enum_decoded = try z.air.decode(&ctx, try f.load(ctx.allocator, enum_owner), .memory);
    try std.testing.expect(std.mem.indexOf(u8, enum_decoded, "(.record \"enum:fixture.Mode\" ⟨1, 1⟩)") != null);
    for (invalid_enums) |invalid| {
        const mutations = [_]f.Edit{
            f.set("/signature/parameters/0/child/fields/0/type", invalid),
            f.set("/instructions/0/type/child/fields/0/type", invalid),
        };
        try std.testing.expectError(error.InvalidInput, z.air.decode(&ctx, try f.load(ctx.allocator, f.derive(&enum_owner, &mutations)), .memory));
    }
    // Storage admission cannot be used as a runtime enum-value implementation.
    const runtime_enum = f.derive(&enum_owner, &.{ f.set("/signature/returnType", opaque_enum), f.set("/instructions/2/type", opaque_enum) });
    try std.testing.expectError(error.InvalidInput, z.air.decode(&ctx, try f.load(ctx.allocator, runtime_enum), .memory));
    const conversion = try z.air.decode(&ctx, try f.load(ctx.allocator, array_slice), .memory);
    try std.testing.expect(std.mem.indexOf(u8, conversion, "(.arrayToSlice (.local 0))") != null);
    for (invalid_arrays) |invalid| try std.testing.expectError(error.InvalidInput, z.air.decode(&ctx, try f.load(ctx.allocator, invalid), .memory));
}

pub fn emitted(ctx: *z.common.Context) ![]const u8 {
    const raw = try f.load(ctx.allocator, read_field);
    const wrong_index = try f.load(ctx.allocator, f.derive(&read_field, &.{f.set("/instructions/1/fieldIndex", f.n("2"))}));
    const original = try ctx.fmt(
        \\import Compiler.ZigAir.Captured
        \\open Compiler.ZigAir Compiler.ZigAir.MemoryAir Compiler.ZigAir.Memory
        \\def readField : Program := {s}
        \\{s}
        \\def pair : Ty := .aggregate "fixture.Pair" ⟨16, 8⟩ [(0, .scalar (.int false 64)), (8, .scalar (.int false 64))]
        \\def heap : State := ⟨[(0, ⟨8, pair, [(0, .scalar (.int false 64 42))], true, false⟩)], 1, 24⟩
        \\example : readField.run [.pointer (.pointer false false pair) ⟨0, 0⟩] heap = (.ok (.scalar (.int false 64 42)), heap) := rfl
        \\example : readField.run [.pointer (.pointer false false pair) ⟨0, 8⟩] heap = (.error .memoryValidity, heap) := rfl
        \\example : Captured.decode false {s} = none := rfl
        \\
    , .{ try z.air.decode(ctx, raw, .memory), try z.certificate.declaration(ctx, raw, "readField", false), try z.certificate.lift(ctx, wrong_index, 0) });
    const with_enum = try f.load(ctx.allocator, enum_owner);
    var parts: std.ArrayList([]const u8) = .empty;
    try parts.append(ctx.allocator, original);
    try parts.append(ctx.allocator, try ctx.fmt("def readWithEnum : Program := {s}\n{s}\n", .{ try z.air.decode(ctx, with_enum, .memory), try z.certificate.declaration(ctx, with_enum, "readWithEnum", false) }));
    for (invalid_enums) |invalid| try parts.append(ctx.allocator, try ctx.fmt("example : Captured.typeOf 17 {s} = none := by decide +kernel\n", .{try z.certificate.lift(ctx, try f.load(ctx.allocator, invalid), 0)}));
    const conversion = try f.load(ctx.allocator, array_slice);
    try parts.append(ctx.allocator, try ctx.fmt("def arraySlice : Program := {s}\n{s}\n", .{ try z.air.decode(ctx, conversion, .memory), try z.certificate.declaration(ctx, conversion, "arraySlice", false) }));
    try parts.append(ctx.allocator,
        \\example : arraySlice.run [.pointer (.pointer false false (.array 3 (.scalar (.int false 8)))) ⟨4, 7⟩] ⟨[], 0, 1⟩ =
        \\    (.ok (.slice (.slice false (.scalar (.int false 8))) ⟨4, 7⟩ 3), ⟨[], 0, 1⟩) := rfl
        \\
    );
    for (invalid_arrays) |invalid| try parts.append(ctx.allocator, try ctx.fmt("example : Captured.decode false {s} = none := rfl\n", .{try z.certificate.lift(ctx, try f.load(ctx.allocator, invalid), 0)}));
    return std.mem.concat(ctx.allocator, u8, parts.items);
}
