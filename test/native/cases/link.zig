// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
// Immutable reference controls with shared fixtures and explicit mutations.
const f = @import("../fixtures.zig");
const shared = @import("shared.zig");
const golden = @import("golden.zig");

const fixture_0 = f.obj(&.{
    .{ "records", f.obj(&.{
        .{ "mem.swap__anon_1", f.obj(&.{
            .{ "schema", f.s("oksolc.fresh-air.v3") },
            .{ "capturePoint", f.s("after-sema-before-legalize") },
            .{ "name", f.s("mem.swap__anon_1") },
            .{ "sourceFile", f.s("mem.zig") },
            .{ "sourceSha256", f.s("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb") },
            .{ "configuration", f.obj(&.{
                .{ "optimize", f.s("ReleaseFast") },
                .{ "useLlvm", f.b(true) },
                .{ "isTest", f.b(false) },
            }) },
            .{ "signature", f.obj(&.{
                .{ "callingConvention", f.s("auto") },
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
        .{ "fixture.choose", f.obj(&.{
            .{ "schema", f.s("oksolc.fresh-air.v3") },
            .{ "capturePoint", f.s("after-sema-before-legalize") },
            .{ "name", f.s("fixture.choose") },
            .{ "sourceFile", f.s("fixture.zig") },
            .{ "sourceSha256", f.s("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") },
            .{ "configuration", f.obj(&.{
                .{ "optimize", f.s("ReleaseFast") },
                .{ "useLlvm", f.b(true) },
                .{ "isTest", f.b(false) },
            }) },
            .{ "signature", f.obj(&.{
                .{ "callingConvention", f.s("auto") },
                .{ "genericInstance", f.b(false) },
                .{ "varArgs", f.b(false) },
                .{ "noaliasBits", f.n("0") },
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
                f.n("3"),
            }) },
            .{ "instructions", f.arr(&.{
                f.obj(&.{
                    .{ "index", f.n("0") },
                    .{ "tag", f.s("arg") },
                    .{ "type", f.ref(&shared.pointer_566) },
                    .{ "payloadVisited", f.b(true) },
                    .{ "zirParameterIndex", f.n("0") },
                }),
                f.obj(&.{
                    .{ "index", f.n("1") },
                    .{ "tag", f.s("arg") },
                    .{ "type", f.ref(&shared.pointer_566) },
                    .{ "payloadVisited", f.b(true) },
                    .{ "zirParameterIndex", f.n("1") },
                }),
                f.obj(&.{
                    .{ "index", f.n("2") },
                    .{ "tag", f.s("call") },
                    .{ "type", f.obj(&.{
                        .{ "kind", f.s("void") },
                    }) },
                    .{ "payloadVisited", f.b(true) },
                    .{ "callee", f.obj(&.{
                        .{ "kind", f.s("function") },
                        .{ "identity", f.obj(&.{
                            .{ "name", f.s("mem.swap__anon_1") },
                            .{ "sourceFile", f.s("mem.zig") },
                            .{ "sourceSha256", f.s("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb") },
                        }) },
                    }) },
                    .{ "arguments", f.arr(&.{
                        f.obj(&.{
                            .{ "kind", f.s("instruction") },
                            .{ "index", f.n("0") },
                        }),
                        f.obj(&.{
                            .{ "kind", f.s("instruction") },
                            .{ "index", f.n("1") },
                        }),
                    }) },
                }),
                f.obj(&.{
                    .{ "index", f.n("3") },
                    .{ "tag", f.s("ret") },
                    .{ "type", f.obj(&.{
                        .{ "kind", f.s("noreturn") },
                    }) },
                    .{ "payloadVisited", f.b(true) },
                    .{ "operand", f.obj(&.{
                        .{ "kind", f.s("unit") },
                    }) },
                }),
            }) },
        }) },
    }) },
    .{ "roots", f.arr(&.{
        f.s("fixture.choose"),
    }) },
    .{ "sources", f.ref(&shared.link_fixture_0_sources_580) },
    .{ "output", f.obj(&.{
        .{ "schema", f.s("oksolc.specialization-links.v1") },
        .{ "exportedCallLinksChecked", f.b(true) },
        .{ "bodyCoverageVerified", f.b(false) },
        .{ "argumentDominanceVerified", f.b(false) },
        .{ "specializationSemanticsVerified", f.b(false) },
        .{ "noaliasVerified", f.b(false) },
        .{ "sourceSafetyVerified", f.b(false) },
        .{ "nativeBackendVerified", f.b(false) },
        .{ "wholeCompilerVerified", f.b(false) },
        .{ "roots", f.arr(&.{
            f.s("fixture.choose"),
        }) },
        .{ "sources", f.ref(&shared.link_fixture_0_sources_580) },
        .{ "configuration", f.obj(&.{
            .{ "optimize", f.s("ReleaseFast") },
            .{ "useLlvm", f.b(true) },
            .{ "isTest", f.b(false) },
        }) },
        .{ "functions", f.obj(&.{
            .{ "fixture.choose", f.obj(&.{
                .{ "recordSha256", f.s("a5f457b0e3047ecf311b962b3670ba20909de326307651fe56765bfc3b5a437a") },
                .{ "specializationSha256", .null },
                .{ "runtimeParameterIndices", f.arr(&.{
                    f.n("0"),
                    f.n("1"),
                }) },
                .{ "noaliasBits", f.n("0") },
                .{ "unsupportedBodyInstructions", f.arr(&.{}) },
                .{ "unvisitedInstructions", f.n("0") },
            }) },
            .{ "mem.swap__anon_1", f.obj(&.{
                .{ "recordSha256", f.s("8b0b7175cac8810d1eaee4351a35afe566c1bf8c868a007339e58c0c7b669563") },
                .{ "specializationSha256", f.s("e4e353eda295f692e0210c60bb76a5efed12c52a690d8af753a96f8ef1b812b9") },
                .{ "runtimeParameterIndices", f.arr(&.{
                    f.n("1"),
                    f.n("2"),
                }) },
                .{ "noaliasBits", f.n("3") },
                .{ "unsupportedBodyInstructions", f.arr(&.{}) },
                .{ "unvisitedInstructions", f.n("0") },
            }) },
        }) },
        .{ "edges", f.arr(&.{
            f.obj(&.{
                .{ "caller", f.s("fixture.choose") },
                .{ "instruction", f.n("2") },
                .{ "tag", f.s("call") },
                .{ "callee", f.s("mem.swap__anon_1") },
                .{ "arguments", f.arr(&.{
                    f.obj(&.{
                        .{ "kind", f.s("instruction") },
                        .{ "index", f.n("0") },
                    }),
                    f.obj(&.{
                        .{ "kind", f.s("instruction") },
                        .{ "index", f.n("1") },
                    }),
                }) },
            }),
        }) },
    }) },
    .{ "reject", f.b(false) },
});

pub const cases = blk: {
    @setEvalBranchQuota(50_000);
    break :blk [_]f.Value{
        // Control 0
        f.ref(&fixture_0),
        // Control 1
        f.derive(&fixture_0, &.{
            f.set("/records/mem.swap__anon_1/specialization/arguments/0/value/bits", f.n("8")),
            f.set("/output/functions/mem.swap__anon_1/recordSha256", f.s("34f5928169152540d3e53092eb07b1a3d2b86447f67d3e9f8fefc6ba43b69539")),
            f.set("/output/functions/mem.swap__anon_1/specializationSha256", f.s("788d5398faa6b693cc27b23396bb974574bb88be2fcb495465d9eb1f1920ffb6")),
        }),
        // Control 2
        f.derive(&fixture_0, &.{
            f.remove("/records/mem.swap__anon_1"),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 3
        f.derive(&fixture_0, &.{
            f.set("/records/mem.swap__anon_1/sourceSha256", f.s("cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 4
        f.derive(&fixture_0, &.{
            f.set("/records/fixture.choose/instructions/2/callee/identity/sourceSha256", f.s("cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 5
        f.derive(&fixture_0, &.{
            f.set("/records/mem.swap__anon_1/specialization/owner/sourceFile", f.s("other.zig")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 6
        f.derive(&fixture_0, &.{
            f.set("/records/mem.swap__anon_1/configuration/optimize", f.s("Debug")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 7
        f.derive(&fixture_0, &.{
            f.set("/records/mem.swap__anon_1/capturePoint", f.s("after-legalize")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 8
        f.derive(&fixture_0, &.{
            f.set("/records/fixture.choose/instructions/2/callee/kind", f.s("instruction")),
            f.remove("/records/fixture.choose/instructions/2/callee/identity"),
            f.add("/records/fixture.choose/instructions/2/callee/index", f.n("0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 9
        f.derive(&fixture_0, &.{
            f.remove("/records/fixture.choose/instructions/2/callee/identity/name"),
            f.remove("/records/fixture.choose/instructions/2/callee/identity/sourceFile"),
            f.remove("/records/fixture.choose/instructions/2/callee/identity/sourceSha256"),
            f.add("/records/fixture.choose/instructions/2/callee/identity/kind", f.s("unsupported")),
            f.add("/records/fixture.choose/instructions/2/callee/identity/reason", f.s("coerced-function")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 10
        f.derive(&fixture_0, &.{
            f.set("/records/fixture.choose/instructions/2/payloadVisited", f.n("1")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 11
        f.derive(&fixture_0, &.{
            f.remove("/records/fixture.choose/instructions/2/arguments/1"),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 12
        f.derive(&fixture_0, &.{
            f.set("/records/fixture.choose/instructions/2/arguments/0/kind", f.s("constant")),
            f.remove("/records/fixture.choose/instructions/2/arguments/0/index"),
            f.add("/records/fixture.choose/instructions/2/arguments/0/type", f.obj(&.{
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("unsigned") },
                .{ "bits", f.n("8") },
            })),
            f.add("/records/fixture.choose/instructions/2/arguments/0/value", f.n("0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 13
        f.derive(&fixture_0, &.{
            f.set("/records/fixture.choose/instructions/2/arguments/0/index", f.n("9")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 14
        f.derive(&fixture_0, &.{
            f.set("/records/fixture.choose/instructions/1/payloadVisited", f.b(false)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 15
        f.derive(&fixture_0, &.{
            f.set("/records/fixture.choose/instructions/2/type/kind", f.s("int")),
            f.add("/records/fixture.choose/instructions/2/type/bits", f.n("32")),
            f.add("/records/fixture.choose/instructions/2/type/signedness", f.s("unsigned")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 16
        f.derive(&fixture_0, &.{
            f.add("/records/fixture.choose/instructions/2/unsupportedPayload", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 17
        f.derive(&fixture_0, &.{
            f.remove("/records/mem.swap__anon_1/specialization"),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 18
        f.derive(&fixture_0, &.{
            f.set("/records/mem.swap__anon_1/signature/genericInstance", f.b(false)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 19
        f.derive(&fixture_0, &.{
            f.set("/records/mem.swap__anon_1/signature/noaliasBits", f.n("0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 20
        f.derive(&fixture_0, &.{
            f.set("/records/mem.swap__anon_1/specialization/sourceNoaliasBits", f.n("0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 21
        f.derive(&fixture_0, &.{
            f.set("/records/mem.swap__anon_1/specialization/sourceComptimeBits", f.n("3")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 22
        f.derive(&fixture_0, &.{
            f.set("/records/mem.swap__anon_1/specialization/sourceParameterCount", f.n("2")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 23
        f.derive(&fixture_0, &.{
            f.set("/records/mem.swap__anon_1/specialization/arguments/2/runtimeIndex", f.n("0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 24
        f.derive(&fixture_0, &.{
            f.set("/records/mem.swap__anon_1/specialization/arguments/1/runtimeIndex", f.b(false)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 25
        f.derive(&fixture_0, &.{
            f.set("/records/mem.swap__anon_1/instructions/0/zirParameterIndex", f.n("0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 26
        f.derive(&fixture_0, &.{
            f.set("/records/mem.swap__anon_1/instructions/0/zirParameterIndex", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 27
        f.derive(&fixture_0, &.{
            f.set("/records/mem.swap__anon_1/instructions/2/tag", f.s("future_container")),
            f.remove("/records/mem.swap__anon_1/instructions/2/operand"),
            f.add("/records/mem.swap__anon_1/instructions/2/unsupportedPayload", f.b(true)),
            f.set("/output/functions/mem.swap__anon_1/recordSha256", f.s("0de512fa92edf089d12de2bdf5668507760915656b7f6bf0a71753a7571f3b5a")),
            f.add("/output/functions/mem.swap__anon_1/unsupportedBodyInstructions/0", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "tag", f.s("future_container") },
            })),
        }),
    };
};
