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

pub fn controls() !void {
    const definition = "pub fn child() void {} pub fn parent() void { child(); }";
    const cases = [_]struct { input: f.Value = caller, callee: f.Value = leaf, source: []const u8 = definition, filename: []const u8 = "fixture.zig", child_declaration: []const u8 = "fn_child", linked: bool = false, profile: z.air.Profile = .calls, imported: bool = false, include: bool = true, extra_root: bool = false, accepted: bool = false }{
        .{ .accepted = true },
        .{
            .input = f.derive(&caller, &.{f.set("/instructions/0/callee/identity/name", f.s("fixture.Helper.parent"))}),
            .callee = f.derive(&leaf, &.{f.set("/name", f.s("fixture.Helper.parent"))}),
            .source = "pub fn parent() void { Helper.parent(); } const Helper = struct { pub fn parent() void {} };",
            .child_declaration = "fn_parent_1",
            .accepted = true,
        },
        .{ .input = nested_caller, .callee = nested_leaf, .filename = "nested/fixture.zig", .accepted = true },
        .{ .input = nested_caller, .callee = nested_leaf, .filename = "nested/fixture.zig", .linked = true },
        .{ .input = nested_caller, .callee = nested_leaf, .filename = "nested/fixture.zig", .source = "pub fn parent() void {} const Decoy = struct { pub fn child() void {} };" },
        .{ .input = nested_caller, .callee = leaf, .filename = "nested/fixture.zig" },
        .{ .accepted = true, .imported = true },
        .{ .extra_root = true },
        .{ .extra_root = true, .imported = true, .accepted = true },
        .{ .input = f.derive(&caller, &.{f.set("/instructions/0/tag", f.s("call_never_inline"))}), .accepted = true },
        .{ .include = false },
        .{ .input = f.derive(&caller, &.{f.set("/instructions/0/callee/identity/sourceSha256", f.repeat('b', 64))}) },
        .{ .input = f.derive(&caller, &.{f.set("/instructions/0/callee/identity/sourceFile", f.s("decoy.zig"))}) },
        .{ .input = f.derive(&caller, &.{f.set("/instructions/0/callee/identity/name", f.s("fixture.parent"))}) },
        .{ .input = f.derive(&caller, &.{f.set("/instructions/0/tag", f.s("call_always_tail"))}) },
        .{ .input = f.derive(&caller, &.{f.set("/instructions/0/arguments", f.arr(&.{f.obj(&.{.{ "kind", f.s("unit") }})}))}) },
        .{ .callee = f.derive(&leaf, &.{f.set("/instructions/0/tag", f.s("unreach"))}) },
        .{ .callee = f.derive(&leaf, &.{f.set("/signature/genericInstance", f.b(true))}) },
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
            .roots = if (case.extra_root) &.{ parent_name, child_name } else &.{parent_name},
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
            try std.testing.expect(std.mem.indexOf(u8, generated, try ctx.fmt("(.call FunctionId.{s} [])", .{case.child_declaration})) != null);
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
            try std.testing.expect(std.mem.indexOf(u8, generated, try ctx.fmt("(.call FunctionId.{s} [])", .{case.child_declaration})) != null);
            try std.testing.expect(std.mem.indexOf(u8, generated, try ctx.fmt("def FunctionId.{s} : Nat := 0", .{case.child_declaration})) != null);
            try std.testing.expect(std.mem.indexOf(u8, generated, "def FunctionId.fn_parent : Nat := 1") != null);
            try std.testing.expect(std.mem.indexOf(u8, generated, " <|\n      (.ret (.local 0))") != null);
            try std.testing.expect(std.mem.indexOf(u8, generated, try ctx.fmt("def functions : Program := [{s}, fn_parent]", .{case.child_declaration})) != null);
            try std.testing.expect(std.mem.indexOf(u8, generated, ".target") == null);
            try std.testing.expectEqualStrings(generated, try ctx.read(std.testing.io, try ctx.fmt("{s}/Generated.lean", .{options.output}), 16384));
        } else {
            try std.testing.expectError(error.InvalidInput, z.translate.run(&ctx, std.testing.io, machine_options));
            try std.testing.expectError(error.FileNotFound, tmp.dir.statFile(std.testing.io, "machine", .{}));
        }
    }
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
        \\def child : Program := {s}
        \\def parent : Program := {s}
        \\def resumable : Program true := {s}
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
    var machine_loop = try z.air.Decoder.initWith(ctx, loop_child, .call_loops, .{ .call_machine = true });
    const block_child = try f.load(ctx.allocator, block_leaf);
    var machine_block = try z.air.Decoder.initWith(ctx, block_child, .calls, .{ .call_machine = true });
    return ctx.fmt(
        \\import Compiler.ZigAir.CapturedCallMachine
        \\import Compiler.ZigAir.CapturedNestedCalls
        \\{s}
        \\def loopChild : Compiler.ZigAir.MemoryCall.Program true := {s}
        \\{s}
        \\def partialCaller : Compiler.ZigAir.MemoryPartialCall.Program := {s}
        \\{s}
        \\example : partialCaller.observe 10 [] {{}} = .finished (.ok (.scalar .unit)) {{}} := rfl
        \\example : partialCaller.observe 0 [] {{}} = .pending {{}} := rfl
        \\example : CapturedNestedCalls.decode 64 [] partialCaller_captured = none := rfl
        \\example : CapturedNestedCalls.decode 64 [loopChild_captured, loopChild_captured] partialCaller_captured = none := rfl
        \\example : CapturedNestedCalls.decode 64 [replaceIdentity loopChild_captured] partialCaller_captured = none := rfl
        \\example : CapturedNestedCalls.decode 0 [loopChild_captured] partialCaller_captured = none := rfl
        \\def machineChild : MemoryCallMachine.Function := {s}
        \\def machineParent : MemoryCallMachine.Function :=
        \\{s}
        \\example : CapturedCallMachine.decode [child_captured, parent_captured] = some [machineChild, machineParent] := rfl
        \\example : CapturedCallMachine.decode [parent_captured, child_captured] = none := rfl
        \\example : CapturedCallMachine.decode [child_captured, child_captured] = none := rfl
        \\example : CapturedCallMachine.decode [replaceIdentity child_captured, parent_captured] = none := rfl
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
    , .{ previous, try z.air.decode(ctx, loop_child, .call_loops), try z.certificate.callDeclaration(ctx, loop_child, "loopChild", true, &.{}), try partial.program(), try z.certificate.nestedDeclaration(ctx, parent, "partialCaller", &targets), child_text, try machine.program(), try machine_loop.program(), try machine_block.program(), try z.certificate.lift(ctx, block_child, 0) });
}
