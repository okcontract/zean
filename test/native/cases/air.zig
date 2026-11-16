// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
// Immutable reference controls with shared fixtures and explicit mutations.
const f = @import("../fixtures.zig");
const shared = @import("shared.zig");
const golden = @import("golden.zig");

const scalar_constant_0 = f.obj(&.{
    .{ "input", f.obj(&.{
        .{ "kind", f.s("constant") },
        .{ "type", f.obj(&.{
            .{ "bits", f.n("0") },
            .{ "kind", f.s("int") },
            .{ "signedness", f.s("unsigned") },
        }) },
        .{ "value", f.n("0") },
    }) },
    .{ "kind", f.s("constant") },
    .{ "output", f.s("(.constant (.int false 0 (0)))") },
    .{ "profile", f.s("scalar") },
    .{ "reject", f.b(false) },
});

const scalar_program_1 = f.obj(&.{
    .{ "input", f.ref(&shared.air_scalar_program_1_input_2) },
    .{ "kind", f.s("program") },
    .{ "output", f.ref(&golden.air_scalar_program_1_output_11) },
    .{ "profile", f.s("scalar") },
    .{ "reject", f.b(false) },
});

const memory_program_2 = f.obj(&.{
    .{ "input", f.ref(&shared.air_memory_program_2_input_13) },
    .{ "kind", f.s("program") },
    .{ "output", f.ref(&golden.air_memory_program_2_output_30) },
    .{ "profile", f.s("memory") },
    .{ "reject", f.b(false) },
});

const memory_constant_3 = f.obj(&.{
    .{ "input", f.obj(&.{
        .{ "kind", f.s("constant") },
        .{ "type", f.obj(&.{
            .{ "bits", f.n("64") },
            .{ "kind", f.s("int") },
            .{ "signedness", f.s("unsigned") },
        }) },
        .{ "value", f.n("0") },
    }) },
    .{ "kind", f.s("constant") },
    .{ "output", f.s("(.constant (.scalar (.int false 64 (0))))") },
    .{ "profile", f.s("memory") },
    .{ "reject", f.b(false) },
});

const aggregate_program_4 = f.obj(&.{
    .{ "input", f.ref(&shared.air_aggregate_program_4_input_33) },
    .{ "kind", f.s("program") },
    .{ "output", f.ref(&golden.air_aggregate_program_4_output_50) },
    .{ "profile", f.s("aggregate") },
    .{ "reject", f.b(false) },
});

const aggregate_constant_5 = f.obj(&.{
    .{ "input", f.obj(&.{
        .{ "kind", f.s("undefined") },
        .{ "type", f.obj(&.{
            .{ "bits", f.n("64") },
            .{ "kind", f.s("int") },
            .{ "signedness", f.s("unsigned") },
        }) },
    }) },
    .{ "kind", f.s("constant") },
    .{ "profile", f.s("aggregate") },
    .{ "reject", f.b(true) },
});

const word_bytes_program_6 = f.obj(&.{
    .{ "input", f.obj(&.{
        .{ "body", f.arr(&.{
            f.n("0"),
            f.n("1"),
            f.n("2"),
            f.n("3"),
            f.n("4"),
            f.n("5"),
            f.n("6"),
            f.n("7"),
            f.n("8"),
            f.n("9"),
            f.n("10"),
            f.n("11"),
        }) },
        .{ "bodyTraversal", f.s("supported-structured-containers-only") },
        .{ "capturePoint", f.s("after-sema-before-legalize") },
        .{ "configuration", f.ref(&shared.air_memory_program_2_input_configuration_14) },
        .{ "instructions", f.arr(&.{
            f.ref(&shared.air_word_bytes_program_6_input_instructions_55),
            f.ref(&shared.air_memory_program_2_input_instructions_19),
            f.ref(&shared.air_word_bytes_program_6_input_instructions_57),
            f.ref(&shared.air_word_bytes_program_6_input_instructions_58),
            f.ref(&shared.air_word_bytes_program_6_input_instructions_61),
            f.ref(&shared.air_word_bytes_program_6_input_instructions_64),
            f.ref(&shared.air_word_bytes_program_6_input_instructions_66),
            f.ref(&shared.air_word_bytes_program_6_input_instructions_67),
            f.ref(&shared.air_word_bytes_program_6_input_instructions_70),
            f.ref(&shared.air_word_bytes_program_6_input_instructions_71),
            f.obj(&.{
                .{ "index", f.n("10") },
                .{ "operand", f.obj(&.{
                    .{ "index", f.n("9") },
                    .{ "kind", f.s("instruction") },
                }) },
                .{ "payloadVisited", f.b(true) },
                .{ "tag", f.s("load") },
                .{ "type", f.obj(&.{
                    .{ "bits", f.n("8") },
                    .{ "kind", f.s("int") },
                    .{ "signedness", f.s("unsigned") },
                }) },
            }),
            f.obj(&.{
                .{ "index", f.n("11") },
                .{ "operand", f.obj(&.{
                    .{ "kind", f.s("unit") },
                }) },
                .{ "payloadVisited", f.b(true) },
                .{ "tag", f.s("ret") },
                .{ "type", f.obj(&.{
                    .{ "kind", f.s("noreturn") },
                }) },
            }),
        }) },
        .{ "name", f.s("fixture.choose") },
        .{ "schema", f.s("oksolc.fresh-air.v3") },
        .{ "signature", f.ref(&shared.air_word_bytes_program_6_input_signature_75) },
        .{ "sourceFile", f.s("fixture.zig") },
        .{ "sourceOperationTags", f.arr(&.{
            f.s("add"),
            f.s("ret_node"),
        }) },
        .{ "sourceSha256", f.s("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") },
        .{ "sourceValidity", f.obj(&.{
            .{ "complete", f.b(false) },
            .{ "coverage", f.s("runtime-slice-results") },
            .{ "schema", f.s("oksolc.source-validity.v1") },
            .{ "slices", f.arr(&.{}) },
        }) },
        .{ "sourceValidityConditionsPreserved", f.b(false) },
    }) },
    .{ "kind", f.s("program") },
    .{ "output", f.ref(&golden.air_word_bytes_program_6_output_77) },
    .{ "profile", f.s("word-bytes") },
    .{ "reject", f.b(false) },
});

const loops_program_7 = f.obj(&.{
    .{ "input", f.ref(&shared.air_loops_program_7_input_79) },
    .{ "kind", f.s("program") },
    .{ "output", f.ref(&golden.air_loops_program_7_output_85) },
    .{ "profile", f.s("loops") },
    .{ "reject", f.b(false) },
});

const word_byte_loops_program_8 = f.obj(&.{
    .{ "input", f.ref(&shared.air_word_byte_loops_program_8_input_87) },
    .{ "kind", f.s("program") },
    .{ "output", f.ref(&golden.air_word_byte_loops_program_8_output_88) },
    .{ "profile", f.s("word-byte-loops") },
    .{ "reject", f.b(false) },
});

const scalar_constant_9 = f.obj(&.{
    .{ "input", f.obj(&.{
        .{ "kind", f.s("constant") },
        .{ "type", f.obj(&.{
            .{ "bits", f.n("512") },
            .{ "kind", f.s("int") },
            .{ "signedness", f.s("unsigned") },
        }) },
        .{ "value", f.n("13407807929942597099574024998205846127479365820592393377723561443721764030073546976801874298166903427690031858186486050853753882811946569946433649006084095") },
    }) },
    .{ "kind", f.s("constant") },
    .{ "output", f.ref(&golden.air_scalar_constant_9_output_91) },
    .{ "profile", f.s("scalar") },
    .{ "reject", f.b(false) },
});

const scalar_constant_10 = f.obj(&.{
    .{ "input", f.obj(&.{
        .{ "kind", f.s("constant") },
        .{ "type", f.obj(&.{
            .{ "bits", f.n("256") },
            .{ "kind", f.s("int") },
            .{ "signedness", f.s("signed") },
        }) },
        .{ "value", f.n("-57896044618658097711785492504343953926634992332820282019728792003956564819968") },
    }) },
    .{ "kind", f.s("constant") },
    .{ "output", f.s("(.constant (.int true 256 (-57896044618658097711785492504343953926634992332820282019728792003956564819968)))") },
    .{ "profile", f.s("scalar") },
    .{ "reject", f.b(false) },
});

const scalar_constant_11 = f.obj(&.{
    .{ "input", f.obj(&.{
        .{ "kind", f.s("constant") },
        .{ "type", f.obj(&.{
            .{ "bits", f.n("512") },
            .{ "kind", f.s("int") },
            .{ "signedness", f.s("signed") },
        }) },
        .{ "value", f.n("-6703903964971298549787012499102923063739682910296196688861780721860882015036773488400937149083451713845015929093243025426876941405973284973216824503042048") },
    }) },
    .{ "kind", f.s("constant") },
    .{ "output", f.ref(&golden.air_scalar_constant_11_output_96) },
    .{ "profile", f.s("scalar") },
    .{ "reject", f.b(false) },
});

const scalar_program_12 = f.obj(&.{
    .{ "input", f.ref(&shared.air_scalar_program_12_input_98) },
    .{ "kind", f.s("program") },
    .{ "output", f.ref(&golden.air_scalar_program_12_output_103) },
    .{ "profile", f.s("scalar") },
    .{ "reject", f.b(false) },
});

const scalar_program_13 = f.obj(&.{
    .{ "input", f.obj(&.{
        .{ "body", f.arr(&.{
            f.n("0"),
            f.n("1"),
            f.n("2"),
        }) },
        .{ "bodyTraversal", f.s("supported-structured-containers-only") },
        .{ "capturePoint", f.s("after-sema-before-legalize") },
        .{ "configuration", f.obj(&.{
            .{ "isTest", f.b(false) },
            .{ "optimize", f.s("ReleaseFast") },
            .{ "useLlvm", f.b(true) },
        }) },
        .{ "instructions", f.arr(&.{
            f.obj(&.{
                .{ "index", f.n("0") },
                .{ "payloadVisited", f.b(true) },
                .{ "tag", f.s("arg") },
                .{ "type", f.obj(&.{
                    .{ "bits", f.n("1") },
                    .{ "kind", f.s("int") },
                    .{ "signedness", f.s("unsigned") },
                }) },
                .{ "zirParameterIndex", f.n("0") },
            }),
            f.obj(&.{
                .{ "index", f.n("1") },
                .{ "lhs", f.obj(&.{
                    .{ "index", f.n("0") },
                    .{ "kind", f.s("instruction") },
                }) },
                .{ "payloadVisited", f.b(true) },
                .{ "rhs", f.obj(&.{
                    .{ "kind", f.s("constant") },
                    .{ "type", f.obj(&.{
                        .{ "bits", f.n("0") },
                        .{ "kind", f.s("int") },
                        .{ "signedness", f.s("unsigned") },
                    }) },
                    .{ "value", f.n("0") },
                }) },
                .{ "tag", f.s("shr") },
                .{ "type", f.obj(&.{
                    .{ "bits", f.n("1") },
                    .{ "kind", f.s("int") },
                    .{ "signedness", f.s("unsigned") },
                }) },
            }),
            f.obj(&.{
                .{ "index", f.n("2") },
                .{ "operand", f.obj(&.{
                    .{ "kind", f.s("constant") },
                    .{ "type", f.obj(&.{
                        .{ "bits", f.n("1") },
                        .{ "kind", f.s("int") },
                        .{ "signedness", f.s("unsigned") },
                    }) },
                    .{ "value", f.n("0") },
                }) },
                .{ "payloadVisited", f.b(true) },
                .{ "tag", f.s("ret") },
                .{ "type", f.obj(&.{
                    .{ "kind", f.s("noreturn") },
                }) },
            }),
        }) },
        .{ "name", f.s("fixture.choose") },
        .{ "schema", f.s("oksolc.fresh-air.v3") },
        .{ "signature", f.obj(&.{
            .{ "callingConvention", f.s("auto") },
            .{ "genericInstance", f.b(false) },
            .{ "noaliasBits", f.n("0") },
            .{ "parameters", f.arr(&.{
                f.obj(&.{
                    .{ "bits", f.n("1") },
                    .{ "kind", f.s("int") },
                    .{ "signedness", f.s("unsigned") },
                }),
            }) },
            .{ "returnType", f.obj(&.{
                .{ "bits", f.n("1") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("unsigned") },
            }) },
            .{ "varArgs", f.b(false) },
        }) },
        .{ "sourceFile", f.s("fixture.zig") },
        .{ "sourceOperationTags", f.arr(&.{
            f.s("add"),
            f.s("ret_node"),
        }) },
        .{ "sourceSha256", f.s("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") },
        .{ "sourceValidity", f.obj(&.{
            .{ "complete", f.b(false) },
            .{ "coverage", f.s("runtime-slice-results") },
            .{ "schema", f.s("oksolc.source-validity.v1") },
            .{ "slices", f.arr(&.{}) },
        }) },
        .{ "sourceValidityConditionsPreserved", f.b(false) },
    }) },
    .{ "kind", f.s("program") },
    .{ "output", f.ref(&golden.air_scalar_program_13_output_111) },
    .{ "profile", f.s("scalar") },
    .{ "reject", f.b(false) },
});

const scalar_program_14 = f.obj(&.{
    .{ "input", f.obj(&.{
        .{ "body", f.arr(&.{
            f.n("0"),
            f.n("1"),
            f.n("2"),
        }) },
        .{ "bodyTraversal", f.s("supported-structured-containers-only") },
        .{ "capturePoint", f.s("after-sema-before-legalize") },
        .{ "configuration", f.obj(&.{
            .{ "isTest", f.b(false) },
            .{ "optimize", f.s("ReleaseFast") },
            .{ "useLlvm", f.b(true) },
        }) },
        .{ "instructions", f.arr(&.{
            f.obj(&.{
                .{ "index", f.n("0") },
                .{ "payloadVisited", f.b(true) },
                .{ "tag", f.s("arg") },
                .{ "type", f.obj(&.{
                    .{ "bits", f.n("256") },
                    .{ "kind", f.s("int") },
                    .{ "signedness", f.s("unsigned") },
                }) },
                .{ "zirParameterIndex", f.n("0") },
            }),
            f.obj(&.{
                .{ "index", f.n("1") },
                .{ "lhs", f.obj(&.{
                    .{ "kind", f.s("constant") },
                    .{ "type", f.obj(&.{
                        .{ "bits", f.n("256") },
                        .{ "kind", f.s("int") },
                        .{ "signedness", f.s("signed") },
                    }) },
                    .{ "value", f.n("1") },
                }) },
                .{ "payloadVisited", f.b(true) },
                .{ "rhs", f.obj(&.{
                    .{ "kind", f.s("constant") },
                    .{ "type", f.obj(&.{
                        .{ "bits", f.n("8") },
                        .{ "kind", f.s("int") },
                        .{ "signedness", f.s("unsigned") },
                    }) },
                    .{ "value", f.n("1") },
                }) },
                .{ "tag", f.s("shr") },
                .{ "type", f.obj(&.{
                    .{ "bits", f.n("256") },
                    .{ "kind", f.s("int") },
                    .{ "signedness", f.s("unsigned") },
                }) },
            }),
            f.obj(&.{
                .{ "index", f.n("2") },
                .{ "operand", f.obj(&.{
                    .{ "index", f.n("1") },
                    .{ "kind", f.s("instruction") },
                }) },
                .{ "payloadVisited", f.b(true) },
                .{ "tag", f.s("ret") },
                .{ "type", f.obj(&.{
                    .{ "kind", f.s("noreturn") },
                }) },
            }),
        }) },
        .{ "name", f.s("fixture.choose") },
        .{ "schema", f.s("oksolc.fresh-air.v3") },
        .{ "signature", f.obj(&.{
            .{ "callingConvention", f.s("auto") },
            .{ "genericInstance", f.b(false) },
            .{ "noaliasBits", f.n("0") },
            .{ "parameters", f.arr(&.{
                f.obj(&.{
                    .{ "bits", f.n("256") },
                    .{ "kind", f.s("int") },
                    .{ "signedness", f.s("unsigned") },
                }),
            }) },
            .{ "returnType", f.obj(&.{
                .{ "bits", f.n("256") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("unsigned") },
            }) },
            .{ "varArgs", f.b(false) },
        }) },
        .{ "sourceFile", f.s("fixture.zig") },
        .{ "sourceOperationTags", f.arr(&.{
            f.s("add"),
            f.s("ret_node"),
        }) },
        .{ "sourceSha256", f.s("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") },
        .{ "sourceValidity", f.obj(&.{
            .{ "complete", f.b(false) },
            .{ "coverage", f.s("runtime-slice-results") },
            .{ "schema", f.s("oksolc.source-validity.v1") },
            .{ "slices", f.arr(&.{}) },
        }) },
        .{ "sourceValidityConditionsPreserved", f.b(false) },
    }) },
    .{ "kind", f.s("program") },
    .{ "profile", f.s("scalar") },
    .{ "reject", f.b(true) },
});

const memory_program_15 = f.obj(&.{
    .{ "input", f.ref(&shared.air_word_byte_loops_program_8_input_87) },
    .{ "kind", f.s("program") },
    .{ "output", f.ref(&golden.air_word_byte_loops_program_8_output_88) },
    .{ "profile", f.s("memory") },
    .{ "reject", f.b(false) },
});

const memory_program_16 = f.obj(&.{
    .{ "input", f.ref(&shared.air_memory_program_16_input_120) },
    .{ "kind", f.s("program") },
    .{ "profile", f.s("memory") },
    .{ "reject", f.b(true) },
});

const memory_program_17 = f.obj(&.{
    .{ "input", f.ref(&shared.air_memory_program_17_input_128) },
    .{ "kind", f.s("program") },
    .{ "profile", f.s("memory") },
    .{ "reject", f.b(true) },
});

const memory_program_18 = f.obj(&.{
    .{ "input", f.ref(&shared.air_aggregate_program_4_input_33) },
    .{ "kind", f.s("program") },
    .{ "profile", f.s("memory") },
    .{ "reject", f.b(true) },
});

const memory_program_19 = f.obj(&.{
    .{ "input", f.obj(&.{
        .{ "body", f.arr(&.{
            f.n("0"),
            f.n("1"),
            f.n("2"),
            f.n("3"),
            f.n("4"),
            f.n("5"),
            f.n("6"),
            f.n("7"),
            f.n("8"),
            f.n("9"),
            f.n("10"),
            f.n("11"),
        }) },
        .{ "bodyTraversal", f.s("supported-structured-containers-only") },
        .{ "capturePoint", f.s("after-sema-before-legalize") },
        .{ "configuration", f.ref(&shared.air_memory_program_2_input_configuration_14) },
        .{ "instructions", f.arr(&.{
            f.ref(&shared.air_word_bytes_program_6_input_instructions_55),
            f.ref(&shared.air_memory_program_2_input_instructions_19),
            f.ref(&shared.air_word_bytes_program_6_input_instructions_57),
            f.ref(&shared.air_word_bytes_program_6_input_instructions_58),
            f.ref(&shared.air_word_bytes_program_6_input_instructions_61),
            f.ref(&shared.air_word_bytes_program_6_input_instructions_64),
            f.ref(&shared.air_word_bytes_program_6_input_instructions_66),
            f.ref(&shared.air_word_bytes_program_6_input_instructions_67),
            f.ref(&shared.air_word_bytes_program_6_input_instructions_70),
            f.ref(&shared.air_word_bytes_program_6_input_instructions_71),
            f.ref(&shared.air_memory_program_19_input_instructions_135),
            f.obj(&.{
                .{ "index", f.n("11") },
                .{ "operand", f.obj(&.{
                    .{ "kind", f.s("unit") },
                }) },
                .{ "payloadVisited", f.b(true) },
                .{ "tag", f.s("ret") },
                .{ "type", f.obj(&.{
                    .{ "kind", f.s("noreturn") },
                }) },
            }),
        }) },
        .{ "name", f.s("fixture.choose") },
        .{ "schema", f.s("oksolc.fresh-air.v3") },
        .{ "signature", f.ref(&shared.air_word_bytes_program_6_input_signature_75) },
        .{ "sourceFile", f.s("fixture.zig") },
        .{ "sourceOperationTags", f.arr(&.{
            f.s("add"),
            f.s("ret_node"),
        }) },
        .{ "sourceSha256", f.s("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") },
        .{ "sourceValidity", f.obj(&.{
            .{ "complete", f.b(false) },
            .{ "coverage", f.s("runtime-slice-results") },
            .{ "schema", f.s("oksolc.source-validity.v1") },
            .{ "slices", f.arr(&.{}) },
        }) },
        .{ "sourceValidityConditionsPreserved", f.b(false) },
    }) },
    .{ "kind", f.s("program") },
    .{ "profile", f.s("memory") },
    .{ "reject", f.b(true) },
});

const memory_program_20 = f.obj(&.{
    .{ "input", f.ref(&shared.air_loops_program_7_input_79) },
    .{ "kind", f.s("program") },
    .{ "profile", f.s("memory") },
    .{ "reject", f.b(true) },
});

const loops_program_21 = f.obj(&.{
    .{ "input", f.obj(&.{
        .{ "body", f.arr(&.{
            f.n("0"),
            f.n("1"),
            f.n("2"),
            f.n("3"),
        }) },
        .{ "bodyTraversal", f.s("supported-structured-containers-only") },
        .{ "capturePoint", f.s("after-sema-before-legalize") },
        .{ "configuration", f.ref(&shared.air_memory_program_2_input_configuration_14) },
        .{ "instructions", f.arr(&.{
            f.ref(&shared.air_memory_program_2_input_instructions_16),
            f.ref(&shared.air_memory_program_2_input_instructions_19),
            f.obj(&.{
                .{ "index", f.n("2") },
                .{ "lhs", f.obj(&.{
                    .{ "index", f.n("0") },
                    .{ "kind", f.s("instruction") },
                }) },
                .{ "payloadVisited", f.b(true) },
                .{ "rhs", f.obj(&.{
                    .{ "index", f.n("1") },
                    .{ "kind", f.s("instruction") },
                }) },
                .{ "tag", f.s("ptr_elem_ptr") },
                .{ "type", f.ref(&shared.pointer_124) },
            }),
            f.ref(&shared.air_memory_program_2_input_instructions_23),
        }) },
        .{ "name", f.s("fixture.choose") },
        .{ "schema", f.s("oksolc.fresh-air.v3") },
        .{ "signature", f.ref(&shared.air_memory_program_2_input_signature_24) },
        .{ "sourceFile", f.s("fixture.zig") },
        .{ "sourceOperationTags", f.arr(&.{
            f.s("add"),
            f.s("ret_node"),
        }) },
        .{ "sourceSha256", f.s("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") },
        .{ "sourceValidity", f.obj(&.{
            .{ "complete", f.b(false) },
            .{ "coverage", f.s("runtime-slice-results") },
            .{ "schema", f.s("oksolc.source-validity.v1") },
            .{ "slices", f.arr(&.{}) },
        }) },
        .{ "sourceValidityConditionsPreserved", f.b(false) },
    }) },
    .{ "kind", f.s("program") },
    .{ "output", f.ref(&golden.air_loops_program_21_output_141) },
    .{ "profile", f.s("loops") },
    .{ "reject", f.b(false) },
});

const loops_program_22 = f.obj(&.{
    .{ "input", f.ref(&shared.air_loops_program_22_input_143) },
    .{ "kind", f.s("program") },
    .{ "output", f.ref(&golden.air_loops_program_22_output_146) },
    .{ "profile", f.s("loops") },
    .{ "reject", f.b(false) },
});

const memory_program_23 = f.obj(&.{
    .{ "input", f.ref(&shared.air_memory_program_23_input_148) },
    .{ "kind", f.s("program") },
    .{ "profile", f.s("memory") },
    .{ "reject", f.b(true) },
});

const word_byte_loops_program_24 = f.obj(&.{
    .{ "input", f.obj(&.{
        .{ "body", f.arr(&.{
            f.n("0"),
            f.n("1"),
            f.n("2"),
        }) },
        .{ "bodyTraversal", f.s("supported-structured-containers-only") },
        .{ "capturePoint", f.s("after-sema-before-legalize") },
        .{ "configuration", f.ref(&shared.air_memory_program_2_input_configuration_14) },
        .{ "instructions", f.ref(&shared.air_memory_program_23_input_instructions_149) },
        .{ "name", f.s("mem.swap__anon_1") },
        .{ "schema", f.s("oksolc.fresh-air.v3") },
        .{ "signature", f.obj(&.{
            .{ "callingConvention", f.obj(&.{
                .{ "auto", f.obj(&.{}) },
            }) },
            .{ "genericInstance", f.b(true) },
            .{ "noaliasBits", f.n("3") },
            .{ "parameters", f.ref(&shared.air_memory_program_23_input_signature_parameters_153) },
            .{ "returnType", f.obj(&.{
                .{ "kind", f.s("void") },
            }) },
            .{ "varArgs", f.b(false) },
        }) },
        .{ "sourceFile", f.s("mem.zig") },
        .{ "sourceOperationTags", f.arr(&.{
            f.s("add"),
            f.s("ret_node"),
        }) },
        .{ "sourceSha256", f.s("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb") },
        .{ "sourceValidity", f.obj(&.{
            .{ "complete", f.b(false) },
            .{ "coverage", f.s("runtime-slice-results") },
            .{ "schema", f.s("oksolc.source-validity.v1") },
            .{ "slices", f.arr(&.{}) },
        }) },
        .{ "sourceValidityConditionsPreserved", f.b(false) },
        .{ "specialization", f.ref(&shared.air_memory_program_23_input_specialization_154) },
    }) },
    .{ "kind", f.s("program") },
    .{ "profile", f.s("word-byte-loops") },
    .{ "reject", f.b(true) },
});

const loops_program_25 = f.obj(&.{
    .{ "input", f.ref(&shared.air_word_byte_loops_program_8_input_87) },
    .{ "kind", f.s("program") },
    .{ "output", f.ref(&golden.air_word_byte_loops_program_8_output_88) },
    .{ "profile", f.s("loops") },
    .{ "reject", f.b(false) },
});

const aggregate_program_26 = f.obj(&.{
    .{ "input", f.ref(&shared.air_word_byte_loops_program_8_input_87) },
    .{ "kind", f.s("program") },
    .{ "output", f.ref(&golden.air_aggregate_program_26_output_162) },
    .{ "profile", f.s("aggregate") },
    .{ "reject", f.b(false) },
});

const word_bytes_program_27 = f.obj(&.{
    .{ "input", f.ref(&shared.air_word_byte_loops_program_8_input_87) },
    .{ "kind", f.s("program") },
    .{ "output", f.ref(&golden.air_word_byte_loops_program_8_output_88) },
    .{ "profile", f.s("word-bytes") },
    .{ "reject", f.b(false) },
});

pub const cases = blk: {
    @setEvalBranchQuota(50_000);
    break :blk [_]f.Value{
        // Control 0
        f.ref(&scalar_constant_0),
        // Control 1
        f.derive(&scalar_constant_0, &.{
            f.set("/input/value", f.n("-1")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 2
        f.derive(&scalar_constant_0, &.{
            f.set("/input/value", f.n("1")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 3
        f.derive(&scalar_constant_0, &.{
            f.set("/input/value", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 4
        f.derive(&scalar_constant_0, &.{
            f.set("/input/value", f.n("0.0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 5
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("1")),
            f.set("/output", f.s("(.constant (.int false 1 (0)))")),
        }),
        // Control 6
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("1")),
            f.set("/input/value", f.n("1")),
            f.set("/output", f.s("(.constant (.int false 1 (1)))")),
        }),
        // Control 7
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("1")),
            f.set("/input/value", f.n("-1")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 8
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("1")),
            f.set("/input/value", f.n("2")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 9
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("1")),
            f.set("/input/value", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 10
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("1")),
            f.set("/input/value", f.n("0.0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 11
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("8")),
            f.set("/output", f.s("(.constant (.int false 8 (0)))")),
        }),
        // Control 12
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("8")),
            f.set("/input/value", f.n("255")),
            f.set("/output", f.s("(.constant (.int false 8 (255)))")),
        }),
        // Control 13
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("8")),
            f.set("/input/value", f.n("-1")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 14
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("8")),
            f.set("/input/value", f.n("256")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 15
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("8")),
            f.set("/input/value", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 16
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("8")),
            f.set("/input/value", f.n("0.0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 17
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("256")),
            f.set("/output", f.s("(.constant (.int false 256 (0)))")),
        }),
        // Control 18
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("256")),
            f.set("/input/value", f.n("115792089237316195423570985008687907853269984665640564039457584007913129639935")),
            f.set("/output", f.s("(.constant (.int false 256 (115792089237316195423570985008687907853269984665640564039457584007913129639935)))")),
        }),
        // Control 19
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("256")),
            f.set("/input/value", f.n("-1")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 20
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("256")),
            f.set("/input/value", f.n("115792089237316195423570985008687907853269984665640564039457584007913129639936")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 21
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("256")),
            f.set("/input/value", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 22
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("256")),
            f.set("/input/value", f.n("0.0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 23
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("512")),
            f.set("/output", f.s("(.constant (.int false 512 (0)))")),
        }),
        // Control 24
        f.ref(&scalar_constant_9),
        // Control 25
        f.derive(&scalar_constant_9, &.{
            f.set("/input/value", f.n("-1")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 26
        f.derive(&scalar_constant_9, &.{
            f.set("/input/value", f.n("13407807929942597099574024998205846127479365820592393377723561443721764030073546976801874298166903427690031858186486050853753882811946569946433649006084096")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 27
        f.derive(&scalar_constant_9, &.{
            f.set("/input/value", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 28
        f.derive(&scalar_constant_9, &.{
            f.set("/input/value", f.n("0.0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 29
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/signedness", f.s("signed")),
            f.set("/output", f.s("(.constant (.int true 0 (0)))")),
        }),
        // Control 30
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/signedness", f.s("signed")),
            f.set("/input/value", f.n("-1")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 31
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/signedness", f.s("signed")),
            f.set("/input/value", f.n("1")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 32
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/signedness", f.s("signed")),
            f.set("/input/value", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 33
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/signedness", f.s("signed")),
            f.set("/input/value", f.n("0.0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 34
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("1")),
            f.set("/input/type/signedness", f.s("signed")),
            f.set("/input/value", f.n("-1")),
            f.set("/output", f.s("(.constant (.int true 1 (-1)))")),
        }),
        // Control 35
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("1")),
            f.set("/input/type/signedness", f.s("signed")),
            f.set("/output", f.s("(.constant (.int true 1 (0)))")),
        }),
        // Control 36
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("1")),
            f.set("/input/type/signedness", f.s("signed")),
            f.set("/input/value", f.n("-2")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 37
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("1")),
            f.set("/input/type/signedness", f.s("signed")),
            f.set("/input/value", f.n("1")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 38
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("1")),
            f.set("/input/type/signedness", f.s("signed")),
            f.set("/input/value", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 39
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("1")),
            f.set("/input/type/signedness", f.s("signed")),
            f.set("/input/value", f.n("0.0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 40
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("8")),
            f.set("/input/type/signedness", f.s("signed")),
            f.set("/input/value", f.n("-128")),
            f.set("/output", f.s("(.constant (.int true 8 (-128)))")),
        }),
        // Control 41
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("8")),
            f.set("/input/type/signedness", f.s("signed")),
            f.set("/input/value", f.n("127")),
            f.set("/output", f.s("(.constant (.int true 8 (127)))")),
        }),
        // Control 42
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("8")),
            f.set("/input/type/signedness", f.s("signed")),
            f.set("/input/value", f.n("-129")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 43
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("8")),
            f.set("/input/type/signedness", f.s("signed")),
            f.set("/input/value", f.n("128")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 44
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("8")),
            f.set("/input/type/signedness", f.s("signed")),
            f.set("/input/value", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 45
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("8")),
            f.set("/input/type/signedness", f.s("signed")),
            f.set("/input/value", f.n("0.0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 46
        f.ref(&scalar_constant_10),
        // Control 47
        f.derive(&scalar_constant_10, &.{
            f.set("/input/value", f.n("57896044618658097711785492504343953926634992332820282019728792003956564819967")),
            f.set("/output", f.s("(.constant (.int true 256 (57896044618658097711785492504343953926634992332820282019728792003956564819967)))")),
        }),
        // Control 48
        f.derive(&scalar_constant_10, &.{
            f.set("/input/value", f.n("-57896044618658097711785492504343953926634992332820282019728792003956564819969")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 49
        f.derive(&scalar_constant_10, &.{
            f.set("/input/value", f.n("57896044618658097711785492504343953926634992332820282019728792003956564819968")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 50
        f.derive(&scalar_constant_10, &.{
            f.set("/input/value", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 51
        f.derive(&scalar_constant_10, &.{
            f.set("/input/value", f.n("0.0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 52
        f.ref(&scalar_constant_11),
        // Control 53
        f.derive(&scalar_constant_11, &.{
            f.set("/input/value", f.n("6703903964971298549787012499102923063739682910296196688861780721860882015036773488400937149083451713845015929093243025426876941405973284973216824503042047")),
            f.text("/output", &.{
                .{ .at = 27, .old = "-", .new = "" },
                .{ .at = 181, .old = "8", .new = "7" },
            }),
        }),
        // Control 54
        f.derive(&scalar_constant_11, &.{
            f.set("/input/value", f.n("-6703903964971298549787012499102923063739682910296196688861780721860882015036773488400937149083451713845015929093243025426876941405973284973216824503042049")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 55
        f.derive(&scalar_constant_11, &.{
            f.set("/input/value", f.n("6703903964971298549787012499102923063739682910296196688861780721860882015036773488400937149083451713845015929093243025426876941405973284973216824503042048")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 56
        f.derive(&scalar_constant_11, &.{
            f.set("/input/value", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 57
        f.derive(&scalar_constant_11, &.{
            f.set("/input/value", f.n("0.0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 58
        f.ref(&scalar_program_1),
        // Control 59
        f.derive(&scalar_program_1, &.{
            f.set("/input/instructions/4/tag", f.s("sub")),
            f.text("/output", &.{
                .{ .at = 286, .old = "add", .new = "sub" },
            }),
        }),
        // Control 60
        f.derive(&scalar_program_1, &.{
            f.set("/input/instructions/4/tag", f.s("add_safe")),
            f.text("/output", &.{
                .{ .at = 291, .old = "un", .new = "" },
            }),
        }),
        // Control 61
        f.derive(&scalar_program_1, &.{
            f.set("/input/instructions/4/tag", f.s("add_wrap")),
            f.text("/output", &.{
                .{ .at = 291, .old = "unchecked", .new = "wrapping" },
            }),
        }),
        // Control 62
        f.derive(&scalar_program_1, &.{
            f.add("/input/body/3", f.n("7")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 63
        f.derive(&scalar_program_1, &.{
            f.add("/input/body/1", f.n("0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 64
        f.derive(&scalar_program_1, &.{
            f.remove("/input/body/2"),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 65
        f.derive(&scalar_program_1, &.{
            f.remove("/input/body/2"),
            f.remove("/input/body/1"),
            f.remove("/input/body/0"),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 66
        f.derive(&scalar_program_1, &.{
            f.remove("/input/body/2"),
            f.remove("/input/body/1"),
            f.remove("/input/body/0"),
            f.add("/input/body/0", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 67
        f.derive(&scalar_program_1, &.{
            f.remove("/input/body/2"),
            f.remove("/input/body/1"),
            f.remove("/input/body/0"),
            f.add("/input/body/0", f.n("8")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 68
        f.derive(&scalar_program_1, &.{
            f.remove("/input/instructions/3/elseBody/0"),
            f.add("/input/instructions/3/elseBody/0", f.n("4")),
            f.add("/input/instructions/3/elseBody/1", f.n("5")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 69
        f.derive(&scalar_program_1, &.{
            f.set("/input/instructions/5/operand/index", f.n("0")),
            f.text("/output", &.{
                .{ .at = 363, .old = "4", .new = "0" },
            }),
        }),
        // Control 70
        f.derive(&scalar_program_1, &.{
            f.set("/input/instructions/4/lhs/index", f.n("4")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 71
        f.derive(&scalar_program_1, &.{
            f.set("/input/instructions/6/operand/index", f.n("4")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 72
        f.derive(&scalar_program_1, &.{
            f.set("/input/instructions/7/operand/index", f.n("2")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 73
        f.derive(&scalar_program_1, &.{
            f.set("/input/instructions/5/target", f.n("0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 74
        f.derive(&scalar_program_1, &.{
            f.set("/input/instructions/5/target", f.n("5")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 75
        f.derive(&scalar_program_1, &.{
            f.set("/input/instructions/5/target", f.n("7")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 76
        f.derive(&scalar_program_1, &.{
            f.set("/input/instructions/5/target", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 77
        f.derive(&scalar_program_1, &.{
            f.set("/input/instructions/5/target", f.n("-1")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 78
        f.derive(&scalar_program_1, &.{
            f.set("/input/instructions/5/target", f.n("8")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 79
        f.derive(&scalar_program_1, &.{
            f.set("/input/name", f.s("numeric.u2s")),
        }),
        // Control 80
        f.derive(&scalar_program_1, &.{
            f.set("/input/name", f.s("numeric.s2u")),
        }),
        // Control 81
        f.derive(&scalar_program_1, &.{
            f.remove("/input/instructions/4/type/bits"),
            f.set("/input/instructions/4/type/kind", f.s("void")),
            f.remove("/input/instructions/4/type/signedness"),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 82
        f.derive(&scalar_program_1, &.{
            f.remove("/input/instructions/5/operand/index"),
            f.set("/input/instructions/5/operand/kind", f.s("unit")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 83
        f.derive(&scalar_program_1, &.{
            f.set("/input/instructions/3/condition/index", f.n("0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 84
        f.derive(&scalar_program_1, &.{
            f.remove("/input/instructions/7/operand/index"),
            f.set("/input/instructions/7/operand/kind", f.s("unit")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 85
        f.derive(&scalar_program_1, &.{
            f.remove("/input/signature/parameters/0/bits"),
            f.set("/input/signature/parameters/0/kind", f.s("void")),
            f.remove("/input/signature/parameters/0/signedness"),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 86
        f.derive(&scalar_program_1, &.{
            f.set("/input/signature/noaliasBits", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 87
        f.derive(&scalar_program_1, &.{
            f.set("/input/signature/varArgs", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 88
        f.derive(&scalar_program_1, &.{
            f.set("/input/signature/genericInstance", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 89
        f.derive(&scalar_program_1, &.{
            f.set("/input/instructions/0/zirParameterIndex", f.n("1")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 90
        f.derive(&scalar_program_1, &.{
            f.set("/input/instructions/4/tag", f.s("future")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 91
        f.derive(&scalar_program_1, &.{
            f.set("/input/instructions/4/tag", f.s("load")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 92
        f.derive(&scalar_program_1, &.{
            f.set("/input/instructions/4/tag", f.s("store")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 93
        f.derive(&scalar_program_1, &.{
            f.set("/input/instructions/4/tag", f.s("alloc")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 94
        f.derive(&scalar_program_1, &.{
            f.set("/input/instructions/4/tag", f.s("call")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 95
        f.derive(&scalar_program_1, &.{
            f.set("/input/instructions/4/tag", f.s("loop")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 96
        f.derive(&scalar_program_1, &.{
            f.set("/input/instructions/4/tag", f.s("repeat")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 97
        f.derive(&scalar_program_1, &.{
            f.set("/input/instructions/4/tag", f.s("unreach")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 98
        f.derive(&scalar_program_1, &.{
            f.add("/input/instructions/4/extra", f.n("0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 99
        f.derive(&scalar_program_1, &.{
            f.set("/input/instructions/4/payloadVisited", f.b(false)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 100
        f.derive(&scalar_program_1, &.{
            f.set("/input/sourceValidityConditionsPreserved", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 101
        f.derive(&scalar_program_1, &.{
            f.set("/input/configuration/optimize", f.s("Debug")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 102
        f.derive(&scalar_program_1, &.{
            f.add("/input/sourceValidity/slices/0", f.obj(&.{
                .{ "anchor", f.s("dead-result") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 103
        f.derive(&scalar_program_1, &.{
            f.set("/input/sourceValidity/complete", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 104
        f.derive(&scalar_program_1, &.{
            f.set("/input/sourceValidity/complete", f.n("0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 105
        f.derive(&scalar_program_1, &.{
            f.set("/input/schema", f.s("oksolc.fresh-air.v1")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 106
        f.derive(&scalar_program_1, &.{
            f.add("/input/instructions/8", f.obj(&.{
                .{ "index", f.n("8") },
                .{ "payloadVisited", f.b(false) },
                .{ "reason", f.s("outside-decoded-body-closure") },
                .{ "tag", f.s("block") },
                .{ "unsupportedPayload", f.b(true) },
            })),
        }),
        // Control 107
        f.derive(&scalar_program_1, &.{
            f.add("/input/instructions/8", f.ref(&shared.air_input_instructions_8_164)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 108
        f.derive(&scalar_program_1, &.{
            f.add("/input/body/1", f.n("8")),
            f.add("/input/instructions/8", f.obj(&.{
                .{ "index", f.n("8") },
                .{ "payloadVisited", f.b(false) },
                .{ "reason", f.s("outside-decoded-body-closure") },
                .{ "tag", f.s("block") },
                .{ "unsupportedPayload", f.b(true) },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 109
        f.ref(&scalar_program_12),
        // Control 110
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("1")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("1")),
            f.set("/input/instructions/1/type/bits", f.n("1")),
            f.set("/input/signature/parameters/0/bits", f.n("1")),
            f.set("/input/signature/returnType/bits", f.n("1")),
            f.set("/output", f.s(
                \\{ parameters := [(.int false 1)], returnType := (.int false 1), body :=
                \\  (.bind 0 (.int false 1)
                \\  (.argument 0)
                \\  (.bind 1 (.int false 1)
                \\  (.bitAnd (.local 0) (.constant (.int false 1 (0))))
                \\  (.ret (.local 1)))) }
            )),
        }),
        // Control 111
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("8")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("8")),
            f.set("/input/instructions/1/type/bits", f.n("8")),
            f.set("/input/signature/parameters/0/bits", f.n("8")),
            f.set("/input/signature/returnType/bits", f.n("8")),
            f.set("/output", f.s(
                \\{ parameters := [(.int false 8)], returnType := (.int false 8), body :=
                \\  (.bind 0 (.int false 8)
                \\  (.argument 0)
                \\  (.bind 1 (.int false 8)
                \\  (.bitAnd (.local 0) (.constant (.int false 8 (0))))
                \\  (.ret (.local 1)))) }
            )),
        }),
        // Control 112
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("64")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("64")),
            f.set("/input/instructions/1/type/bits", f.n("64")),
            f.set("/input/signature/parameters/0/bits", f.n("64")),
            f.set("/input/signature/returnType/bits", f.n("64")),
            f.set("/output", f.s(
                \\{ parameters := [(.int false 64)], returnType := (.int false 64), body :=
                \\  (.bind 0 (.int false 64)
                \\  (.argument 0)
                \\  (.bind 1 (.int false 64)
                \\  (.bitAnd (.local 0) (.constant (.int false 64 (0))))
                \\  (.ret (.local 1)))) }
            )),
        }),
        // Control 113
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("256")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
            f.set("/output", f.s(
                \\{ parameters := [(.int false 256)], returnType := (.int false 256), body :=
                \\  (.bind 0 (.int false 256)
                \\  (.argument 0)
                \\  (.bind 1 (.int false 256)
                \\  (.bitAnd (.local 0) (.constant (.int false 256 (0))))
                \\  (.ret (.local 1)))) }
            )),
        }),
        // Control 114
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("512")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("512")),
            f.set("/input/instructions/1/type/bits", f.n("512")),
            f.set("/input/signature/parameters/0/bits", f.n("512")),
            f.set("/input/signature/returnType/bits", f.n("512")),
            f.set("/output", f.s(
                \\{ parameters := [(.int false 512)], returnType := (.int false 512), body :=
                \\  (.bind 0 (.int false 512)
                \\  (.argument 0)
                \\  (.bind 1 (.int false 512)
                \\  (.bitAnd (.local 0) (.constant (.int false 512 (0))))
                \\  (.ret (.local 1)))) }
            )),
        }),
        // Control 115
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("8")),
            f.set("/input/instructions/1/rhs/value", f.n("1")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 116
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/lhs/index", f.n("1")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/value", f.n("1")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 117
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.remove("/input/instructions/1/lhs"),
            f.set("/input/instructions/1/rhs/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/value", f.n("1")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 118
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/kind", f.s("instruction")),
            f.remove("/input/instructions/1/rhs/type"),
            f.remove("/input/instructions/1/rhs/value"),
            f.add("/input/instructions/1/rhs/index", f.n("1")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 119
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.remove("/input/instructions/1/rhs"),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 120
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/lhs/index", f.n("1")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/value", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 121
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.remove("/input/instructions/1/lhs"),
            f.set("/input/instructions/1/rhs/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/value", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 122
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/kind", f.s("instruction")),
            f.remove("/input/instructions/1/rhs/type"),
            f.remove("/input/instructions/1/rhs/value"),
            f.add("/input/instructions/1/rhs/index", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 123
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.remove("/input/instructions/1/rhs"),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 124
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/lhs/index", f.n("1")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("8")),
            f.set("/input/instructions/1/rhs/value", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 125
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.remove("/input/instructions/1/lhs"),
            f.set("/input/instructions/1/rhs/type/bits", f.n("8")),
            f.set("/input/instructions/1/rhs/value", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 126
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/kind", f.s("instruction")),
            f.remove("/input/instructions/1/rhs/type"),
            f.remove("/input/instructions/1/rhs/value"),
            f.add("/input/instructions/1/rhs/index", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 127
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.remove("/input/instructions/1/rhs"),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 128
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("1")),
            f.set("/input/signature/parameters/0/bits", f.n("1")),
            f.set("/input/signature/returnType/bits", f.n("1")),
            f.set("/output", f.s(
                \\{ parameters := [(.int false 1)], returnType := (.int false 1), body :=
                \\  (.bind 0 (.int false 1)
                \\  (.argument 0)
                \\  (.bind 1 (.int false 1)
                \\  (.shiftRight (.local 0) (.constant (.int false 0 (0))))
                \\  (.ret (.local 1)))) }
            )),
        }),
        // Control 129
        f.ref(&scalar_program_13),
        // Control 130
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("3")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("2")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("3")),
            f.set("/input/signature/parameters/0/bits", f.n("3")),
            f.set("/input/signature/returnType/bits", f.n("3")),
            f.set("/output", f.s(
                \\{ parameters := [(.int false 3)], returnType := (.int false 3), body :=
                \\  (.bind 0 (.int false 3)
                \\  (.argument 0)
                \\  (.bind 1 (.int false 3)
                \\  (.shiftRight (.local 0) (.constant (.int false 2 (0))))
                \\  (.ret (.local 1)))) }
            )),
        }),
        // Control 131
        f.derive(&scalar_program_13, &.{
            f.set("/input/instructions/0/type/bits", f.n("3")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("2")),
            f.set("/input/instructions/1/type/bits", f.n("3")),
            f.set("/input/instructions/2/operand/type/bits", f.n("3")),
            f.set("/input/signature/parameters/0/bits", f.n("3")),
            f.set("/input/signature/returnType/bits", f.n("3")),
            f.set("/output", f.s(
                \\{ parameters := [(.int false 3)], returnType := (.int false 3), body :=
                \\  (.bind 0 (.int false 3)
                \\  (.argument 0)
                \\  (.bind 1 (.int false 3)
                \\  (.shiftRight (.local 0) (.constant (.int false 2 (0))))
                \\  (.ret (.constant (.int false 3 (0)))))) }
            )),
        }),
        // Control 132
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("8")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("3")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("8")),
            f.set("/input/signature/parameters/0/bits", f.n("8")),
            f.set("/input/signature/returnType/bits", f.n("8")),
            f.set("/output", f.s(
                \\{ parameters := [(.int false 8)], returnType := (.int false 8), body :=
                \\  (.bind 0 (.int false 8)
                \\  (.argument 0)
                \\  (.bind 1 (.int false 8)
                \\  (.shiftRight (.local 0) (.constant (.int false 3 (0))))
                \\  (.ret (.local 1)))) }
            )),
        }),
        // Control 133
        f.derive(&scalar_program_13, &.{
            f.set("/input/instructions/0/type/bits", f.n("8")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("3")),
            f.set("/input/instructions/1/type/bits", f.n("8")),
            f.set("/input/instructions/2/operand/type/bits", f.n("8")),
            f.set("/input/signature/parameters/0/bits", f.n("8")),
            f.set("/input/signature/returnType/bits", f.n("8")),
            f.set("/output", f.s(
                \\{ parameters := [(.int false 8)], returnType := (.int false 8), body :=
                \\  (.bind 0 (.int false 8)
                \\  (.argument 0)
                \\  (.bind 1 (.int false 8)
                \\  (.shiftRight (.local 0) (.constant (.int false 3 (0))))
                \\  (.ret (.constant (.int false 8 (0)))))) }
            )),
        }),
        // Control 134
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("64")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("6")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("64")),
            f.set("/input/signature/parameters/0/bits", f.n("64")),
            f.set("/input/signature/returnType/bits", f.n("64")),
            f.set("/output", f.s(
                \\{ parameters := [(.int false 64)], returnType := (.int false 64), body :=
                \\  (.bind 0 (.int false 64)
                \\  (.argument 0)
                \\  (.bind 1 (.int false 64)
                \\  (.shiftRight (.local 0) (.constant (.int false 6 (0))))
                \\  (.ret (.local 1)))) }
            )),
        }),
        // Control 135
        f.derive(&scalar_program_13, &.{
            f.set("/input/instructions/0/type/bits", f.n("64")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("6")),
            f.set("/input/instructions/1/type/bits", f.n("64")),
            f.set("/input/instructions/2/operand/type/bits", f.n("64")),
            f.set("/input/signature/parameters/0/bits", f.n("64")),
            f.set("/input/signature/returnType/bits", f.n("64")),
            f.set("/output", f.s(
                \\{ parameters := [(.int false 64)], returnType := (.int false 64), body :=
                \\  (.bind 0 (.int false 64)
                \\  (.argument 0)
                \\  (.bind 1 (.int false 64)
                \\  (.shiftRight (.local 0) (.constant (.int false 6 (0))))
                \\  (.ret (.constant (.int false 64 (0)))))) }
            )),
        }),
        // Control 136
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("8")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
            f.set("/output", f.s(
                \\{ parameters := [(.int false 256)], returnType := (.int false 256), body :=
                \\  (.bind 0 (.int false 256)
                \\  (.argument 0)
                \\  (.bind 1 (.int false 256)
                \\  (.shiftRight (.local 0) (.constant (.int false 8 (0))))
                \\  (.ret (.local 1)))) }
            )),
        }),
        // Control 137
        f.derive(&scalar_program_13, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("8")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/instructions/2/operand/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
            f.set("/output", f.s(
                \\{ parameters := [(.int false 256)], returnType := (.int false 256), body :=
                \\  (.bind 0 (.int false 256)
                \\  (.argument 0)
                \\  (.bind 1 (.int false 256)
                \\  (.shiftRight (.local 0) (.constant (.int false 8 (0))))
                \\  (.ret (.constant (.int false 256 (0)))))) }
            )),
        }),
        // Control 138
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("512")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("9")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("512")),
            f.set("/input/signature/parameters/0/bits", f.n("512")),
            f.set("/input/signature/returnType/bits", f.n("512")),
            f.set("/output", f.s(
                \\{ parameters := [(.int false 512)], returnType := (.int false 512), body :=
                \\  (.bind 0 (.int false 512)
                \\  (.argument 0)
                \\  (.bind 1 (.int false 512)
                \\  (.shiftRight (.local 0) (.constant (.int false 9 (0))))
                \\  (.ret (.local 1)))) }
            )),
        }),
        // Control 139
        f.derive(&scalar_program_13, &.{
            f.set("/input/instructions/0/type/bits", f.n("512")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("9")),
            f.set("/input/instructions/1/type/bits", f.n("512")),
            f.set("/input/instructions/2/operand/type/bits", f.n("512")),
            f.set("/input/signature/parameters/0/bits", f.n("512")),
            f.set("/input/signature/returnType/bits", f.n("512")),
            f.set("/output", f.s(
                \\{ parameters := [(.int false 512)], returnType := (.int false 512), body :=
                \\  (.bind 0 (.int false 512)
                \\  (.argument 0)
                \\  (.bind 1 (.int false 512)
                \\  (.shiftRight (.local 0) (.constant (.int false 9 (0))))
                \\  (.ret (.constant (.int false 512 (0)))))) }
            )),
        }),
        // Control 140
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("3")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("2")),
            f.set("/input/instructions/1/rhs/value", f.n("3")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("3")),
            f.set("/input/signature/parameters/0/bits", f.n("3")),
            f.set("/input/signature/returnType/bits", f.n("3")),
            f.set("/output", f.s(
                \\{ parameters := [(.int false 3)], returnType := (.int false 3), body :=
                \\  (.bind 0 (.int false 3)
                \\  (.argument 0)
                \\  (.bind 1 (.int false 3)
                \\  (.shiftRight (.local 0) (.constant (.int false 2 (3))))
                \\  (.ret (.local 1)))) }
            )),
        }),
        // Control 141
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 142
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("256")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 143
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("8")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("8")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("8")),
            f.set("/input/signature/parameters/0/bits", f.n("8")),
            f.set("/input/signature/returnType/bits", f.n("8")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 144
        f.derive(&scalar_program_13, &.{
            f.set("/input/instructions/1/rhs/type/bits", f.n("1")),
            f.set("/input/instructions/2/operand/kind", f.s("instruction")),
            f.remove("/input/instructions/2/operand/type"),
            f.remove("/input/instructions/2/operand/value"),
            f.add("/input/instructions/2/operand/index", f.n("1")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 145
        f.ref(&scalar_program_14),
        // Control 146
        f.derive(&scalar_program_14, &.{
            f.set("/input/instructions/1/lhs/kind", f.s("instruction")),
            f.remove("/input/instructions/1/lhs/type"),
            f.remove("/input/instructions/1/lhs/value"),
            f.add("/input/instructions/1/lhs/index", f.n("0")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/type/signedness", f.s("signed")),
        }),
        // Control 147
        f.derive(&scalar_program_14, &.{
            f.set("/input/instructions/1/rhs/type/bits", f.n("256")),
            f.set("/input/instructions/1/tag", f.s("bit_and")),
        }),
        // Control 148
        f.derive(&scalar_program_14, &.{
            f.set("/input/instructions/1/lhs/kind", f.s("instruction")),
            f.remove("/input/instructions/1/lhs/type"),
            f.remove("/input/instructions/1/lhs/value"),
            f.add("/input/instructions/1/lhs/index", f.n("0")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/type/signedness", f.s("signed")),
            f.set("/input/instructions/1/tag", f.s("bit_and")),
        }),
        // Control 149
        f.derive(&scalar_program_14, &.{
            f.set("/input/instructions/1/rhs/type/bits", f.n("256")),
            f.set("/input/instructions/1/tag", f.s("xor")),
        }),
        // Control 150
        f.derive(&scalar_program_14, &.{
            f.set("/input/instructions/1/lhs/kind", f.s("instruction")),
            f.remove("/input/instructions/1/lhs/type"),
            f.remove("/input/instructions/1/lhs/value"),
            f.add("/input/instructions/1/lhs/index", f.n("0")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/type/signedness", f.s("signed")),
            f.set("/input/instructions/1/tag", f.s("xor")),
        }),
        // Control 151
        f.derive(&scalar_program_14, &.{
            f.set("/input/instructions/1/lhs/kind", f.s("instruction")),
            f.remove("/input/instructions/1/lhs/type"),
            f.remove("/input/instructions/1/lhs/value"),
            f.add("/input/instructions/1/lhs/index", f.n("0")),
            f.set("/input/instructions/1/tag", f.s("shr_exact")),
        }),
        // Control 152
        f.derive(&scalar_program_14, &.{
            f.set("/input/instructions/1/lhs/kind", f.s("instruction")),
            f.remove("/input/instructions/1/lhs/type"),
            f.remove("/input/instructions/1/lhs/value"),
            f.add("/input/instructions/1/lhs/index", f.n("0")),
            f.set("/input/instructions/1/tag", f.s("shl")),
        }),
        // Control 153
        f.derive(&scalar_program_14, &.{
            f.set("/input/instructions/1/lhs/kind", f.s("instruction")),
            f.remove("/input/instructions/1/lhs/type"),
            f.remove("/input/instructions/1/lhs/value"),
            f.add("/input/instructions/1/lhs/index", f.n("0")),
            f.set("/input/instructions/1/tag", f.s("bit_or")),
        }),
        // Control 154
        f.derive(&scalar_program_14, &.{
            f.set("/input/instructions/1/lhs/kind", f.s("instruction")),
            f.remove("/input/instructions/1/lhs/type"),
            f.remove("/input/instructions/1/lhs/value"),
            f.add("/input/instructions/1/lhs/index", f.n("0")),
            f.remove("/input/instructions/1/rhs/type/bits"),
            f.set("/input/instructions/1/rhs/type/kind", f.s("vector")),
            f.remove("/input/instructions/1/rhs/type/signedness"),
        }),
        // Control 155
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.text("/output", &.{
                .{ .at = 147, .old = "And", .new = "Xor" },
            }),
        }),
        // Control 156
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.remove("/input/instructions/2/operand/index"),
            f.set("/input/instructions/2/operand/kind", f.s("constant")),
            f.add("/input/instructions/2/operand/type", f.obj(&.{
                .{ "bits", f.n("0") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("unsigned") },
            })),
            f.add("/input/instructions/2/operand/value", f.n("0")),
            f.text("/output", &.{
                .{ .at = 147, .old = "And (.local 0) (.constant (.int false 0 (0))))\n  (.ret (.local 1", .new = "Xor (.local 0) (.constant (.int false 0 (0))))\n  (.ret (.constant (.int false 0 (0))" },
            }),
        }),
        // Control 157
        f.derive(&scalar_program_13, &.{
            f.set("/input/instructions/1/rhs/type/bits", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/2/operand/kind", f.s("instruction")),
            f.remove("/input/instructions/2/operand/type"),
            f.remove("/input/instructions/2/operand/value"),
            f.add("/input/instructions/2/operand/index", f.n("1")),
            f.text("/output", &.{
                .{ .at = 144, .old = "shiftRight (.local 0) (.constant (.int false 0 (0))))\n  (.ret (.constant (.int false 1 (0))", .new = "bitXor (.local 0) (.constant (.int false 1 (0))))\n  (.ret (.local 1" },
            }),
        }),
        // Control 158
        f.derive(&scalar_program_13, &.{
            f.set("/input/instructions/1/rhs/type/bits", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.text("/output", &.{
                .{ .at = 144, .old = "shiftRight (.local 0) (.constant (.int false 0", .new = "bitXor (.local 0) (.constant (.int false 1" },
            }),
        }),
        // Control 159
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("8")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("8")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("8")),
            f.set("/input/signature/parameters/0/bits", f.n("8")),
            f.set("/input/signature/returnType/bits", f.n("8")),
            f.set("/output", f.s(
                \\{ parameters := [(.int false 8)], returnType := (.int false 8), body :=
                \\  (.bind 0 (.int false 8)
                \\  (.argument 0)
                \\  (.bind 1 (.int false 8)
                \\  (.bitXor (.local 0) (.constant (.int false 8 (0))))
                \\  (.ret (.local 1)))) }
            )),
        }),
        // Control 160
        f.derive(&scalar_program_13, &.{
            f.set("/input/instructions/0/type/bits", f.n("8")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("8")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("8")),
            f.set("/input/instructions/2/operand/type/bits", f.n("8")),
            f.set("/input/signature/parameters/0/bits", f.n("8")),
            f.set("/input/signature/returnType/bits", f.n("8")),
            f.set("/output", f.s(
                \\{ parameters := [(.int false 8)], returnType := (.int false 8), body :=
                \\  (.bind 0 (.int false 8)
                \\  (.argument 0)
                \\  (.bind 1 (.int false 8)
                \\  (.bitXor (.local 0) (.constant (.int false 8 (0))))
                \\  (.ret (.constant (.int false 8 (0)))))) }
            )),
        }),
        // Control 161
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("64")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("64")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("64")),
            f.set("/input/signature/parameters/0/bits", f.n("64")),
            f.set("/input/signature/returnType/bits", f.n("64")),
            f.set("/output", f.s(
                \\{ parameters := [(.int false 64)], returnType := (.int false 64), body :=
                \\  (.bind 0 (.int false 64)
                \\  (.argument 0)
                \\  (.bind 1 (.int false 64)
                \\  (.bitXor (.local 0) (.constant (.int false 64 (0))))
                \\  (.ret (.local 1)))) }
            )),
        }),
        // Control 162
        f.derive(&scalar_program_13, &.{
            f.set("/input/instructions/0/type/bits", f.n("64")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("64")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("64")),
            f.set("/input/instructions/2/operand/type/bits", f.n("64")),
            f.set("/input/signature/parameters/0/bits", f.n("64")),
            f.set("/input/signature/returnType/bits", f.n("64")),
            f.set("/output", f.s(
                \\{ parameters := [(.int false 64)], returnType := (.int false 64), body :=
                \\  (.bind 0 (.int false 64)
                \\  (.argument 0)
                \\  (.bind 1 (.int false 64)
                \\  (.bitXor (.local 0) (.constant (.int false 64 (0))))
                \\  (.ret (.constant (.int false 64 (0)))))) }
            )),
        }),
        // Control 163
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("128")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("128")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("128")),
            f.set("/input/signature/parameters/0/bits", f.n("128")),
            f.set("/input/signature/returnType/bits", f.n("128")),
            f.set("/output", f.s(
                \\{ parameters := [(.int false 128)], returnType := (.int false 128), body :=
                \\  (.bind 0 (.int false 128)
                \\  (.argument 0)
                \\  (.bind 1 (.int false 128)
                \\  (.bitXor (.local 0) (.constant (.int false 128 (0))))
                \\  (.ret (.local 1)))) }
            )),
        }),
        // Control 164
        f.derive(&scalar_program_13, &.{
            f.set("/input/instructions/0/type/bits", f.n("128")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("128")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("128")),
            f.set("/input/instructions/2/operand/type/bits", f.n("128")),
            f.set("/input/signature/parameters/0/bits", f.n("128")),
            f.set("/input/signature/returnType/bits", f.n("128")),
            f.set("/output", f.s(
                \\{ parameters := [(.int false 128)], returnType := (.int false 128), body :=
                \\  (.bind 0 (.int false 128)
                \\  (.argument 0)
                \\  (.bind 1 (.int false 128)
                \\  (.bitXor (.local 0) (.constant (.int false 128 (0))))
                \\  (.ret (.constant (.int false 128 (0)))))) }
            )),
        }),
        // Control 165
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("256")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
            f.set("/output", f.s(
                \\{ parameters := [(.int false 256)], returnType := (.int false 256), body :=
                \\  (.bind 0 (.int false 256)
                \\  (.argument 0)
                \\  (.bind 1 (.int false 256)
                \\  (.bitXor (.local 0) (.constant (.int false 256 (0))))
                \\  (.ret (.local 1)))) }
            )),
        }),
        // Control 166
        f.derive(&scalar_program_13, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("256")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/instructions/2/operand/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
            f.set("/output", f.s(
                \\{ parameters := [(.int false 256)], returnType := (.int false 256), body :=
                \\  (.bind 0 (.int false 256)
                \\  (.argument 0)
                \\  (.bind 1 (.int false 256)
                \\  (.bitXor (.local 0) (.constant (.int false 256 (0))))
                \\  (.ret (.constant (.int false 256 (0)))))) }
            )),
        }),
        // Control 167
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("512")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("512")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("512")),
            f.set("/input/signature/parameters/0/bits", f.n("512")),
            f.set("/input/signature/returnType/bits", f.n("512")),
            f.set("/output", f.s(
                \\{ parameters := [(.int false 512)], returnType := (.int false 512), body :=
                \\  (.bind 0 (.int false 512)
                \\  (.argument 0)
                \\  (.bind 1 (.int false 512)
                \\  (.bitXor (.local 0) (.constant (.int false 512 (0))))
                \\  (.ret (.local 1)))) }
            )),
        }),
        // Control 168
        f.derive(&scalar_program_13, &.{
            f.set("/input/instructions/0/type/bits", f.n("512")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("512")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("512")),
            f.set("/input/instructions/2/operand/type/bits", f.n("512")),
            f.set("/input/signature/parameters/0/bits", f.n("512")),
            f.set("/input/signature/returnType/bits", f.n("512")),
            f.set("/output", f.s(
                \\{ parameters := [(.int false 512)], returnType := (.int false 512), body :=
                \\  (.bind 0 (.int false 512)
                \\  (.argument 0)
                \\  (.bind 1 (.int false 512)
                \\  (.bitXor (.local 0) (.constant (.int false 512 (0))))
                \\  (.ret (.constant (.int false 512 (0)))))) }
            )),
        }),
        // Control 169
        f.derive(&scalar_program_12, &.{
            f.set("/input/instructions/0/type/bits", f.n("64")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("32")),
            f.set("/input/instructions/1/rhs/value", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("64")),
            f.set("/input/signature/parameters/0/bits", f.n("64")),
            f.set("/input/signature/returnType/bits", f.n("64")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 170
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("64")),
            f.set("/output", f.s("(.constant (.int false 64 (0)))")),
        }),
        // Control 171
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("64")),
            f.set("/input/value", f.n("1")),
            f.set("/output", f.s("(.constant (.int false 64 (1)))")),
        }),
        // Control 172
        f.ref(&memory_program_2),
        // Control 173
        f.derive(&memory_program_2, &.{
            f.set("/input/sourceValidity/slices/0/source/sha256", f.s("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 174
        f.derive(&memory_program_2, &.{
            f.set("/input/sourceValidity/slices/0/anchor/index", f.n("3")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 175
        f.derive(&memory_program_2, &.{
            f.set("/input/sourceValidity/slices/0/anchor/index", f.n("20")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 176
        f.derive(&memory_program_2, &.{
            f.set("/input/sourceValidity/slices/0/end/index", f.n("2")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 177
        f.derive(&memory_program_2, &.{
            f.set("/input/sourceValidity/slices/0/anchor/inSupportedBody", f.b(false)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 178
        f.derive(&memory_program_2, &.{
            f.add("/input/sourceValidity/slices/1", f.ref(&shared.air_memory_program_2_input_sourcevalidity_slices_28)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 179
        f.derive(&memory_program_2, &.{
            f.set("/input/sourceValidity/slices/0/upperBound/kind", f.s("sliceLength")),
            f.remove("/input/sourceValidity/slices/0/upperBound/requiresMemoryValidity"),
            f.add("/input/sourceValidity/slices/0/upperBound/original", f.obj(&.{
                .{ "index", f.n("0") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 180
        f.derive(&memory_program_2, &.{
            f.set("/input/sourceValidity/slices/0/upperBound/requiresMemoryValidity", f.n("1")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 181
        f.derive(&memory_program_2, &.{
            f.set("/input/sourceValidity/slices/0/unsupportedReason", f.s("sentinel")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 182
        f.derive(&memory_program_2, &.{
            f.set("/input/sourceValidity/slices/0/upperBound", f.arr(&.{})),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 183
        f.derive(&memory_program_2, &.{
            f.add("/input/sourceOperationTags/2", f.s("slice_length")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 184
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("8")),
            f.set("/input/value", f.n("128")),
            f.set("/output", f.s("(.constant (.int false 8 (128)))")),
        }),
        // Control 185
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("8")),
            f.set("/input/value", f.n("1")),
            f.set("/output", f.s("(.constant (.int false 8 (1)))")),
        }),
        // Control 186
        f.ref(&memory_program_15),
        // Control 187
        f.derive(&memory_program_15, &.{
            f.set("/input/instructions/4/rhs/kind", f.s("instruction")),
            f.remove("/input/instructions/4/rhs/type"),
            f.remove("/input/instructions/4/rhs/value"),
            f.add("/input/instructions/4/rhs/index", f.n("4")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 188
        f.ref(&memory_program_16),
        // Control 189
        f.derive(&memory_program_16, &.{
            f.set("/input/instructions/2/lhs/index", f.n("0")),
            f.set("/input/instructions/2/rhs/index", f.n("0")),
        }),
        // Control 190
        f.derive(&memory_program_16, &.{
            f.set("/input/instructions/2/lhs/index", f.n("0")),
            f.set("/input/instructions/2/rhs/index", f.n("2")),
        }),
        // Control 191
        f.derive(&memory_program_16, &.{
            f.remove("/input/instructions/2/lhs"),
        }),
        // Control 192
        f.derive(&memory_program_16, &.{
            f.set("/input/instructions/2/lhs/index", f.n("0")),
            f.add("/input/instructions/2/unexpected", f.b(true)),
        }),
        // Control 193
        f.derive(&memory_program_16, &.{
            f.set("/input/instructions/2/lhs/index", f.n("0")),
            f.set("/input/instructions/2/payloadVisited", f.b(false)),
        }),
        // Control 194
        f.derive(&memory_program_16, &.{
            f.set("/input/instructions/2/lhs/index", f.n("0")),
            f.set("/input/instructions/2/type/flags/isConst", f.b(false)),
            f.set("/input/signature/returnType/flags/isConst", f.b(false)),
        }),
        // Control 195
        f.derive(&memory_program_16, &.{
            f.set("/input/instructions/2/lhs/index", f.n("0")),
            f.set("/input/instructions/2/type/flags/size", f.s("many")),
            f.set("/input/signature/returnType/flags/size", f.s("many")),
        }),
        // Control 196
        f.derive(&memory_program_16, &.{
            f.set("/input/instructions/2/lhs/index", f.n("0")),
            f.set("/input/instructions/2/type/child/bits", f.n("64")),
            f.set("/input/instructions/2/type/pointeeLayout/alignment", f.n("8")),
            f.set("/input/instructions/2/type/pointeeLayout/bytes", f.n("8")),
        }),
        // Control 197
        f.derive(&memory_program_16, &.{
            f.set("/input/instructions/2/lhs/index", f.n("0")),
            f.set("/reject", f.b(false)),
            f.add("/output", f.s(
                \\{ parameters := [(.slice false (.scalar (.int false 8))), (.scalar (.int false 64))], returnType := (.pointer false false (.scalar (.int false 8))), body :=
                \\  (.bind 0 (.slice false (.scalar (.int false 8)))
                \\  (.argument 0)
                \\  (.bind 1 (.scalar (.int false 64))
                \\  (.argument 1)
                \\  (.bind 2 (.pointer false false (.scalar (.int false 8)))
                \\  (.sliceElementPointer (.local 0) (.local 1))
                \\  (.ret (.local 2))))) }
            )),
        }),
        // Control 198
        f.derive(&memory_program_2, &.{
            f.set("/input/configuration/pointerBits", f.n("32")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 199
        f.derive(&memory_program_2, &.{
            f.set("/input/configuration/endianness", f.s("big")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 200
        f.derive(&memory_program_2, &.{
            f.set("/input/configuration/arch", f.s("x86_64")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 201
        f.derive(&memory_program_2, &.{
            f.set("/input/configuration/os", f.s("linux")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 202
        f.ref(&memory_program_17),
        // Control 203
        f.derive(&memory_program_2, &.{
            f.set("/input/instructions/2/rhs/index", f.n("0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 204
        f.derive(&memory_program_2, &.{
            f.set("/input/instructions/3/tag", f.s("ret_load")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 205
        f.ref(&memory_constant_3),
        // Control 206
        f.ref(&aggregate_program_4),
        // Control 207
        f.ref(&memory_program_18),
        // Control 208
        f.derive(&aggregate_program_4, &.{
            f.set("/input/instructions/3/fieldIndex", f.n("0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 209
        f.derive(&aggregate_program_4, &.{
            f.set("/input/instructions/3/operand/index", f.n("3")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 210
        f.derive(&aggregate_program_4, &.{
            f.set("/input/instructions/3/type/flags/isConst", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 211
        f.derive(&aggregate_program_4, &.{
            f.set("/input/instructions/3/operand/index", f.n("0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 212
        f.derive(&aggregate_program_4, &.{
            f.set("/input/instructions/4/tag", f.s("memcpy")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 213
        f.derive(&aggregate_program_4, &.{
            f.add("/input/sourceValidity/slices/0", f.obj(&.{})),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 214
        f.derive(&aggregate_program_4, &.{
            f.remove("/input/body/4"),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 215
        f.derive(&aggregate_program_4, &.{
            f.add("/input/sourceOperationTags/2", f.s("slice_length")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 216
        f.derive(&aggregate_program_4, &.{
            f.remove("/input/instructions/2/rhs/fields/1"),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 217
        f.derive(&aggregate_program_4, &.{
            f.set("/input/instructions/2/rhs/fields/0/type/bits", f.n("32")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 218
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("64")),
            f.set("/input/value", f.n("18446744073709551616")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 219
        f.derive(&memory_constant_3, &.{
            f.set("/input/value", f.n("18446744073709551616")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 220
        f.derive(&aggregate_program_4, &.{
            f.set("/input/instructions/2/rhs/fields/1/value", f.n("18446744073709551616")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 221
        f.derive(&aggregate_program_4, &.{
            f.add("/input/instructions/2/rhs/fields/0/value", f.n("0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 222
        f.ref(&aggregate_constant_5),
        // Control 223
        f.derive(&word_bytes_program_6, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("0")),
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 224
        f.derive(&word_bytes_program_6, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("3")),
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 225
        f.derive(&word_bytes_program_6, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("8")),
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 226
        f.derive(&word_bytes_program_6, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.b(true)),
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 227
        f.derive(&word_bytes_program_6, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4.0")),
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 228
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("64")),
            f.set("/input/value", f.n("4")),
            f.set("/output", f.s("(.constant (.int false 64 (4)))")),
        }),
        // Control 229
        f.derive(&word_bytes_program_6, &.{
            f.set("/input/instructions/4/type/flags/alignment", f.n("2")),
            f.set("/input/instructions/5/type/child/flags/alignment", f.n("2")),
            f.set("/input/instructions/7/type/child/flags/alignment", f.n("2")),
            f.set("/input/instructions/8/type/flags/alignment", f.n("2")),
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 230
        f.derive(&word_bytes_program_6, &.{
            f.set("/input/instructions/9/type/flags/alignment", f.n("4")),
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 231
        f.derive(&word_bytes_program_6, &.{
            f.set("/input/instructions/3/type/pointeeLayout/alignment", f.n("4")),
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 232
        f.derive(&word_bytes_program_6, &.{
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.set("/input/signature/parameters/0/child/bits", f.n("8")),
            f.set("/input/signature/parameters/0/flags/alignment", f.n("4")),
            f.set("/input/signature/parameters/0/flags/size", f.s("many")),
            f.set("/input/signature/parameters/0/pointeeLayout/alignment", f.n("1")),
            f.set("/input/signature/parameters/0/pointeeLayout/bytes", f.n("1")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 233
        f.derive(&word_bytes_program_6, &.{
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.set("/input/signature/parameters/0/child/bits", f.n("64")),
            f.set("/input/signature/parameters/0/pointeeLayout/alignment", f.n("8")),
            f.set("/input/signature/parameters/0/pointeeLayout/bytes", f.n("8")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 234
        f.derive(&word_bytes_program_6, &.{
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/input/signature/parameters/0/child/bits"),
            f.set("/input/signature/parameters/0/child/kind", f.s("pointer")),
            f.remove("/input/signature/parameters/0/child/signedness"),
            f.add("/input/signature/parameters/0/child/child", f.obj(&.{
                .{ "bits", f.n("32") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("unsigned") },
            })),
            f.add("/input/signature/parameters/0/child/flags", f.ref(&shared.air_aggregate_program_4_input_instructions_type_flags_41)),
            f.add("/input/signature/parameters/0/child/layout", f.obj(&.{
                .{ "alignment", f.n("8") },
                .{ "bytes", f.n("8") },
                .{ "kind", f.s("abi") },
            })),
            f.add("/input/signature/parameters/0/child/pointeeLayout", f.obj(&.{
                .{ "alignment", f.n("4") },
                .{ "bytes", f.n("4") },
                .{ "kind", f.s("abi") },
            })),
            f.add("/input/signature/parameters/0/child/sentinel", .null),
            f.set("/input/signature/parameters/0/pointeeLayout/alignment", f.n("8")),
            f.set("/input/signature/parameters/0/pointeeLayout/bytes", f.n("8")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 235
        f.derive(&word_bytes_program_6, &.{
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.set("/input/signature/genericInstance", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 236
        f.derive(&word_bytes_program_6, &.{
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.set("/input/signature/noaliasBits", f.n("1")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 237
        f.derive(&word_bytes_program_6, &.{
            f.set("/input/configuration/endianness", f.s("big")),
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 238
        f.derive(&word_bytes_program_6, &.{
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.set("/input/instructions/11/operand/kind", f.s("instruction")),
            f.add("/input/instructions/11/operand/index", f.n("9")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 239
        f.derive(&word_bytes_program_6, &.{
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.set("/input/instructions/11/operand/kind", f.s("instruction")),
            f.add("/input/instructions/11/operand/index", f.n("5")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 240
        f.derive(&word_bytes_program_6, &.{
            f.set("/input/instructions/9/tag", f.s("ptr_add")),
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 241
        f.derive(&word_bytes_program_6, &.{
            f.set("/input/instructions/6/rhs/index", f.n("5")),
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 242
        f.derive(&scalar_constant_0, &.{
            f.set("/input/kind", f.s("unit")),
            f.remove("/input/type"),
            f.remove("/input/value"),
            f.set("/output", f.s("(.constant .unit)")),
        }),
        // Control 243
        f.ref(&word_bytes_program_6),
        // Control 244
        f.derive(&word_bytes_program_6, &.{
            f.set("/input/instructions/10/operand/index", f.n("8")),
            f.set("/input/instructions/10/tag", f.s("slice_len")),
            f.set("/input/instructions/10/type/bits", f.n("64")),
            f.text("/output", &.{
                .{ .at = 1144, .old = "8))\n  (.wordByteLoad .little (.local 9", .new = "64))\n  (.sliceLen (.local 8" },
            }),
        }),
        // Control 245
        f.derive(&word_bytes_program_6, &.{
            f.set("/input/instructions/10/operand/index", f.n("8")),
            f.set("/input/instructions/10/tag", f.s("slice_ptr")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("pointer")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/type/child", f.obj(&.{
                .{ "bits", f.n("8") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("unsigned") },
            })),
            f.add("/input/instructions/10/type/flags", f.ref(&shared.air_word_bytes_program_6_input_instructions_type_flags_60)),
            f.add("/input/instructions/10/type/layout", f.obj(&.{
                .{ "alignment", f.n("8") },
                .{ "bytes", f.n("8") },
                .{ "kind", f.s("abi") },
            })),
            f.add("/input/instructions/10/type/pointeeLayout", f.obj(&.{
                .{ "alignment", f.n("1") },
                .{ "bytes", f.n("1") },
                .{ "kind", f.s("abi") },
            })),
            f.add("/input/instructions/10/type/sentinel", .null),
            f.text("/output", &.{
                .{ .at = 1125, .old = "scalar (.int false 8))\n  (.wordByteLoad .little (.local 9", .new = "pointer true true (.scalar (.int false 8)))\n  (.slicePtr (.local 8" },
            }),
        }),
        // Control 246
        f.derive(&word_bytes_program_6, &.{
            f.set("/input/instructions/0/type/flags/isConst", f.b(true)),
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.set("/input/signature/parameters/0/flags/isConst", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 247
        f.derive(&word_bytes_program_6, &.{
            f.set("/input/instructions/9/type/flags/isConst", f.b(true)),
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 248
        f.derive(&word_bytes_program_6, &.{
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("1") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 249
        f.derive(&word_bytes_program_6, &.{
            f.remove("/input/instructions/8/type/child"),
            f.remove("/input/instructions/8/type/flags"),
            f.set("/input/instructions/8/type/kind", f.s("int")),
            f.remove("/input/instructions/8/type/layout"),
            f.remove("/input/instructions/8/type/pointeeLayout"),
            f.remove("/input/instructions/8/type/sentinel"),
            f.add("/input/instructions/8/type/bits", f.n("8")),
            f.add("/input/instructions/8/type/signedness", f.s("unsigned")),
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 250
        f.derive(&word_bytes_program_6, &.{
            f.set("/input/body/10", f.n("12")),
            f.set("/input/body/11", f.n("13")),
            f.remove("/input/instructions/11"),
            f.remove("/input/instructions/10"),
            f.remove("/input/instructions/9"),
            f.add("/input/instructions/9", f.ref(&shared.air_input_instructions_9_193)),
            f.add("/input/instructions/10", f.ref(&shared.air_input_instructions_10_195)),
            f.add("/input/instructions/11", f.ref(&shared.air_input_instructions_11_196)),
            f.add("/input/instructions/12", f.ref(&shared.air_input_instructions_12_197)),
            f.add("/input/instructions/13", f.obj(&.{
                .{ "index", f.n("13") },
                .{ "operand", f.obj(&.{
                    .{ "kind", f.s("unit") },
                }) },
                .{ "payloadVisited", f.b(true) },
                .{ "tag", f.s("ret") },
                .{ "type", f.obj(&.{
                    .{ "kind", f.s("noreturn") },
                }) },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 251
        f.derive(&word_bytes_program_6, &.{
            f.set("/input/instructions/3/type/flags/isVolatile", f.b(true)),
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 252
        f.derive(&word_bytes_program_6, &.{
            f.set("/input/instructions/3/type/child/bits", f.n("64")),
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 253
        f.derive(&word_bytes_program_6, &.{
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.text("/output", &.{
                .{ .at = 1132, .old = "(.int false 8))\n  (.wordByteLoad .little (.local 9", .new = ".unit)\n  (.wordByteStore .little (.local 9) (.local 2" },
            }),
        }),
        // Control 254
        f.ref(&memory_program_19),
        // Control 255
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("64")),
            f.set("/input/value", f.n("3")),
            f.set("/output", f.s("(.constant (.int false 64 (3)))")),
        }),
        // Control 256
        f.derive(&word_bytes_program_6, &.{
            f.set("/input/instructions/4/rhs/value", f.n("3")),
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 257
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("64")),
            f.set("/input/value", f.n("5")),
            f.set("/output", f.s("(.constant (.int false 64 (5)))")),
        }),
        // Control 258
        f.derive(&word_bytes_program_6, &.{
            f.set("/input/instructions/4/rhs/value", f.n("5")),
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 259
        f.derive(&word_bytes_program_6, &.{
            f.set("/input/instructions/4/rhs/kind", f.s("instruction")),
            f.remove("/input/instructions/4/rhs/type"),
            f.remove("/input/instructions/4/rhs/value"),
            f.add("/input/instructions/4/rhs/index", f.n("1")),
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 260
        f.derive(&word_bytes_program_6, &.{
            f.remove("/input/instructions/4/type/child"),
            f.remove("/input/instructions/4/type/flags"),
            f.set("/input/instructions/4/type/kind", f.s("void")),
            f.remove("/input/instructions/4/type/layout"),
            f.remove("/input/instructions/4/type/pointeeLayout"),
            f.remove("/input/instructions/4/type/sentinel"),
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 261
        f.derive(&word_bytes_program_6, &.{
            f.set("/input/instructions/4/type/child/bits", f.n("32")),
            f.set("/input/instructions/4/type/flags/alignment", .null),
            f.set("/input/instructions/4/type/pointeeLayout/alignment", f.n("4")),
            f.set("/input/instructions/4/type/pointeeLayout/bytes", f.n("4")),
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 262
        f.derive(&word_bytes_program_6, &.{
            f.set("/input/instructions/6/rhs/index", f.n("0")),
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 263
        f.derive(&word_bytes_program_6, &.{
            f.set("/input/instructions/6/lhs/index", f.n("0")),
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 264
        f.derive(&word_bytes_program_6, &.{
            f.set("/input/instructions/5/allocationKind", f.s("heap")),
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 265
        f.derive(&word_bytes_program_6, &.{
            f.set("/input/instructions/7/type/flags/isConst", f.b(false)),
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 266
        f.derive(&word_bytes_program_6, &.{
            f.set("/input/instructions/9/lhs/index", f.n("1")),
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 267
        f.derive(&word_bytes_program_6, &.{
            f.set("/input/instructions/9/rhs/index", f.n("9")),
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 268
        f.derive(&word_bytes_program_6, &.{
            f.remove("/input/instructions/6/lhs"),
            f.remove("/input/instructions/6/rhs"),
            f.set("/input/instructions/6/tag", f.s("load")),
            f.set("/input/instructions/6/type/kind", f.s("pointer")),
            f.add("/input/instructions/6/type/child", f.obj(&.{
                .{ "bits", f.n("8") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("unsigned") },
            })),
            f.add("/input/instructions/6/type/flags", f.ref(&shared.air_word_bytes_program_6_input_instructions_type_flags_63)),
            f.add("/input/instructions/6/type/layout", f.obj(&.{
                .{ "alignment", f.n("8") },
                .{ "bytes", f.n("16") },
                .{ "kind", f.s("abi") },
            })),
            f.add("/input/instructions/6/type/pointeeLayout", f.obj(&.{
                .{ "alignment", f.n("1") },
                .{ "bytes", f.n("1") },
                .{ "kind", f.s("abi") },
            })),
            f.add("/input/instructions/6/type/sentinel", .null),
            f.add("/input/instructions/6/operand", f.obj(&.{
                .{ "index", f.n("5") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/input/instructions/10/operand"),
            f.set("/input/instructions/10/tag", f.s("store")),
            f.remove("/input/instructions/10/type/bits"),
            f.set("/input/instructions/10/type/kind", f.s("void")),
            f.remove("/input/instructions/10/type/signedness"),
            f.add("/input/instructions/10/lhs", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
            f.add("/input/instructions/10/rhs", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "kind", f.s("instruction") },
            })),
            f.text("/output", &.{
                .{ .at = 726, .old = "calar .unit)\n  (.store (.local 5) (.local 4", .new = "lice true (.scalar (.int false 8)))\n  (.load (.local 5" },
                .{ .at = 1132, .old = "(.int false 8))\n  (.wordByteLoad .little (.local 9", .new = ".unit)\n  (.wordByteStore .little (.local 9) (.local 2" },
            }),
        }),
        // Control 269
        f.ref(&loops_program_7),
        // Control 270
        f.ref(&memory_program_20),
        // Control 271
        f.ref(&loops_program_21),
        // Control 272
        f.derive(&loops_program_21, &.{
            f.set("/input/instructions/2/type/flags/size", f.s("many")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 273
        f.derive(&loops_program_21, &.{
            f.set("/input/instructions/2/type/flags/isConst", f.b(false)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 274
        f.derive(&loops_program_21, &.{
            f.set("/input/instructions/2/rhs/index", f.n("2")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 275
        f.derive(&loops_program_21, &.{
            f.set("/input/instructions/2/rhs/index", f.n("0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 276
        f.derive(&loops_program_21, &.{
            f.remove("/input/instructions/0/type/child/bits"),
            f.set("/input/instructions/0/type/child/kind", f.s("void")),
            f.remove("/input/instructions/0/type/child/signedness"),
            f.set("/input/instructions/0/type/pointeeLayout/bytes", f.n("0")),
            f.remove("/input/signature/parameters/0/child/bits"),
            f.set("/input/signature/parameters/0/child/kind", f.s("void")),
            f.remove("/input/signature/parameters/0/child/signedness"),
            f.set("/input/signature/parameters/0/pointeeLayout/bytes", f.n("0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 277
        f.derive(&loops_program_21, &.{
            f.set("/input/instructions/0/type/flags/size", f.s("one")),
            f.set("/input/signature/parameters/0/flags/size", f.s("one")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 278
        f.derive(&loops_program_7, &.{
            f.remove("/input/instructions/2/body/1"),
            f.remove("/input/instructions/2/body/0"),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 279
        f.derive(&loops_program_7, &.{
            f.remove("/input/instructions/2/body/1"),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 280
        f.derive(&loops_program_7, &.{
            f.add("/input/instructions/2/body/2", f.n("6")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 281
        f.derive(&loops_program_7, &.{
            f.add("/input/instructions/2/body/1", f.n("3")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 282
        f.derive(&loops_program_7, &.{
            f.remove("/input/instructions/2/body/1"),
            f.remove("/input/instructions/2/body/0"),
            f.add("/input/instructions/2/body/0", f.n("2")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 283
        f.derive(&loops_program_7, &.{
            f.remove("/input/instructions/4/elseBody/0"),
            f.add("/input/instructions/4/elseBody/0", f.n("5")),
            f.add("/input/instructions/4/elseBody/1", f.n("6")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 284
        f.derive(&loops_program_7, &.{
            f.set("/input/instructions/6/tag", f.s("br")),
            f.set("/input/instructions/6/target", f.n("1")),
            f.add("/input/instructions/6/operand", f.obj(&.{
                .{ "index", f.n("5") },
                .{ "kind", f.s("instruction") },
            })),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 285
        f.derive(&loops_program_7, &.{
            f.set("/input/instructions/2/type/kind", f.s("void")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 286
        f.derive(&loops_program_7, &.{
            f.add("/input/instructions/2/extra", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 287
        f.derive(&loops_program_7, &.{
            f.set("/input/instructions/6/type/kind", f.s("void")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 288
        f.derive(&loops_program_7, &.{
            f.add("/input/instructions/6/extra", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 289
        f.derive(&loops_program_7, &.{
            f.set("/input/instructions/3/lhs/index", f.n("5")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 290
        f.derive(&loops_program_7, &.{
            f.set("/input/instructions/5/rhs/kind", f.s("instruction")),
            f.remove("/input/instructions/5/rhs/type"),
            f.remove("/input/instructions/5/rhs/value"),
            f.add("/input/instructions/5/rhs/index", f.n("5")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 291
        f.derive(&loops_program_7, &.{
            f.set("/input/instructions/7/operand/index", f.n("5")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 292
        f.derive(&loops_program_7, &.{
            f.set("/input/instructions/8/operand/index", f.n("3")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 293
        f.derive(&loops_program_7, &.{
            f.set("/input/instructions/8/operand/index", f.n("2")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 294
        f.ref(&loops_program_22),
        // Control 295
        f.derive(&loops_program_7, &.{
            f.set("/input/instructions/6/target", f.n("0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 296
        f.derive(&loops_program_7, &.{
            f.set("/input/instructions/6/target", f.n("1")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 297
        f.derive(&loops_program_7, &.{
            f.set("/input/instructions/6/target", f.n("5")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 298
        f.derive(&loops_program_7, &.{
            f.set("/input/instructions/6/target", f.n("6")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 299
        f.derive(&loops_program_7, &.{
            f.set("/input/instructions/6/target", f.n("8")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 300
        f.derive(&loops_program_7, &.{
            f.set("/input/instructions/6/target", f.n("-1")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 301
        f.derive(&loops_program_7, &.{
            f.set("/input/instructions/6/target", f.n("9")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 302
        f.derive(&loops_program_7, &.{
            f.set("/input/instructions/6/target", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 303
        f.derive(&loops_program_7, &.{
            f.set("/input/instructions/7/target", f.n("2")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 304
        f.derive(&loops_program_7, &.{
            f.remove("/input/instructions/8/operand"),
            f.set("/input/instructions/8/tag", f.s("repeat")),
            f.add("/input/instructions/8/target", f.n("2")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 305
        f.derive(&loops_program_7, &.{
            f.set("/input/instructions/5/tag", f.s("call")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 306
        f.derive(&loops_program_7, &.{
            f.set("/input/instructions/5/tag", f.s("ret_load")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 307
        f.derive(&loops_program_7, &.{
            f.set("/input/instructions/5/tag", f.s("unreach")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 308
        f.derive(&loops_program_7, &.{
            f.set("/input/instructions/5/tag", f.s("future")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 309
        f.derive(&scalar_constant_0, &.{
            f.set("/input/type/bits", f.n("8")),
            f.set("/input/value", f.n("7")),
            f.set("/output", f.s("(.constant (.int false 8 (7)))")),
        }),
        // Control 310
        f.derive(&memory_constant_3, &.{
            f.set("/input/type/bits", f.n("8")),
            f.set("/input/value", f.n("7")),
            f.set("/output", f.s("(.constant (.scalar (.int false 8 (7))))")),
        }),
        // Control 311
        f.derive(&memory_constant_3, &.{
            f.set("/input/type/bits", f.n("8")),
            f.set("/output", f.s("(.constant (.scalar (.int false 8 (0))))")),
        }),
        // Control 312
        f.ref(&memory_program_23),
        // Control 313
        f.derive(&memory_program_23, &.{
            f.remove("/input/specialization"),
        }),
        // Control 314
        f.ref(&word_byte_loops_program_24),
        // Control 315
        f.ref(&loops_program_25),
        // Control 316
        f.ref(&aggregate_program_26),
        // Control 317
        f.ref(&word_bytes_program_27),
        // Control 318
        f.ref(&word_byte_loops_program_8),
        // Control 319
        f.derive(&scalar_program_1, &.{
            f.set("/input/instructions/4/tag", f.s("future_op")),
            f.set("/input/name", f.s("fixture.other")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
    };
};
