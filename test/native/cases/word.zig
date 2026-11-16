// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
// Immutable reference controls with shared fixtures and explicit mutations.
const f = @import("../fixtures.zig");
const shared = @import("shared.zig");
const golden = @import("golden.zig");

const fixture_0 = f.obj(&.{
    .{ "record", f.obj(&.{
        .{ "schema", f.s("oksolc.fresh-air.v3") },
        .{ "capturePoint", f.s("after-sema-before-legalize") },
        .{ "name", f.s("mem.swap__anon_1") },
        .{ "sourceFile", f.s("mem.zig") },
        .{ "sourceSha256", f.s("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb") },
        .{ "configuration", f.ref(&shared.hash_caller_hash_initialization_0_bundle_caller_configuration_293) },
        .{ "signature", f.obj(&.{
            .{ "callingConvention", f.obj(&.{
                .{ "auto", f.obj(&.{}) },
            }) },
            .{ "genericInstance", f.b(true) },
            .{ "varArgs", f.b(false) },
            .{ "noaliasBits", f.n("3") },
            .{ "parameters", f.ref(&shared.link_fixture_0_records_mem_swap_anon_1_signature_parameters_565) },
            .{ "returnType", f.obj(&.{
                .{ "kind", f.s("void") },
            }) },
        }) },
        .{ "sourceOperationTags", f.arr(&.{
            f.s("add"),
            f.s("ret_node"),
        }) },
        .{ "sourceValidityConditionsPreserved", f.b(false) },
        .{ "sourceValidity", f.obj(&.{
            .{ "schema", f.s("oksolc.source-validity.v1") },
            .{ "coverage", f.s("runtime-slice-results") },
            .{ "complete", f.b(false) },
            .{ "slices", f.arr(&.{}) },
        }) },
        .{ "bodyTraversal", f.s("supported-structured-containers-only") },
        .{ "body", f.arr(&.{
            f.n("0"),
            f.n("1"),
            f.n("2"),
        }) },
        .{ "instructions", f.ref(&shared.link_fixture_0_records_mem_swap_anon_1_instructions_567) },
        .{ "specialization", f.ref(&shared.link_fixture_0_records_mem_swap_anon_1_specialization_570) },
    }) },
    .{ "sources", f.ref(&shared.link_fixture_0_sources_580) },
    .{ "output", f.ref(&golden.word_fixture_0_output_1124) },
    .{ "reject", f.b(false) },
});

pub const cases = blk: {
    @setEvalBranchQuota(50_000);
    break :blk [_]f.Value{
        // Control 0
        f.ref(&fixture_0),
        // Control 1
        f.derive(&fixture_0, &.{
            f.set("/record/signature/genericInstance", f.b(false)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 2
        f.derive(&fixture_0, &.{
            f.set("/record/signature/noaliasBits", f.n("0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 3
        f.derive(&fixture_0, &.{
            f.remove("/record/signature/callingConvention/auto"),
            f.add("/record/signature/callingConvention/c", f.obj(&.{})),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 4
        f.derive(&fixture_0, &.{
            f.set("/record/specialization/owner/name", f.s("mem.other")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 5
        f.derive(&fixture_0, &.{
            f.set("/record/instructions/0/type/child/bits", f.n("16")),
            f.set("/record/instructions/1/type/child/bits", f.n("16")),
            f.set("/record/specialization/arguments/0/value/bits", f.n("16")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 6
        f.derive(&fixture_0, &.{
            f.set("/record/specialization/sourceNoaliasBits", f.n("0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 7
        f.derive(&fixture_0, &.{
            f.set("/record/specialization/arguments/1/runtimeIndex", f.n("1")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 8
        f.derive(&fixture_0, &.{
            f.set("/record/instructions/0/zirParameterIndex", f.n("0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 9
        f.derive(&fixture_0, &.{
            f.set("/record/signature/parameters/0/flags/isConst", f.b(true)),
            f.set("/record/signature/parameters/1/flags/isConst", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 10
        f.derive(&fixture_0, &.{
            f.set("/record/sourceSha256", f.s("cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 11
        f.derive(&fixture_0, &.{
            f.set("/record/configuration/endianness", f.s("big")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 12
        f.derive(&fixture_0, &.{
            f.set("/record/configuration/pointerBits", f.n("32")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 13
        f.derive(&fixture_0, &.{
            f.set("/record/instructions/2/tag", f.s("unrecognized")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 14
        f.derive(&fixture_0, &.{
            f.set("/record/instructions/2/operand/kind", f.s("instruction")),
            f.add("/record/instructions/2/operand/index", f.n("3")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 15
        f.derive(&fixture_0, &.{
            f.set("/record/instructions/2/payloadVisited", f.b(false)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 16
        f.derive(&fixture_0, &.{
            f.add("/record/body/3", f.n("2")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 17
        f.derive(&fixture_0, &.{
            f.remove("/record/body/1"),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
    };
};
