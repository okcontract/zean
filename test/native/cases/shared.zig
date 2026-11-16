// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
// Immutable reference controls with shared fixtures and explicit mutations.
const f = @import("../fixtures.zig");
const golden = @import("golden.zig");

pub const air_scalar_program_1_input_2 = f.obj(&.{
    .{ "body", f.arr(&.{
        f.n("0"),
        f.n("1"),
        f.n("7"),
    }) },
    .{ "bodyTraversal", f.s("supported-structured-containers-only") },
    .{ "capturePoint", f.s("after-sema-before-legalize") },
    .{ "configuration", f.obj(&.{
        .{ "isTest", f.b(false) },
        .{ "optimize", f.s("ReleaseFast") },
        .{ "useLlvm", f.b(true) },
    }) },
    .{ "instructions", f.ref(&air_scalar_program_1_input_instructions_3) },
    .{ "name", f.s("fixture.choose") },
    .{ "schema", f.s("oksolc.fresh-air.v3") },
    .{ "signature", f.ref(&air_scalar_program_1_input_signature_10) },
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
});

pub const air_scalar_program_1_input_instructions_3 = f.arr(&.{
    f.ref(&air_scalar_program_1_input_instructions_4),
    f.obj(&.{
        .{ "body", f.arr(&.{
            f.n("2"),
            f.n("3"),
        }) },
        .{ "index", f.n("1") },
        .{ "payloadVisited", f.b(true) },
        .{ "tag", f.s("block") },
        .{ "type", f.obj(&.{
            .{ "bits", f.n("8") },
            .{ "kind", f.s("int") },
            .{ "signedness", f.s("unsigned") },
        }) },
    }),
    f.ref(&air_scalar_program_1_input_instructions_5),
    f.ref(&air_scalar_program_1_input_instructions_6),
    f.ref(&air_scalar_program_1_input_instructions_7),
    f.ref(&air_scalar_program_1_input_instructions_8),
    f.ref(&air_scalar_program_1_input_instructions_9),
    f.obj(&.{
        .{ "index", f.n("7") },
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
});

pub const air_scalar_program_1_input_instructions_4 = f.obj(&.{
    .{ "index", f.n("0") },
    .{ "payloadVisited", f.b(true) },
    .{ "tag", f.s("arg") },
    .{ "type", f.obj(&.{
        .{ "bits", f.n("8") },
        .{ "kind", f.s("int") },
        .{ "signedness", f.s("unsigned") },
    }) },
    .{ "zirParameterIndex", f.n("0") },
});

pub const air_scalar_program_1_input_instructions_5 = f.obj(&.{
    .{ "index", f.n("2") },
    .{ "lhs", f.obj(&.{
        .{ "index", f.n("0") },
        .{ "kind", f.s("instruction") },
    }) },
    .{ "payloadVisited", f.b(true) },
    .{ "rhs", f.obj(&.{
        .{ "kind", f.s("constant") },
        .{ "type", f.obj(&.{
            .{ "bits", f.n("8") },
            .{ "kind", f.s("int") },
            .{ "signedness", f.s("unsigned") },
        }) },
        .{ "value", f.n("128") },
    }) },
    .{ "tag", f.s("cmp_lt") },
    .{ "type", f.obj(&.{
        .{ "kind", f.s("bool") },
    }) },
});

pub const air_scalar_program_1_input_instructions_6 = f.obj(&.{
    .{ "condition", f.obj(&.{
        .{ "index", f.n("2") },
        .{ "kind", f.s("instruction") },
    }) },
    .{ "elseBody", f.arr(&.{
        f.n("6"),
    }) },
    .{ "index", f.n("3") },
    .{ "payloadVisited", f.b(true) },
    .{ "tag", f.s("cond_br") },
    .{ "thenBody", f.arr(&.{
        f.n("4"),
        f.n("5"),
    }) },
    .{ "type", f.obj(&.{
        .{ "kind", f.s("noreturn") },
    }) },
});

pub const air_scalar_program_1_input_instructions_7 = f.obj(&.{
    .{ "index", f.n("4") },
    .{ "lhs", f.obj(&.{
        .{ "index", f.n("0") },
        .{ "kind", f.s("instruction") },
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
    .{ "tag", f.s("add") },
    .{ "type", f.obj(&.{
        .{ "bits", f.n("8") },
        .{ "kind", f.s("int") },
        .{ "signedness", f.s("unsigned") },
    }) },
});

pub const air_scalar_program_1_input_instructions_8 = f.obj(&.{
    .{ "index", f.n("5") },
    .{ "operand", f.obj(&.{
        .{ "index", f.n("4") },
        .{ "kind", f.s("instruction") },
    }) },
    .{ "payloadVisited", f.b(true) },
    .{ "tag", f.s("br") },
    .{ "target", f.n("1") },
    .{ "type", f.obj(&.{
        .{ "kind", f.s("noreturn") },
    }) },
});

pub const air_scalar_program_1_input_instructions_9 = f.obj(&.{
    .{ "index", f.n("6") },
    .{ "operand", f.obj(&.{
        .{ "index", f.n("0") },
        .{ "kind", f.s("instruction") },
    }) },
    .{ "payloadVisited", f.b(true) },
    .{ "tag", f.s("br") },
    .{ "target", f.n("1") },
    .{ "type", f.obj(&.{
        .{ "kind", f.s("noreturn") },
    }) },
});

pub const air_scalar_program_1_input_signature_10 = f.obj(&.{
    .{ "callingConvention", f.s("auto") },
    .{ "genericInstance", f.b(false) },
    .{ "noaliasBits", f.n("0") },
    .{ "parameters", f.arr(&.{
        f.obj(&.{
            .{ "bits", f.n("8") },
            .{ "kind", f.s("int") },
            .{ "signedness", f.s("unsigned") },
        }),
    }) },
    .{ "returnType", f.obj(&.{
        .{ "bits", f.n("8") },
        .{ "kind", f.s("int") },
        .{ "signedness", f.s("unsigned") },
    }) },
    .{ "varArgs", f.b(false) },
});

pub const air_memory_program_2_input_13 = f.obj(&.{
    .{ "body", f.arr(&.{
        f.n("0"),
        f.n("1"),
        f.n("2"),
        f.n("3"),
    }) },
    .{ "bodyTraversal", f.s("supported-structured-containers-only") },
    .{ "capturePoint", f.s("after-sema-before-legalize") },
    .{ "configuration", f.ref(&air_memory_program_2_input_configuration_14) },
    .{ "instructions", f.ref(&air_memory_program_2_input_instructions_15) },
    .{ "name", f.s("fixture.choose") },
    .{ "schema", f.s("oksolc.fresh-air.v3") },
    .{ "signature", f.ref(&air_memory_program_2_input_signature_24) },
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
        .{ "slices", f.arr(&.{
            f.ref(&air_memory_program_2_input_sourcevalidity_slices_28),
        }) },
    }) },
    .{ "sourceValidityConditionsPreserved", f.b(false) },
});

pub const air_memory_program_2_input_configuration_14 = f.obj(&.{
    .{ "arch", f.s("aarch64") },
    .{ "endianness", f.s("little") },
    .{ "isTest", f.b(false) },
    .{ "optimize", f.s("ReleaseFast") },
    .{ "os", f.s("macos") },
    .{ "pointerBits", f.n("64") },
    .{ "useLlvm", f.b(true) },
});

pub const air_memory_program_2_input_instructions_15 = f.arr(&.{
    f.ref(&air_memory_program_2_input_instructions_16),
    f.ref(&air_memory_program_2_input_instructions_19),
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
        .{ "tag", f.s("slice") },
        .{ "type", f.ref(&pointer_21) },
    }),
    f.ref(&air_memory_program_2_input_instructions_23),
});

pub const air_memory_program_2_input_instructions_16 = f.obj(&.{
    .{ "index", f.n("0") },
    .{ "payloadVisited", f.b(true) },
    .{ "tag", f.s("arg") },
    .{ "type", f.ref(&pointer_17) },
    .{ "zirParameterIndex", f.n("0") },
});

pub const pointer_17 = f.obj(&.{
    .{ "child", f.obj(&.{
        .{ "bits", f.n("8") },
        .{ "kind", f.s("int") },
        .{ "signedness", f.s("unsigned") },
    }) },
    .{ "flags", f.obj(&.{
        .{ "addressSpace", f.s("generic") },
        .{ "alignment", .null },
        .{ "allowZero", f.b(false) },
        .{ "bitOffset", f.n("0") },
        .{ "hostSizeBytes", f.n("0") },
        .{ "isConst", f.b(true) },
        .{ "isVolatile", f.b(false) },
        .{ "size", f.s("many") },
        .{ "vectorIndex", .null },
    }) },
    .{ "kind", f.s("pointer") },
    .{ "layout", f.obj(&.{
        .{ "alignment", f.n("8") },
        .{ "bytes", f.n("8") },
        .{ "kind", f.s("abi") },
    }) },
    .{ "pointeeLayout", f.obj(&.{
        .{ "alignment", f.n("1") },
        .{ "bytes", f.n("1") },
        .{ "kind", f.s("abi") },
    }) },
    .{ "sentinel", .null },
});

pub const air_memory_program_2_input_instructions_19 = f.obj(&.{
    .{ "index", f.n("1") },
    .{ "payloadVisited", f.b(true) },
    .{ "tag", f.s("arg") },
    .{ "type", f.obj(&.{
        .{ "bits", f.n("64") },
        .{ "kind", f.s("int") },
        .{ "signedness", f.s("unsigned") },
    }) },
    .{ "zirParameterIndex", f.n("1") },
});

pub const pointer_21 = f.obj(&.{
    .{ "child", f.obj(&.{
        .{ "bits", f.n("8") },
        .{ "kind", f.s("int") },
        .{ "signedness", f.s("unsigned") },
    }) },
    .{ "flags", f.obj(&.{
        .{ "addressSpace", f.s("generic") },
        .{ "alignment", .null },
        .{ "allowZero", f.b(false) },
        .{ "bitOffset", f.n("0") },
        .{ "hostSizeBytes", f.n("0") },
        .{ "isConst", f.b(true) },
        .{ "isVolatile", f.b(false) },
        .{ "size", f.s("slice") },
        .{ "vectorIndex", .null },
    }) },
    .{ "kind", f.s("pointer") },
    .{ "layout", f.obj(&.{
        .{ "alignment", f.n("8") },
        .{ "bytes", f.n("16") },
        .{ "kind", f.s("abi") },
    }) },
    .{ "pointeeLayout", f.obj(&.{
        .{ "alignment", f.n("1") },
        .{ "bytes", f.n("1") },
        .{ "kind", f.s("abi") },
    }) },
    .{ "sentinel", .null },
});

pub const air_memory_program_2_input_instructions_23 = f.obj(&.{
    .{ "index", f.n("3") },
    .{ "operand", f.obj(&.{
        .{ "kind", f.s("constant") },
        .{ "type", f.obj(&.{
            .{ "bits", f.n("64") },
            .{ "kind", f.s("int") },
            .{ "signedness", f.s("unsigned") },
        }) },
        .{ "value", f.n("1") },
    }) },
    .{ "payloadVisited", f.b(true) },
    .{ "tag", f.s("ret") },
    .{ "type", f.obj(&.{
        .{ "kind", f.s("noreturn") },
    }) },
});

pub const air_memory_program_2_input_signature_24 = f.obj(&.{
    .{ "callingConvention", f.s("auto") },
    .{ "genericInstance", f.b(false) },
    .{ "noaliasBits", f.n("0") },
    .{ "parameters", f.arr(&.{
        f.ref(&pointer_17),
        f.obj(&.{
            .{ "bits", f.n("64") },
            .{ "kind", f.s("int") },
            .{ "signedness", f.s("unsigned") },
        }),
    }) },
    .{ "returnType", f.obj(&.{
        .{ "bits", f.n("64") },
        .{ "kind", f.s("int") },
        .{ "signedness", f.s("unsigned") },
    }) },
    .{ "varArgs", f.b(false) },
});

pub const air_memory_program_2_input_sourcevalidity_slices_28 = f.obj(&.{
    .{ "anchor", f.obj(&.{
        .{ "inSupportedBody", f.b(true) },
        .{ "index", f.n("2") },
        .{ "kind", f.s("beforeInstruction") },
    }) },
    .{ "end", f.obj(&.{
        .{ "index", f.n("1") },
        .{ "kind", f.s("instruction") },
    }) },
    .{ "source", f.obj(&.{
        .{ "file", f.s("fixture.zig") },
        .{ "sha256", f.s("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") },
        .{ "span", f.obj(&.{
            .{ "end", f.n("2") },
            .{ "main", f.n("1") },
            .{ "start", f.n("0") },
        }) },
    }) },
    .{ "start", f.obj(&.{
        .{ "kind", f.s("constant") },
        .{ "type", f.obj(&.{
            .{ "bits", f.n("64") },
            .{ "kind", f.s("int") },
            .{ "signedness", f.s("unsigned") },
        }) },
        .{ "value", f.n("0") },
    }) },
    .{ "unsupportedReason", .null },
    .{ "upperBound", f.obj(&.{
        .{ "kind", f.s("unboundedPointer") },
        .{ "requiresMemoryValidity", f.b(true) },
    }) },
});

pub const air_aggregate_program_4_input_33 = f.obj(&.{
    .{ "body", f.arr(&.{
        f.n("0"),
        f.n("1"),
        f.n("2"),
        f.n("3"),
        f.n("4"),
        f.n("5"),
        f.n("6"),
    }) },
    .{ "bodyTraversal", f.s("supported-structured-containers-only") },
    .{ "capturePoint", f.s("after-sema-before-legalize") },
    .{ "configuration", f.ref(&air_memory_program_2_input_configuration_14) },
    .{ "instructions", f.arr(&.{
        f.ref(&air_aggregate_program_4_input_instructions_35),
        f.obj(&.{
            .{ "allocationKind", f.s("stack") },
            .{ "index", f.n("1") },
            .{ "payloadVisited", f.b(true) },
            .{ "tag", f.s("alloc") },
            .{ "type", f.obj(&.{
                .{ "child", f.ref(&struct_38) },
                .{ "flags", f.ref(&air_aggregate_program_4_input_instructions_type_flags_41) },
                .{ "kind", f.s("pointer") },
                .{ "layout", f.obj(&.{
                    .{ "alignment", f.n("8") },
                    .{ "bytes", f.n("8") },
                    .{ "kind", f.s("abi") },
                }) },
                .{ "pointeeLayout", f.obj(&.{
                    .{ "alignment", f.n("8") },
                    .{ "bytes", f.n("16") },
                    .{ "kind", f.s("abi") },
                }) },
                .{ "sentinel", .null },
            }) },
        }),
        f.obj(&.{
            .{ "index", f.n("2") },
            .{ "lhs", f.obj(&.{
                .{ "index", f.n("1") },
                .{ "kind", f.s("instruction") },
            }) },
            .{ "payloadVisited", f.b(true) },
            .{ "rhs", f.obj(&.{
                .{ "fields", f.ref(&air_aggregate_program_4_input_instructions_rhs_fields_44) },
                .{ "kind", f.s("aggregate") },
                .{ "type", f.ref(&struct_38) },
            }) },
            .{ "tag", f.s("store") },
            .{ "type", f.obj(&.{
                .{ "kind", f.s("void") },
            }) },
        }),
        f.ref(&air_aggregate_program_4_input_instructions_45),
        f.ref(&air_aggregate_program_4_input_instructions_47),
        f.obj(&.{
            .{ "index", f.n("5") },
            .{ "operand", f.obj(&.{
                .{ "index", f.n("1") },
                .{ "kind", f.s("instruction") },
            }) },
            .{ "payloadVisited", f.b(true) },
            .{ "tag", f.s("load") },
            .{ "type", f.ref(&struct_38) },
        }),
        f.obj(&.{
            .{ "index", f.n("6") },
            .{ "operand", f.obj(&.{
                .{ "index", f.n("5") },
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
                .{ "bits", f.n("64") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("unsigned") },
            }),
        }) },
        .{ "returnType", f.ref(&struct_38) },
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
});

pub const air_aggregate_program_4_input_instructions_35 = f.obj(&.{
    .{ "index", f.n("0") },
    .{ "payloadVisited", f.b(true) },
    .{ "tag", f.s("arg") },
    .{ "type", f.obj(&.{
        .{ "bits", f.n("64") },
        .{ "kind", f.s("int") },
        .{ "signedness", f.s("unsigned") },
    }) },
    .{ "zirParameterIndex", f.n("0") },
});

pub const struct_38 = f.obj(&.{
    .{ "containerLayout", f.s("auto") },
    .{ "fields", f.ref(&air_aggregate_program_4_input_instructions_type_child_fields_39) },
    .{ "identity", f.obj(&.{
        .{ "name", f.s("fixture.Pair") },
        .{ "sourceFile", f.s("fixture.zig") },
        .{ "sourceSha256", f.s("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") },
    }) },
    .{ "kind", f.s("struct") },
    .{ "layout", f.obj(&.{
        .{ "alignment", f.n("8") },
        .{ "bytes", f.n("16") },
        .{ "kind", f.s("abi") },
    }) },
});

pub const air_aggregate_program_4_input_instructions_type_child_fields_39 = f.arr(&.{
    f.obj(&.{
        .{ "explicitAlignment", .null },
        .{ "index", f.n("0") },
        .{ "name", f.s("last") },
        .{ "offset", f.n("8") },
        .{ "type", f.obj(&.{
            .{ "bits", f.n("64") },
            .{ "kind", f.s("int") },
            .{ "signedness", f.s("unsigned") },
        }) },
    }),
    f.obj(&.{
        .{ "explicitAlignment", .null },
        .{ "index", f.n("1") },
        .{ "name", f.s("first") },
        .{ "offset", f.n("0") },
        .{ "type", f.obj(&.{
            .{ "bits", f.n("64") },
            .{ "kind", f.s("int") },
            .{ "signedness", f.s("unsigned") },
        }) },
    }),
});

pub const air_aggregate_program_4_input_instructions_type_flags_41 = f.obj(&.{
    .{ "addressSpace", f.s("generic") },
    .{ "alignment", .null },
    .{ "allowZero", f.b(false) },
    .{ "bitOffset", f.n("0") },
    .{ "hostSizeBytes", f.n("0") },
    .{ "isConst", f.b(false) },
    .{ "isVolatile", f.b(false) },
    .{ "size", f.s("one") },
    .{ "vectorIndex", .null },
});

pub const air_aggregate_program_4_input_instructions_rhs_fields_44 = f.arr(&.{
    f.obj(&.{
        .{ "kind", f.s("undefined") },
        .{ "type", f.obj(&.{
            .{ "bits", f.n("64") },
            .{ "kind", f.s("int") },
            .{ "signedness", f.s("unsigned") },
        }) },
    }),
    f.obj(&.{
        .{ "kind", f.s("constant") },
        .{ "type", f.obj(&.{
            .{ "bits", f.n("64") },
            .{ "kind", f.s("int") },
            .{ "signedness", f.s("unsigned") },
        }) },
        .{ "value", f.n("0") },
    }),
});

pub const air_aggregate_program_4_input_instructions_45 = f.obj(&.{
    .{ "fieldIndex", f.n("1") },
    .{ "index", f.n("3") },
    .{ "operand", f.obj(&.{
        .{ "index", f.n("1") },
        .{ "kind", f.s("instruction") },
    }) },
    .{ "payloadVisited", f.b(true) },
    .{ "tag", f.s("struct_field_ptr_index_1") },
    .{ "type", f.obj(&.{
        .{ "child", f.obj(&.{
            .{ "bits", f.n("64") },
            .{ "kind", f.s("int") },
            .{ "signedness", f.s("unsigned") },
        }) },
        .{ "flags", f.ref(&air_aggregate_program_4_input_instructions_type_flags_41) },
        .{ "kind", f.s("pointer") },
        .{ "layout", f.obj(&.{
            .{ "alignment", f.n("8") },
            .{ "bytes", f.n("8") },
            .{ "kind", f.s("abi") },
        }) },
        .{ "pointeeLayout", f.obj(&.{
            .{ "alignment", f.n("8") },
            .{ "bytes", f.n("8") },
            .{ "kind", f.s("abi") },
        }) },
        .{ "sentinel", .null },
    }) },
});

pub const air_aggregate_program_4_input_instructions_47 = f.obj(&.{
    .{ "index", f.n("4") },
    .{ "lhs", f.obj(&.{
        .{ "index", f.n("3") },
        .{ "kind", f.s("instruction") },
    }) },
    .{ "payloadVisited", f.b(true) },
    .{ "rhs", f.obj(&.{
        .{ "index", f.n("0") },
        .{ "kind", f.s("instruction") },
    }) },
    .{ "tag", f.s("store") },
    .{ "type", f.obj(&.{
        .{ "kind", f.s("void") },
    }) },
});

pub const air_word_bytes_program_6_input_instructions_55 = f.obj(&.{
    .{ "index", f.n("0") },
    .{ "payloadVisited", f.b(true) },
    .{ "tag", f.s("arg") },
    .{ "type", f.ref(&pointer_56) },
    .{ "zirParameterIndex", f.n("0") },
});

pub const pointer_56 = f.obj(&.{
    .{ "child", f.obj(&.{
        .{ "bits", f.n("32") },
        .{ "kind", f.s("int") },
        .{ "signedness", f.s("unsigned") },
    }) },
    .{ "flags", f.ref(&air_aggregate_program_4_input_instructions_type_flags_41) },
    .{ "kind", f.s("pointer") },
    .{ "layout", f.obj(&.{
        .{ "alignment", f.n("8") },
        .{ "bytes", f.n("8") },
        .{ "kind", f.s("abi") },
    }) },
    .{ "pointeeLayout", f.obj(&.{
        .{ "alignment", f.n("4") },
        .{ "bytes", f.n("4") },
        .{ "kind", f.s("abi") },
    }) },
    .{ "sentinel", .null },
});

pub const air_word_bytes_program_6_input_instructions_57 = f.obj(&.{
    .{ "index", f.n("2") },
    .{ "payloadVisited", f.b(true) },
    .{ "tag", f.s("arg") },
    .{ "type", f.obj(&.{
        .{ "bits", f.n("8") },
        .{ "kind", f.s("int") },
        .{ "signedness", f.s("unsigned") },
    }) },
    .{ "zirParameterIndex", f.n("2") },
});

pub const air_word_bytes_program_6_input_instructions_58 = f.obj(&.{
    .{ "index", f.n("3") },
    .{ "operand", f.obj(&.{
        .{ "index", f.n("0") },
        .{ "kind", f.s("instruction") },
    }) },
    .{ "payloadVisited", f.b(true) },
    .{ "tag", f.s("ptr_cast") },
    .{ "type", f.obj(&.{
        .{ "child", f.obj(&.{
            .{ "bits", f.n("8") },
            .{ "kind", f.s("int") },
            .{ "signedness", f.s("unsigned") },
        }) },
        .{ "flags", f.ref(&air_word_bytes_program_6_input_instructions_type_flags_60) },
        .{ "kind", f.s("pointer") },
        .{ "layout", f.obj(&.{
            .{ "alignment", f.n("8") },
            .{ "bytes", f.n("8") },
            .{ "kind", f.s("abi") },
        }) },
        .{ "pointeeLayout", f.obj(&.{
            .{ "alignment", f.n("1") },
            .{ "bytes", f.n("1") },
            .{ "kind", f.s("abi") },
        }) },
        .{ "sentinel", .null },
    }) },
});

pub const air_word_bytes_program_6_input_instructions_type_flags_60 = f.obj(&.{
    .{ "addressSpace", f.s("generic") },
    .{ "alignment", f.n("4") },
    .{ "allowZero", f.b(false) },
    .{ "bitOffset", f.n("0") },
    .{ "hostSizeBytes", f.n("0") },
    .{ "isConst", f.b(false) },
    .{ "isVolatile", f.b(false) },
    .{ "size", f.s("many") },
    .{ "vectorIndex", .null },
});

pub const air_word_bytes_program_6_input_instructions_61 = f.obj(&.{
    .{ "index", f.n("4") },
    .{ "lhs", f.obj(&.{
        .{ "index", f.n("3") },
        .{ "kind", f.s("instruction") },
    }) },
    .{ "payloadVisited", f.b(true) },
    .{ "rhs", f.obj(&.{
        .{ "kind", f.s("constant") },
        .{ "type", f.obj(&.{
            .{ "bits", f.n("64") },
            .{ "kind", f.s("int") },
            .{ "signedness", f.s("unsigned") },
        }) },
        .{ "value", f.n("4") },
    }) },
    .{ "tag", f.s("slice") },
    .{ "type", f.ref(&pointer_62) },
});

pub const pointer_62 = f.obj(&.{
    .{ "child", f.obj(&.{
        .{ "bits", f.n("8") },
        .{ "kind", f.s("int") },
        .{ "signedness", f.s("unsigned") },
    }) },
    .{ "flags", f.ref(&air_word_bytes_program_6_input_instructions_type_flags_63) },
    .{ "kind", f.s("pointer") },
    .{ "layout", f.obj(&.{
        .{ "alignment", f.n("8") },
        .{ "bytes", f.n("16") },
        .{ "kind", f.s("abi") },
    }) },
    .{ "pointeeLayout", f.obj(&.{
        .{ "alignment", f.n("1") },
        .{ "bytes", f.n("1") },
        .{ "kind", f.s("abi") },
    }) },
    .{ "sentinel", .null },
});

pub const air_word_bytes_program_6_input_instructions_type_flags_63 = f.obj(&.{
    .{ "addressSpace", f.s("generic") },
    .{ "alignment", f.n("4") },
    .{ "allowZero", f.b(false) },
    .{ "bitOffset", f.n("0") },
    .{ "hostSizeBytes", f.n("0") },
    .{ "isConst", f.b(false) },
    .{ "isVolatile", f.b(false) },
    .{ "size", f.s("slice") },
    .{ "vectorIndex", .null },
});

pub const air_word_bytes_program_6_input_instructions_64 = f.obj(&.{
    .{ "allocationKind", f.s("stack") },
    .{ "index", f.n("5") },
    .{ "payloadVisited", f.b(true) },
    .{ "tag", f.s("alloc") },
    .{ "type", f.obj(&.{
        .{ "child", f.ref(&pointer_62) },
        .{ "flags", f.ref(&air_aggregate_program_4_input_instructions_type_flags_41) },
        .{ "kind", f.s("pointer") },
        .{ "layout", f.obj(&.{
            .{ "alignment", f.n("8") },
            .{ "bytes", f.n("8") },
            .{ "kind", f.s("abi") },
        }) },
        .{ "pointeeLayout", f.obj(&.{
            .{ "alignment", f.n("8") },
            .{ "bytes", f.n("16") },
            .{ "kind", f.s("abi") },
        }) },
        .{ "sentinel", .null },
    }) },
});

pub const air_word_bytes_program_6_input_instructions_66 = f.obj(&.{
    .{ "index", f.n("6") },
    .{ "lhs", f.obj(&.{
        .{ "index", f.n("5") },
        .{ "kind", f.s("instruction") },
    }) },
    .{ "payloadVisited", f.b(true) },
    .{ "rhs", f.obj(&.{
        .{ "index", f.n("4") },
        .{ "kind", f.s("instruction") },
    }) },
    .{ "tag", f.s("store") },
    .{ "type", f.obj(&.{
        .{ "kind", f.s("void") },
    }) },
});

pub const air_word_bytes_program_6_input_instructions_67 = f.obj(&.{
    .{ "index", f.n("7") },
    .{ "operand", f.obj(&.{
        .{ "index", f.n("5") },
        .{ "kind", f.s("instruction") },
    }) },
    .{ "payloadVisited", f.b(true) },
    .{ "tag", f.s("ptr_cast") },
    .{ "type", f.obj(&.{
        .{ "child", f.ref(&pointer_62) },
        .{ "flags", f.ref(&air_word_bytes_program_6_input_instructions_type_flags_69) },
        .{ "kind", f.s("pointer") },
        .{ "layout", f.obj(&.{
            .{ "alignment", f.n("8") },
            .{ "bytes", f.n("8") },
            .{ "kind", f.s("abi") },
        }) },
        .{ "pointeeLayout", f.obj(&.{
            .{ "alignment", f.n("8") },
            .{ "bytes", f.n("16") },
            .{ "kind", f.s("abi") },
        }) },
        .{ "sentinel", .null },
    }) },
});

pub const air_word_bytes_program_6_input_instructions_type_flags_69 = f.obj(&.{
    .{ "addressSpace", f.s("generic") },
    .{ "alignment", .null },
    .{ "allowZero", f.b(false) },
    .{ "bitOffset", f.n("0") },
    .{ "hostSizeBytes", f.n("0") },
    .{ "isConst", f.b(true) },
    .{ "isVolatile", f.b(false) },
    .{ "size", f.s("one") },
    .{ "vectorIndex", .null },
});

pub const air_word_bytes_program_6_input_instructions_70 = f.obj(&.{
    .{ "index", f.n("8") },
    .{ "operand", f.obj(&.{
        .{ "index", f.n("7") },
        .{ "kind", f.s("instruction") },
    }) },
    .{ "payloadVisited", f.b(true) },
    .{ "tag", f.s("load") },
    .{ "type", f.ref(&pointer_62) },
});

pub const air_word_bytes_program_6_input_instructions_71 = f.obj(&.{
    .{ "index", f.n("9") },
    .{ "lhs", f.obj(&.{
        .{ "index", f.n("8") },
        .{ "kind", f.s("instruction") },
    }) },
    .{ "payloadVisited", f.b(true) },
    .{ "rhs", f.obj(&.{
        .{ "index", f.n("1") },
        .{ "kind", f.s("instruction") },
    }) },
    .{ "tag", f.s("slice_elem_ptr") },
    .{ "type", f.obj(&.{
        .{ "child", f.obj(&.{
            .{ "bits", f.n("8") },
            .{ "kind", f.s("int") },
            .{ "signedness", f.s("unsigned") },
        }) },
        .{ "flags", f.obj(&.{
            .{ "addressSpace", f.s("generic") },
            .{ "alignment", f.n("1") },
            .{ "allowZero", f.b(false) },
            .{ "bitOffset", f.n("0") },
            .{ "hostSizeBytes", f.n("0") },
            .{ "isConst", f.b(false) },
            .{ "isVolatile", f.b(false) },
            .{ "size", f.s("one") },
            .{ "vectorIndex", .null },
        }) },
        .{ "kind", f.s("pointer") },
        .{ "layout", f.obj(&.{
            .{ "alignment", f.n("8") },
            .{ "bytes", f.n("8") },
            .{ "kind", f.s("abi") },
        }) },
        .{ "pointeeLayout", f.obj(&.{
            .{ "alignment", f.n("1") },
            .{ "bytes", f.n("1") },
            .{ "kind", f.s("abi") },
        }) },
        .{ "sentinel", .null },
    }) },
});

pub const air_word_bytes_program_6_input_signature_75 = f.obj(&.{
    .{ "callingConvention", f.s("auto") },
    .{ "genericInstance", f.b(false) },
    .{ "noaliasBits", f.n("0") },
    .{ "parameters", f.arr(&.{
        f.ref(&pointer_56),
        f.obj(&.{
            .{ "bits", f.n("64") },
            .{ "kind", f.s("int") },
            .{ "signedness", f.s("unsigned") },
        }),
        f.obj(&.{
            .{ "bits", f.n("8") },
            .{ "kind", f.s("int") },
            .{ "signedness", f.s("unsigned") },
        }),
    }) },
    .{ "returnType", f.obj(&.{
        .{ "kind", f.s("void") },
    }) },
    .{ "varArgs", f.b(false) },
});

pub const air_loops_program_7_input_79 = f.obj(&.{
    .{ "body", f.arr(&.{
        f.n("0"),
        f.n("1"),
        f.n("8"),
    }) },
    .{ "bodyTraversal", f.s("supported-structured-containers-only") },
    .{ "capturePoint", f.s("after-sema-before-legalize") },
    .{ "configuration", f.ref(&air_memory_program_2_input_configuration_14) },
    .{ "instructions", f.arr(&.{
        f.ref(&air_scalar_program_1_input_instructions_4),
        f.obj(&.{
            .{ "body", f.arr(&.{
                f.n("2"),
            }) },
            .{ "index", f.n("1") },
            .{ "payloadVisited", f.b(true) },
            .{ "tag", f.s("block") },
            .{ "type", f.obj(&.{
                .{ "bits", f.n("8") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("unsigned") },
            }) },
        }),
        f.obj(&.{
            .{ "body", f.arr(&.{
                f.n("3"),
                f.n("4"),
            }) },
            .{ "index", f.n("2") },
            .{ "payloadVisited", f.b(true) },
            .{ "tag", f.s("loop") },
            .{ "type", f.obj(&.{
                .{ "kind", f.s("noreturn") },
            }) },
        }),
        f.ref(&air_loops_program_7_input_instructions_81),
        f.obj(&.{
            .{ "condition", f.obj(&.{
                .{ "index", f.n("3") },
                .{ "kind", f.s("instruction") },
            }) },
            .{ "elseBody", f.arr(&.{
                f.n("7"),
            }) },
            .{ "index", f.n("4") },
            .{ "payloadVisited", f.b(true) },
            .{ "tag", f.s("cond_br") },
            .{ "thenBody", f.arr(&.{
                f.n("5"),
                f.n("6"),
            }) },
            .{ "type", f.obj(&.{
                .{ "kind", f.s("noreturn") },
            }) },
        }),
        f.ref(&air_loops_program_7_input_instructions_83),
        f.obj(&.{
            .{ "index", f.n("6") },
            .{ "payloadVisited", f.b(true) },
            .{ "tag", f.s("repeat") },
            .{ "target", f.n("2") },
            .{ "type", f.obj(&.{
                .{ "kind", f.s("noreturn") },
            }) },
        }),
        f.obj(&.{
            .{ "index", f.n("7") },
            .{ "operand", f.obj(&.{
                .{ "index", f.n("0") },
                .{ "kind", f.s("instruction") },
            }) },
            .{ "payloadVisited", f.b(true) },
            .{ "tag", f.s("br") },
            .{ "target", f.n("1") },
            .{ "type", f.obj(&.{
                .{ "kind", f.s("noreturn") },
            }) },
        }),
        f.obj(&.{
            .{ "index", f.n("8") },
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
    .{ "signature", f.ref(&air_scalar_program_1_input_signature_10) },
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
});

pub const air_loops_program_7_input_instructions_81 = f.obj(&.{
    .{ "index", f.n("3") },
    .{ "lhs", f.obj(&.{
        .{ "index", f.n("0") },
        .{ "kind", f.s("instruction") },
    }) },
    .{ "payloadVisited", f.b(true) },
    .{ "rhs", f.obj(&.{
        .{ "kind", f.s("constant") },
        .{ "type", f.obj(&.{
            .{ "bits", f.n("8") },
            .{ "kind", f.s("int") },
            .{ "signedness", f.s("unsigned") },
        }) },
        .{ "value", f.n("128") },
    }) },
    .{ "tag", f.s("cmp_lt") },
    .{ "type", f.obj(&.{
        .{ "kind", f.s("bool") },
    }) },
});

pub const air_loops_program_7_input_instructions_83 = f.obj(&.{
    .{ "index", f.n("5") },
    .{ "lhs", f.obj(&.{
        .{ "index", f.n("0") },
        .{ "kind", f.s("instruction") },
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
    .{ "tag", f.s("add") },
    .{ "type", f.obj(&.{
        .{ "bits", f.n("8") },
        .{ "kind", f.s("int") },
        .{ "signedness", f.s("unsigned") },
    }) },
});

pub const air_word_byte_loops_program_8_input_87 = f.obj(&.{
    .{ "body", f.arr(&.{
        f.n("0"),
        f.n("1"),
        f.n("7"),
    }) },
    .{ "bodyTraversal", f.s("supported-structured-containers-only") },
    .{ "capturePoint", f.s("after-sema-before-legalize") },
    .{ "configuration", f.ref(&air_memory_program_2_input_configuration_14) },
    .{ "instructions", f.ref(&air_scalar_program_1_input_instructions_3) },
    .{ "name", f.s("fixture.choose") },
    .{ "schema", f.s("oksolc.fresh-air.v3") },
    .{ "signature", f.ref(&air_scalar_program_1_input_signature_10) },
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
});

pub const air_scalar_program_12_input_98 = f.obj(&.{
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
                .{ "bits", f.n("0") },
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
            .{ "tag", f.s("bit_and") },
            .{ "type", f.obj(&.{
                .{ "bits", f.n("0") },
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
                .{ "bits", f.n("0") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("unsigned") },
            }),
        }) },
        .{ "returnType", f.obj(&.{
            .{ "bits", f.n("0") },
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
});

pub const air_memory_program_16_input_120 = f.obj(&.{
    .{ "body", f.arr(&.{
        f.n("0"),
        f.n("1"),
        f.n("2"),
        f.n("3"),
    }) },
    .{ "bodyTraversal", f.s("supported-structured-containers-only") },
    .{ "capturePoint", f.s("after-sema-before-legalize") },
    .{ "configuration", f.ref(&air_memory_program_2_input_configuration_14) },
    .{ "instructions", f.arr(&.{
        f.obj(&.{
            .{ "index", f.n("0") },
            .{ "payloadVisited", f.b(true) },
            .{ "tag", f.s("arg") },
            .{ "type", f.ref(&pointer_21) },
            .{ "zirParameterIndex", f.n("0") },
        }),
        f.ref(&air_memory_program_2_input_instructions_19),
        f.obj(&.{
            .{ "index", f.n("2") },
            .{ "lhs", f.obj(&.{
                .{ "index", f.n("1") },
                .{ "kind", f.s("instruction") },
            }) },
            .{ "payloadVisited", f.b(true) },
            .{ "rhs", f.obj(&.{
                .{ "index", f.n("1") },
                .{ "kind", f.s("instruction") },
            }) },
            .{ "tag", f.s("slice_elem_ptr") },
            .{ "type", f.ref(&pointer_124) },
        }),
        f.obj(&.{
            .{ "index", f.n("3") },
            .{ "operand", f.obj(&.{
                .{ "index", f.n("2") },
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
            f.ref(&pointer_21),
            f.obj(&.{
                .{ "bits", f.n("64") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("unsigned") },
            }),
        }) },
        .{ "returnType", f.ref(&pointer_124) },
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
});

pub const pointer_124 = f.obj(&.{
    .{ "child", f.obj(&.{
        .{ "bits", f.n("8") },
        .{ "kind", f.s("int") },
        .{ "signedness", f.s("unsigned") },
    }) },
    .{ "flags", f.ref(&air_word_bytes_program_6_input_instructions_type_flags_69) },
    .{ "kind", f.s("pointer") },
    .{ "layout", f.obj(&.{
        .{ "alignment", f.n("8") },
        .{ "bytes", f.n("8") },
        .{ "kind", f.s("abi") },
    }) },
    .{ "pointeeLayout", f.obj(&.{
        .{ "alignment", f.n("1") },
        .{ "bytes", f.n("1") },
        .{ "kind", f.s("abi") },
    }) },
    .{ "sentinel", .null },
});

pub const air_memory_program_17_input_128 = f.obj(&.{
    .{ "body", f.arr(&.{
        f.n("0"),
        f.n("1"),
        f.n("2"),
        f.n("3"),
    }) },
    .{ "bodyTraversal", f.s("supported-structured-containers-only") },
    .{ "capturePoint", f.s("after-sema-before-legalize") },
    .{ "configuration", f.ref(&air_memory_program_2_input_configuration_14) },
    .{ "instructions", f.ref(&air_memory_program_2_input_instructions_15) },
    .{ "name", f.s("fixture.choose") },
    .{ "schema", f.s("oksolc.fresh-air.v3") },
    .{ "signature", f.ref(&air_memory_program_2_input_signature_24) },
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
        .{ "slices", f.arr(&.{
            f.ref(&air_memory_program_2_input_sourcevalidity_slices_28),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
            f.obj(&.{}),
        }) },
    }) },
    .{ "sourceValidityConditionsPreserved", f.b(false) },
});

pub const air_memory_program_19_input_instructions_135 = f.obj(&.{
    .{ "index", f.n("10") },
    .{ "lhs", f.obj(&.{
        .{ "index", f.n("9") },
        .{ "kind", f.s("instruction") },
    }) },
    .{ "payloadVisited", f.b(true) },
    .{ "rhs", f.obj(&.{
        .{ "index", f.n("2") },
        .{ "kind", f.s("instruction") },
    }) },
    .{ "tag", f.s("store") },
    .{ "type", f.obj(&.{
        .{ "kind", f.s("void") },
    }) },
});

pub const air_loops_program_22_input_143 = f.obj(&.{
    .{ "body", f.arr(&.{
        f.n("0"),
        f.n("1"),
        f.n("8"),
    }) },
    .{ "bodyTraversal", f.s("supported-structured-containers-only") },
    .{ "capturePoint", f.s("after-sema-before-legalize") },
    .{ "configuration", f.ref(&air_memory_program_2_input_configuration_14) },
    .{ "instructions", f.arr(&.{
        f.ref(&air_scalar_program_1_input_instructions_4),
        f.obj(&.{
            .{ "body", f.arr(&.{
                f.n("2"),
            }) },
            .{ "index", f.n("1") },
            .{ "payloadVisited", f.b(true) },
            .{ "tag", f.s("block") },
            .{ "type", f.obj(&.{
                .{ "bits", f.n("8") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("unsigned") },
            }) },
        }),
        f.obj(&.{
            .{ "body", f.arr(&.{
                f.n("9"),
            }) },
            .{ "index", f.n("2") },
            .{ "payloadVisited", f.b(true) },
            .{ "tag", f.s("loop") },
            .{ "type", f.obj(&.{
                .{ "kind", f.s("noreturn") },
            }) },
        }),
        f.ref(&air_loops_program_7_input_instructions_81),
        f.obj(&.{
            .{ "condition", f.obj(&.{
                .{ "index", f.n("3") },
                .{ "kind", f.s("instruction") },
            }) },
            .{ "elseBody", f.arr(&.{
                f.n("10"),
            }) },
            .{ "index", f.n("4") },
            .{ "payloadVisited", f.b(true) },
            .{ "tag", f.s("cond_br") },
            .{ "thenBody", f.arr(&.{
                f.n("5"),
                f.n("6"),
            }) },
            .{ "type", f.obj(&.{
                .{ "kind", f.s("noreturn") },
            }) },
        }),
        f.ref(&air_loops_program_7_input_instructions_83),
        f.obj(&.{
            .{ "index", f.n("6") },
            .{ "payloadVisited", f.b(true) },
            .{ "tag", f.s("repeat") },
            .{ "target", f.n("2") },
            .{ "type", f.obj(&.{
                .{ "kind", f.s("noreturn") },
            }) },
        }),
        f.obj(&.{
            .{ "index", f.n("7") },
            .{ "payloadVisited", f.b(false) },
            .{ "reason", f.s("outside-decoded-body-closure") },
            .{ "tag", f.s("br") },
            .{ "unsupportedPayload", f.b(true) },
        }),
        f.obj(&.{
            .{ "index", f.n("8") },
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
        f.obj(&.{
            .{ "body", f.arr(&.{
                f.n("3"),
                f.n("4"),
            }) },
            .{ "index", f.n("9") },
            .{ "payloadVisited", f.b(true) },
            .{ "tag", f.s("loop") },
            .{ "type", f.obj(&.{
                .{ "kind", f.s("noreturn") },
            }) },
        }),
        f.obj(&.{
            .{ "index", f.n("10") },
            .{ "payloadVisited", f.b(true) },
            .{ "tag", f.s("repeat") },
            .{ "target", f.n("9") },
            .{ "type", f.obj(&.{
                .{ "kind", f.s("noreturn") },
            }) },
        }),
    }) },
    .{ "name", f.s("fixture.choose") },
    .{ "schema", f.s("oksolc.fresh-air.v3") },
    .{ "signature", f.ref(&air_scalar_program_1_input_signature_10) },
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
});

pub const air_memory_program_23_input_148 = f.obj(&.{
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
    .{ "instructions", f.ref(&air_memory_program_23_input_instructions_149) },
    .{ "name", f.s("mem.swap__anon_1") },
    .{ "schema", f.s("oksolc.fresh-air.v3") },
    .{ "signature", f.obj(&.{
        .{ "callingConvention", f.s("auto") },
        .{ "genericInstance", f.b(true) },
        .{ "noaliasBits", f.n("3") },
        .{ "parameters", f.ref(&air_memory_program_23_input_signature_parameters_153) },
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
    .{ "specialization", f.ref(&air_memory_program_23_input_specialization_154) },
});

pub const air_memory_program_23_input_instructions_149 = f.arr(&.{
    f.obj(&.{
        .{ "index", f.n("0") },
        .{ "payloadVisited", f.b(true) },
        .{ "tag", f.s("arg") },
        .{ "type", f.ref(&pointer_56) },
        .{ "zirParameterIndex", f.n("1") },
    }),
    f.obj(&.{
        .{ "index", f.n("1") },
        .{ "payloadVisited", f.b(true) },
        .{ "tag", f.s("arg") },
        .{ "type", f.ref(&pointer_56) },
        .{ "zirParameterIndex", f.n("2") },
    }),
    f.obj(&.{
        .{ "index", f.n("2") },
        .{ "operand", f.obj(&.{
            .{ "kind", f.s("unit") },
        }) },
        .{ "payloadVisited", f.b(true) },
        .{ "tag", f.s("ret") },
        .{ "type", f.obj(&.{
            .{ "kind", f.s("noreturn") },
        }) },
    }),
});

pub const air_memory_program_23_input_signature_parameters_153 = f.arr(&.{
    f.ref(&pointer_56),
    f.ref(&pointer_56),
});

pub const air_memory_program_23_input_specialization_154 = f.obj(&.{
    .{ "arguments", f.arr(&.{
        f.obj(&.{
            .{ "kind", f.s("type") },
            .{ "value", f.obj(&.{
                .{ "bits", f.n("32") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("unsigned") },
            }) },
        }),
        f.obj(&.{
            .{ "kind", f.s("runtime") },
            .{ "runtimeIndex", f.n("0") },
        }),
        f.obj(&.{
            .{ "kind", f.s("runtime") },
            .{ "runtimeIndex", f.n("1") },
        }),
    }) },
    .{ "owner", f.ref(&air_memory_program_23_input_specialization_owner_156) },
    .{ "schema", f.s("oksolc.generic-instance.v1") },
    .{ "sourceComptimeBits", f.n("1") },
    .{ "sourceNoaliasBits", f.n("6") },
    .{ "sourceParameterCount", f.n("3") },
});

pub const air_memory_program_23_input_specialization_owner_156 = f.obj(&.{
    .{ "name", f.s("mem.swap") },
    .{ "sourceFile", f.s("mem.zig") },
    .{ "sourceSha256", f.s("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb") },
});

pub const air_input_instructions_8_164 = f.obj(&.{
    .{ "body", f.arr(&.{
        f.n("0"),
    }) },
    .{ "index", f.n("8") },
    .{ "payloadVisited", f.b(false) },
    .{ "reason", f.s("outside-decoded-body-closure") },
    .{ "tag", f.s("block") },
    .{ "unsupportedPayload", f.b(true) },
});

pub const air_input_instructions_9_193 = f.obj(&.{
    .{ "body", f.arr(&.{
        f.n("10"),
        f.n("11"),
    }) },
    .{ "index", f.n("9") },
    .{ "payloadVisited", f.b(true) },
    .{ "tag", f.s("block") },
    .{ "type", f.ref(&pointer_194) },
});

pub const pointer_194 = f.obj(&.{
    .{ "child", f.obj(&.{
        .{ "bits", f.n("8") },
        .{ "kind", f.s("int") },
        .{ "signedness", f.s("unsigned") },
    }) },
    .{ "flags", f.ref(&air_aggregate_program_4_input_instructions_type_flags_41) },
    .{ "kind", f.s("pointer") },
    .{ "layout", f.obj(&.{
        .{ "alignment", f.n("8") },
        .{ "bytes", f.n("8") },
        .{ "kind", f.s("abi") },
    }) },
    .{ "pointeeLayout", f.obj(&.{
        .{ "alignment", f.n("1") },
        .{ "bytes", f.n("1") },
        .{ "kind", f.s("abi") },
    }) },
    .{ "sentinel", .null },
});

pub const air_input_instructions_10_195 = f.obj(&.{
    .{ "index", f.n("10") },
    .{ "lhs", f.obj(&.{
        .{ "index", f.n("8") },
        .{ "kind", f.s("instruction") },
    }) },
    .{ "payloadVisited", f.b(true) },
    .{ "rhs", f.obj(&.{
        .{ "index", f.n("1") },
        .{ "kind", f.s("instruction") },
    }) },
    .{ "tag", f.s("slice_elem_ptr") },
    .{ "type", f.ref(&pointer_194) },
});

pub const air_input_instructions_11_196 = f.obj(&.{
    .{ "index", f.n("11") },
    .{ "operand", f.obj(&.{
        .{ "index", f.n("10") },
        .{ "kind", f.s("instruction") },
    }) },
    .{ "payloadVisited", f.b(true) },
    .{ "tag", f.s("br") },
    .{ "target", f.n("9") },
    .{ "type", f.obj(&.{
        .{ "kind", f.s("noreturn") },
    }) },
});

pub const air_input_instructions_12_197 = f.obj(&.{
    .{ "index", f.n("12") },
    .{ "lhs", f.obj(&.{
        .{ "index", f.n("9") },
        .{ "kind", f.s("instruction") },
    }) },
    .{ "payloadVisited", f.b(true) },
    .{ "rhs", f.obj(&.{
        .{ "index", f.n("2") },
        .{ "kind", f.s("instruction") },
    }) },
    .{ "tag", f.s("store") },
    .{ "type", f.obj(&.{
        .{ "kind", f.s("void") },
    }) },
});

pub const audit_validity_1_input_sourcevalidity_slices_203 = f.obj(&.{
    .{ "anchor", f.obj(&.{
        .{ "inSupportedBody", f.b(true) },
        .{ "index", f.n("2") },
        .{ "kind", f.s("beforeInstruction") },
    }) },
    .{ "end", f.obj(&.{
        .{ "index", f.n("1") },
        .{ "kind", f.s("instruction") },
    }) },
    .{ "source", f.obj(&.{
        .{ "file", f.s("audit-oracle-source.zig") },
        .{ "sha256", f.s("808f4ea8be1165e0bb264561bf629575302772390a6e75eefe914f27f32a016c") },
        .{ "span", f.obj(&.{
            .{ "end", f.n("2") },
            .{ "main", f.n("1") },
            .{ "start", f.n("0") },
        }) },
    }) },
    .{ "start", f.obj(&.{
        .{ "kind", f.s("constant") },
        .{ "type", f.obj(&.{
            .{ "bits", f.n("64") },
            .{ "kind", f.s("int") },
            .{ "signedness", f.s("unsigned") },
        }) },
        .{ "value", f.n("0") },
    }) },
    .{ "unsupportedReason", .null },
    .{ "upperBound", f.obj(&.{
        .{ "kind", f.s("unboundedPointer") },
        .{ "requiresMemoryValidity", f.b(true) },
    }) },
});

pub const audit_validity_1_source_205 = f.repeat(0x73, 16384);

pub const pointer_216 = f.obj(&.{
    .{ "child", f.obj(&.{
        .{ "bits", f.n("32") },
        .{ "kind", f.s("int") },
        .{ "signedness", f.s("unsigned") },
    }) },
    .{ "flags", f.ref(&audit_signatures_2_input_buffer_alias_signature_parameters_flags_217) },
    .{ "kind", f.s("pointer") },
    .{ "layout", f.obj(&.{
        .{ "alignment", f.n("8") },
        .{ "bytes", f.n("8") },
        .{ "kind", f.s("abi") },
    }) },
    .{ "pointeeLayout", f.obj(&.{
        .{ "alignment", f.n("4") },
        .{ "bytes", f.n("4") },
        .{ "kind", f.s("abi") },
    }) },
    .{ "sentinel", .null },
});

pub const audit_signatures_2_input_buffer_alias_signature_parameters_flags_217 = f.obj(&.{
    .{ "addressSpace", f.s("generic") },
    .{ "alignment", .null },
    .{ "allowZero", f.b(false) },
    .{ "bitOffset", f.n("0") },
    .{ "hostSizeBytes", f.n("0") },
    .{ "isConst", f.b(false) },
    .{ "isVolatile", f.b(false) },
    .{ "size", f.s("many") },
    .{ "vectorIndex", .null },
});

pub const audit_signatures_2_input_initialize_length_218 = f.obj(&.{
    .{ "signature", f.obj(&.{
        .{ "parameters", f.arr(&.{
            f.ref(&pointer_221),
            f.obj(&.{
                .{ "bits", f.n("64") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("unsigned") },
            }),
        }) },
    }) },
});

pub const pointer_221 = f.obj(&.{
    .{ "child", f.obj(&.{
        .{ "child", f.obj(&.{
            .{ "bits", f.n("8") },
            .{ "kind", f.s("int") },
            .{ "signedness", f.s("unsigned") },
        }) },
        .{ "flags", f.obj(&.{
            .{ "addressSpace", f.s("generic") },
            .{ "alignment", .null },
            .{ "allowZero", f.b(false) },
            .{ "bitOffset", f.n("0") },
            .{ "hostSizeBytes", f.n("0") },
            .{ "isConst", f.b(false) },
            .{ "isVolatile", f.b(false) },
            .{ "size", f.s("slice") },
            .{ "vectorIndex", .null },
        }) },
        .{ "kind", f.s("pointer") },
        .{ "layout", f.obj(&.{
            .{ "alignment", f.n("8") },
            .{ "bytes", f.n("16") },
            .{ "kind", f.s("abi") },
        }) },
        .{ "pointeeLayout", f.obj(&.{
            .{ "alignment", f.n("1") },
            .{ "bytes", f.n("1") },
            .{ "kind", f.s("abi") },
        }) },
        .{ "sentinel", .null },
    }) },
    .{ "flags", f.ref(&air_aggregate_program_4_input_instructions_type_flags_41) },
    .{ "kind", f.s("pointer") },
    .{ "layout", f.obj(&.{
        .{ "alignment", f.n("8") },
        .{ "bytes", f.n("8") },
        .{ "kind", f.s("abi") },
    }) },
    .{ "pointeeLayout", f.obj(&.{
        .{ "alignment", f.n("8") },
        .{ "bytes", f.n("16") },
        .{ "kind", f.s("abi") },
    }) },
    .{ "sentinel", .null },
});

pub const struct_274 = f.obj(&.{
    .{ "containerLayout", f.s("auto") },
    .{ "fields", f.ref(&air_aggregate_program_4_input_instructions_type_child_fields_39) },
    .{ "identity", f.ref(&audit_input_instructions_1_type_child_identity_275) },
    .{ "kind", f.s("struct") },
    .{ "layout", f.obj(&.{
        .{ "alignment", f.n("8") },
        .{ "bytes", f.n("16") },
        .{ "kind", f.s("abi") },
    }) },
});

pub const audit_input_instructions_1_type_child_identity_275 = f.obj(&.{
    .{ "name", f.s("fixture.Pair") },
    .{ "sourceFile", f.s("audit-oracle-source.zig") },
    .{ "sourceSha256", f.s("808f4ea8be1165e0bb264561bf629575302772390a6e75eefe914f27f32a016c") },
});

pub const capture_fixture_0_files_root_json_281 = f.s("{\"schema\": \"oksolc.fresh-air.v3\", \"capturePoint\": \"after-sema-before-legalize\", \"name\": \"fixture.add\", \"sourceSha256\": \"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\", \"sourceValidityConditionsPreserved\": false, \"sourceValidity\": {\"schema\": \"oksolc.source-validity.v1\", \"coverage\": \"runtime-slice-results\", \"complete\": false, \"slices\": []}, \"sourceOperationTags\": [\"addwrap\", \"ret_node\"], \"configuration\": {\"optimize\": \"ReleaseFast\", \"useLlvm\": true, \"isTest\": false}, \"body\": [0], \"instructions\": [{\"index\": 0, \"tag\": \"future_opcode\", \"unsupportedPayload\": true}]}");

pub const hash_caller_hash_initialization_0_bundle_caller_configuration_293 = f.obj(&.{
    .{ "optimize", f.s("ReleaseFast") },
    .{ "useLlvm", f.b(true) },
    .{ "isTest", f.b(false) },
    .{ "arch", f.s("aarch64") },
    .{ "os", f.s("macos") },
    .{ "pointerBits", f.n("64") },
    .{ "endianness", f.s("little") },
});

pub const hash_caller_hash_initialization_0_bundle_caller_instructions_type_flags_312 = f.obj(&.{
    .{ "size", f.s("one") },
    .{ "alignment", .null },
    .{ "isConst", f.b(false) },
    .{ "isVolatile", f.b(false) },
    .{ "allowZero", f.b(false) },
    .{ "addressSpace", f.s("generic") },
    .{ "vectorIndex", .null },
    .{ "hostSizeBytes", f.n("0") },
    .{ "bitOffset", f.n("0") },
});

pub const link_fixture_0_records_mem_swap_anon_1_signature_parameters_565 = f.arr(&.{
    f.ref(&pointer_566),
    f.ref(&pointer_566),
});

pub const pointer_566 = f.obj(&.{
    .{ "kind", f.s("pointer") },
    .{ "child", f.obj(&.{
        .{ "kind", f.s("int") },
        .{ "bits", f.n("32") },
        .{ "signedness", f.s("unsigned") },
    }) },
    .{ "sentinel", .null },
    .{ "layout", f.obj(&.{
        .{ "kind", f.s("abi") },
        .{ "bytes", f.n("8") },
        .{ "alignment", f.n("8") },
    }) },
    .{ "pointeeLayout", f.obj(&.{
        .{ "kind", f.s("abi") },
        .{ "bytes", f.n("4") },
        .{ "alignment", f.n("4") },
    }) },
    .{ "flags", f.ref(&hash_caller_hash_initialization_0_bundle_caller_instructions_type_flags_312) },
});

pub const link_fixture_0_records_mem_swap_anon_1_instructions_567 = f.arr(&.{
    f.obj(&.{
        .{ "index", f.n("0") },
        .{ "tag", f.s("arg") },
        .{ "type", f.ref(&pointer_566) },
        .{ "payloadVisited", f.b(true) },
        .{ "zirParameterIndex", f.n("1") },
    }),
    f.obj(&.{
        .{ "index", f.n("1") },
        .{ "tag", f.s("arg") },
        .{ "type", f.ref(&pointer_566) },
        .{ "payloadVisited", f.b(true) },
        .{ "zirParameterIndex", f.n("2") },
    }),
    f.obj(&.{
        .{ "index", f.n("2") },
        .{ "tag", f.s("ret") },
        .{ "type", f.obj(&.{
            .{ "kind", f.s("noreturn") },
        }) },
        .{ "payloadVisited", f.b(true) },
        .{ "operand", f.obj(&.{
            .{ "kind", f.s("unit") },
        }) },
    }),
});

pub const link_fixture_0_records_mem_swap_anon_1_specialization_570 = f.obj(&.{
    .{ "schema", f.s("oksolc.generic-instance.v1") },
    .{ "owner", f.ref(&air_memory_program_23_input_specialization_owner_156) },
    .{ "sourceNoaliasBits", f.n("6") },
    .{ "sourceComptimeBits", f.n("1") },
    .{ "sourceParameterCount", f.n("3") },
    .{ "arguments", f.arr(&.{
        f.obj(&.{
            .{ "kind", f.s("type") },
            .{ "value", f.obj(&.{
                .{ "kind", f.s("int") },
                .{ "bits", f.n("32") },
                .{ "signedness", f.s("unsigned") },
            }) },
        }),
        f.obj(&.{
            .{ "kind", f.s("runtime") },
            .{ "runtimeIndex", f.n("0") },
        }),
        f.obj(&.{
            .{ "kind", f.s("runtime") },
            .{ "runtimeIndex", f.n("1") },
        }),
    }) },
});

pub const link_fixture_0_sources_580 = f.obj(&.{
    .{ "fixture.zig", f.s("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") },
    .{ "mem.zig", f.s("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb") },
});
