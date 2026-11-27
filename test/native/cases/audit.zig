// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
// Immutable reference controls with shared fixtures and explicit mutations.
const f = @import("../fixtures.zig");
const shared = @import("shared.zig");
const golden = @import("golden.zig");

const memory_0 = f.obj(&.{
    .{ "input", f.ref(&shared.air_scalar_program_1_input_2) },
    .{ "kind", f.s("memory") },
    .{ "output", f.obj(&.{}) },
    .{ "reject", f.b(false) },
});

const validity_1 = f.obj(&.{
    .{ "basename", f.s("audit-oracle-source.zig") },
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
        .{ "instructions", f.ref(&shared.air_memory_program_2_input_instructions_15) },
        .{ "name", f.s("fixture.choose") },
        .{ "schema", f.s("oksolc.fresh-air.v3") },
        .{ "signature", f.ref(&shared.air_memory_program_2_input_signature_24) },
        .{ "sourceFile", f.s("audit-oracle-source.zig") },
        .{ "sourceOperationTags", f.arr(&.{
            f.s("add"),
            f.s("ret_node"),
        }) },
        .{ "sourceSha256", f.s("808f4ea8be1165e0bb264561bf629575302772390a6e75eefe914f27f32a016c") },
        .{ "sourceValidity", f.obj(&.{
            .{ "complete", f.b(false) },
            .{ "coverage", f.s("runtime-slice-results") },
            .{ "schema", f.s("oksolc.source-validity.v1") },
            .{ "slices", f.arr(&.{
                f.ref(&shared.audit_validity_1_input_sourcevalidity_slices_203),
            }) },
        }) },
        .{ "sourceValidityConditionsPreserved", f.b(false) },
    }) },
    .{ "kind", f.s("validity") },
    .{ "output", f.arr(&.{
        f.obj(&.{
            .{ "anchor", f.n("2") },
            .{ "bound", f.s("unboundedPointer") },
            .{ "path", f.arr(&.{}) },
            .{ "source", f.s("ss") },
            .{ "unsupported", .null },
        }),
    }) },
    .{ "reject", f.b(false) },
    .{ "source", f.ref(&shared.audit_validity_1_source_205) },
});

const signatures_2 = f.obj(&.{
    .{ "input", f.obj(&.{
        .{ "allow_zero", f.obj(&.{
            .{ "signature", f.obj(&.{
                .{ "parameters", f.arr(&.{
                    f.obj(&.{
                        .{ "child", f.obj(&.{
                            .{ "bits", f.n("8") },
                            .{ "kind", f.s("int") },
                            .{ "signedness", f.s("unsigned") },
                        }) },
                        .{ "flags", f.obj(&.{
                            .{ "addressSpace", f.s("generic") },
                            .{ "alignment", .null },
                            .{ "allowZero", f.b(true) },
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
                    }),
                }) },
            }) },
        }) },
        .{ "buffer_alias", f.obj(&.{
            .{ "signature", f.obj(&.{
                .{ "parameters", f.arr(&.{
                    f.ref(&shared.pointer_216),
                    f.obj(&.{
                        .{ "bits", f.n("64") },
                        .{ "kind", f.s("int") },
                        .{ "signedness", f.s("unsigned") },
                    }),
                    f.obj(&.{
                        .{ "bits", f.n("32") },
                        .{ "kind", f.s("int") },
                        .{ "signedness", f.s("unsigned") },
                    }),
                    f.obj(&.{
                        .{ "bits", f.n("32") },
                        .{ "kind", f.s("int") },
                        .{ "signedness", f.s("unsigned") },
                    }),
                }) },
            }) },
        }) },
        .{ "initialize_length", f.ref(&shared.audit_signatures_2_input_initialize_length_218) },
        .{ "initialize_slice", f.obj(&.{
            .{ "signature", f.obj(&.{
                .{ "parameters", f.arr(&.{
                    f.ref(&shared.pointer_221),
                    f.obj(&.{
                        .{ "child", f.obj(&.{
                            .{ "bits", f.n("8") },
                            .{ "kind", f.s("int") },
                            .{ "signedness", f.s("unsigned") },
                        }) },
                        .{ "flags", f.ref(&shared.audit_signatures_2_input_buffer_alias_signature_parameters_flags_217) },
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
                    }),
                    f.obj(&.{
                        .{ "bits", f.n("64") },
                        .{ "kind", f.s("int") },
                        .{ "signedness", f.s("unsigned") },
                    }),
                }) },
            }) },
        }) },
        .{ "load_store", f.obj(&.{
            .{ "signature", f.obj(&.{
                .{ "parameters", f.arr(&.{
                    f.ref(&shared.pointer_56),
                    f.obj(&.{
                        .{ "bits", f.n("32") },
                        .{ "kind", f.s("int") },
                        .{ "signedness", f.s("unsigned") },
                    }),
                }) },
            }) },
        }) },
        .{ "move_back", f.obj(&.{
            .{ "signature", f.obj(&.{
                .{ "parameters", f.arr(&.{
                    f.ref(&shared.pointer_216),
                    f.obj(&.{
                        .{ "bits", f.n("64") },
                        .{ "kind", f.s("int") },
                        .{ "signedness", f.s("unsigned") },
                    }),
                }) },
            }) },
        }) },
        .{ "opaque_pointer", f.obj(&.{
            .{ "signature", f.obj(&.{
                .{ "parameters", f.arr(&.{
                    f.obj(&.{
                        .{ "child", f.obj(&.{
                            .{ "kind", f.s("unsupported") },
                            .{ "zigTypeTag", f.s("opaque") },
                        }) },
                        .{ "flags", f.ref(&shared.air_aggregate_program_4_input_instructions_type_flags_41) },
                        .{ "kind", f.s("pointer") },
                        .{ "layout", f.obj(&.{
                            .{ "alignment", f.n("8") },
                            .{ "bytes", f.n("8") },
                            .{ "kind", f.s("abi") },
                        }) },
                        .{ "pointeeLayout", f.obj(&.{
                            .{ "kind", f.s("unsupported") },
                            .{ "reason", f.s("non-scalar-layout") },
                        }) },
                        .{ "sentinel", .null },
                    }),
                }) },
            }) },
        }) },
        .{ "packed_pointer", f.obj(&.{
            .{ "signature", f.obj(&.{
                .{ "parameters", f.arr(&.{
                    f.obj(&.{
                        .{ "child", f.obj(&.{
                            .{ "bits", f.n("3") },
                            .{ "kind", f.s("int") },
                            .{ "signedness", f.s("unsigned") },
                        }) },
                        .{ "flags", f.obj(&.{
                            .{ "addressSpace", f.s("generic") },
                            .{ "alignment", f.n("1") },
                            .{ "allowZero", f.b(false) },
                            .{ "bitOffset", f.n("3") },
                            .{ "hostSizeBytes", f.n("1") },
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
                    }),
                }) },
            }) },
        }) },
        .{ "slice_fields", f.ref(&shared.audit_signatures_2_input_initialize_length_218) },
        .{ "unaligned_volatile", f.obj(&.{
            .{ "signature", f.obj(&.{
                .{ "parameters", f.arr(&.{
                    f.obj(&.{
                        .{ "child", f.obj(&.{
                            .{ "bits", f.n("32") },
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
                            .{ "isVolatile", f.b(true) },
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
                            .{ "alignment", f.n("4") },
                            .{ "bytes", f.n("4") },
                            .{ "kind", f.s("abi") },
                        }) },
                        .{ "sentinel", .null },
                    }),
                }) },
            }) },
        }) },
        .{ "undefined_store", f.obj(&.{
            .{ "signature", f.obj(&.{
                .{ "parameters", f.arr(&.{
                    f.ref(&shared.pointer_56),
                }) },
            }) },
        }) },
    }) },
    .{ "kind", f.s("signatures") },
    .{ "output", .null },
    .{ "reject", f.b(false) },
});

const memory_3 = f.obj(&.{
    .{ "input", f.ref(&shared.air_scalar_program_12_input_98) },
    .{ "kind", f.s("memory") },
    .{ "output", f.obj(&.{}) },
    .{ "reject", f.b(false) },
});

const memory_4 = f.obj(&.{
    .{ "input", f.ref(&shared.air_memory_program_2_input_13) },
    .{ "kind", f.s("memory") },
    .{ "output", f.obj(&.{
        .{ "slice", f.n("1") },
    }) },
    .{ "reject", f.b(false) },
});

const memory_5 = f.obj(&.{
    .{ "input", f.ref(&shared.air_memory_program_16_input_120) },
    .{ "kind", f.s("memory") },
    .{ "reject", f.b(true) },
});

const memory_6 = f.obj(&.{
    .{ "input", f.ref(&shared.air_memory_program_17_input_128) },
    .{ "kind", f.s("memory") },
    .{ "output", f.obj(&.{
        .{ "slice", f.n("1") },
    }) },
    .{ "reject", f.b(false) },
});

const validity_7 = f.obj(&.{
    .{ "basename", f.s("audit-oracle-source.zig") },
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
        .{ "instructions", f.ref(&shared.air_memory_program_2_input_instructions_15) },
        .{ "name", f.s("fixture.choose") },
        .{ "schema", f.s("oksolc.fresh-air.v3") },
        .{ "signature", f.ref(&shared.air_memory_program_2_input_signature_24) },
        .{ "sourceFile", f.s("audit-oracle-source.zig") },
        .{ "sourceOperationTags", f.arr(&.{
            f.s("add"),
            f.s("ret_node"),
        }) },
        .{ "sourceSha256", f.s("808f4ea8be1165e0bb264561bf629575302772390a6e75eefe914f27f32a016c") },
        .{ "sourceValidity", f.obj(&.{
            .{ "complete", f.b(false) },
            .{ "coverage", f.s("runtime-slice-results") },
            .{ "schema", f.s("oksolc.source-validity.v1") },
            .{ "slices", f.arr(&.{
                f.ref(&shared.audit_validity_1_input_sourcevalidity_slices_203),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
                f.obj(&.{}),
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
    }) },
    .{ "kind", f.s("validity") },
    .{ "reject", f.b(true) },
    .{ "source", f.ref(&shared.audit_validity_1_source_205) },
});

const memory_8 = f.obj(&.{
    .{ "input", f.ref(&shared.air_aggregate_program_4_input_33) },
    .{ "kind", f.s("memory") },
    .{ "reject", f.b(true) },
});

const memory_9 = f.obj(&.{
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
            f.obj(&.{
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
                    .{ "flags", f.obj(&.{
                        .{ "addressSpace", f.s("generic") },
                        .{ "alignment", f.n("0") },
                        .{ "allowZero", f.b(false) },
                        .{ "bitOffset", f.n("0") },
                        .{ "hostSizeBytes", f.n("0") },
                        .{ "isConst", f.b(false) },
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
                }) },
            }),
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
    .{ "kind", f.s("memory") },
    .{ "reject", f.b(true) },
});

const memory_10 = f.obj(&.{
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
            f.n("12"),
            f.n("13"),
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
            f.ref(&shared.air_input_instructions_9_193),
            f.ref(&shared.air_input_instructions_10_195),
            f.ref(&shared.air_input_instructions_11_196),
            f.ref(&shared.air_input_instructions_12_197),
            f.obj(&.{
                .{ "index", f.n("13") },
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
    .{ "kind", f.s("memory") },
    .{ "reject", f.b(true) },
});

const memory_11 = f.obj(&.{
    .{ "input", f.ref(&shared.air_loops_program_7_input_79) },
    .{ "kind", f.s("memory") },
    .{ "output", f.obj(&.{}) },
    .{ "reject", f.b(false) },
});

const memory_12 = f.obj(&.{
    .{ "input", f.ref(&shared.air_loops_program_22_input_143) },
    .{ "kind", f.s("memory") },
    .{ "output", f.obj(&.{}) },
    .{ "reject", f.b(false) },
});

const memory_13 = f.obj(&.{
    .{ "input", f.ref(&shared.air_memory_program_23_input_148) },
    .{ "kind", f.s("memory") },
    .{ "output", f.obj(&.{}) },
    .{ "reject", f.b(false) },
});

pub const cases = blk: {
    @setEvalBranchQuota(50_000);
    break :blk [_]f.Value{
        // Control 0
        f.ref(&memory_0),
        // Control 1
        f.derive(&memory_0, &.{
            f.set("/input/instructions/4/tag", f.s("sub")),
        }),
        // Control 2
        f.derive(&memory_0, &.{
            f.set("/input/instructions/4/tag", f.s("add_safe")),
        }),
        // Control 3
        f.derive(&memory_0, &.{
            f.set("/input/instructions/4/tag", f.s("add_wrap")),
        }),
        // Control 4
        f.derive(&memory_0, &.{
            f.add("/input/body/3", f.n("7")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 5
        f.derive(&memory_0, &.{
            f.add("/input/body/1", f.n("0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 6
        f.derive(&memory_0, &.{
            f.remove("/input/body/2"),
        }),
        // Control 7
        f.derive(&memory_0, &.{
            f.remove("/input/body/2"),
            f.remove("/input/body/1"),
            f.remove("/input/body/0"),
        }),
        // Control 8
        f.derive(&memory_0, &.{
            f.remove("/input/body/2"),
            f.remove("/input/body/1"),
            f.remove("/input/body/0"),
            f.add("/input/body/0", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 9
        f.derive(&memory_0, &.{
            f.remove("/input/body/2"),
            f.remove("/input/body/1"),
            f.remove("/input/body/0"),
            f.add("/input/body/0", f.n("8")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 10
        f.derive(&memory_0, &.{
            f.remove("/input/instructions/3/elseBody/0"),
            f.add("/input/instructions/3/elseBody/0", f.n("4")),
            f.add("/input/instructions/3/elseBody/1", f.n("5")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 11
        f.derive(&memory_0, &.{
            f.set("/input/instructions/5/operand/index", f.n("0")),
        }),
        // Control 12
        f.derive(&memory_0, &.{
            f.set("/input/instructions/4/lhs/index", f.n("4")),
        }),
        // Control 13
        f.derive(&memory_0, &.{
            f.set("/input/instructions/6/operand/index", f.n("4")),
        }),
        // Control 14
        f.derive(&memory_0, &.{
            f.set("/input/instructions/7/operand/index", f.n("2")),
        }),
        // Control 15
        f.derive(&memory_0, &.{
            f.set("/input/instructions/5/target", f.n("0")),
        }),
        // Control 16
        f.derive(&memory_0, &.{
            f.set("/input/instructions/5/target", f.n("5")),
        }),
        // Control 17
        f.derive(&memory_0, &.{
            f.set("/input/instructions/5/target", f.n("7")),
        }),
        // Control 18
        f.derive(&memory_0, &.{
            f.set("/input/instructions/5/target", f.b(true)),
        }),
        // Control 19
        f.derive(&memory_0, &.{
            f.set("/input/instructions/5/target", f.n("-1")),
        }),
        // Control 20
        f.derive(&memory_0, &.{
            f.set("/input/instructions/5/target", f.n("8")),
        }),
        // Control 21
        f.derive(&memory_0, &.{
            f.set("/input/name", f.s("numeric.u2s")),
        }),
        // Control 22
        f.derive(&memory_0, &.{
            f.set("/input/name", f.s("numeric.s2u")),
        }),
        // Control 23
        f.derive(&memory_0, &.{
            f.remove("/input/instructions/4/type/bits"),
            f.set("/input/instructions/4/type/kind", f.s("void")),
            f.remove("/input/instructions/4/type/signedness"),
        }),
        // Control 24
        f.derive(&memory_0, &.{
            f.remove("/input/instructions/5/operand/index"),
            f.set("/input/instructions/5/operand/kind", f.s("unit")),
        }),
        // Control 25
        f.derive(&memory_0, &.{
            f.set("/input/instructions/3/condition/index", f.n("0")),
        }),
        // Control 26
        f.derive(&memory_0, &.{
            f.remove("/input/instructions/7/operand/index"),
            f.set("/input/instructions/7/operand/kind", f.s("unit")),
        }),
        // Control 27
        f.derive(&memory_0, &.{
            f.remove("/input/signature/parameters/0/bits"),
            f.set("/input/signature/parameters/0/kind", f.s("void")),
            f.remove("/input/signature/parameters/0/signedness"),
        }),
        // Control 28
        f.derive(&memory_0, &.{
            f.set("/input/signature/noaliasBits", f.b(true)),
        }),
        // Control 29
        f.derive(&memory_0, &.{
            f.set("/input/signature/varArgs", f.b(true)),
        }),
        // Control 30
        f.derive(&memory_0, &.{
            f.set("/input/signature/genericInstance", f.b(true)),
        }),
        // Control 31
        f.derive(&memory_0, &.{
            f.set("/input/instructions/0/zirParameterIndex", f.n("1")),
        }),
        // Control 32
        f.derive(&memory_0, &.{
            f.set("/input/instructions/4/tag", f.s("future")),
        }),
        // Control 33
        f.derive(&memory_0, &.{
            f.set("/input/instructions/4/tag", f.s("load")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 34
        f.derive(&memory_0, &.{
            f.set("/input/instructions/4/tag", f.s("store")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 35
        f.derive(&memory_0, &.{
            f.set("/input/instructions/4/tag", f.s("alloc")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 36
        f.derive(&memory_0, &.{
            f.set("/input/instructions/4/tag", f.s("call")),
        }),
        // Control 37
        f.derive(&memory_0, &.{
            f.set("/input/instructions/4/tag", f.s("loop")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 38
        f.derive(&memory_0, &.{
            f.set("/input/instructions/4/tag", f.s("repeat")),
        }),
        // Control 39
        f.derive(&memory_0, &.{
            f.set("/input/instructions/4/tag", f.s("unreach")),
        }),
        // Control 40
        f.derive(&memory_0, &.{
            f.add("/input/instructions/4/extra", f.n("0")),
        }),
        // Control 41
        f.derive(&memory_0, &.{
            f.set("/input/instructions/4/payloadVisited", f.b(false)),
        }),
        // Control 42
        f.derive(&memory_0, &.{
            f.set("/input/sourceValidityConditionsPreserved", f.b(true)),
        }),
        // Control 43
        f.derive(&memory_0, &.{
            f.set("/input/configuration/optimize", f.s("Debug")),
        }),
        // Control 44
        f.derive(&memory_0, &.{
            f.add("/input/sourceValidity/slices/0", f.obj(&.{
                .{ "anchor", f.s("dead-result") },
            })),
        }),
        // Control 45
        f.derive(&validity_1, &.{
            f.remove("/input/body/3"),
            f.remove("/input/body/2"),
            f.add("/input/body/2", f.n("7")),
            f.remove("/input/configuration/arch"),
            f.remove("/input/configuration/endianness"),
            f.remove("/input/configuration/os"),
            f.remove("/input/configuration/pointerBits"),
            f.remove("/input/instructions/3"),
            f.remove("/input/instructions/2"),
            f.remove("/input/instructions/1"),
            f.remove("/input/instructions/0"),
            f.add("/input/instructions/0", f.ref(&shared.air_scalar_program_1_input_instructions_4)),
            f.add("/input/instructions/1", f.obj(&.{
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
            })),
            f.add("/input/instructions/2", f.ref(&shared.air_scalar_program_1_input_instructions_5)),
            f.add("/input/instructions/3", f.ref(&shared.air_scalar_program_1_input_instructions_6)),
            f.add("/input/instructions/4", f.ref(&shared.air_scalar_program_1_input_instructions_7)),
            f.add("/input/instructions/5", f.ref(&shared.air_scalar_program_1_input_instructions_8)),
            f.add("/input/instructions/6", f.ref(&shared.air_scalar_program_1_input_instructions_9)),
            f.add("/input/instructions/7", f.obj(&.{
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
            })),
            f.remove("/input/signature/parameters/1"),
            f.remove("/input/signature/parameters/0"),
            f.add("/input/signature/parameters/0", f.obj(&.{
                .{ "bits", f.n("8") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("unsigned") },
            })),
            f.set("/input/signature/returnType/bits", f.n("8")),
            f.set("/input/sourceValidity/slices/0/anchor", f.s("dead-result")),
            f.remove("/input/sourceValidity/slices/0/end"),
            f.remove("/input/sourceValidity/slices/0/source"),
            f.remove("/input/sourceValidity/slices/0/start"),
            f.remove("/input/sourceValidity/slices/0/unsupportedReason"),
            f.remove("/input/sourceValidity/slices/0/upperBound"),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 46
        f.derive(&memory_0, &.{
            f.set("/input/sourceValidity/complete", f.b(true)),
        }),
        // Control 47
        f.derive(&memory_0, &.{
            f.set("/input/sourceValidity/complete", f.n("0")),
        }),
        // Control 48
        f.derive(&memory_0, &.{
            f.set("/input/schema", f.s("oksolc.fresh-air.v1")),
        }),
        // Control 49
        f.derive(&memory_0, &.{
            f.add("/input/instructions/8", f.obj(&.{
                .{ "index", f.n("8") },
                .{ "payloadVisited", f.b(false) },
                .{ "reason", f.s("outside-decoded-body-closure") },
                .{ "tag", f.s("block") },
                .{ "unsupportedPayload", f.b(true) },
            })),
        }),
        // Control 50
        f.derive(&memory_0, &.{
            f.add("/input/instructions/8", f.ref(&shared.air_input_instructions_8_164)),
        }),
        // Control 51
        f.derive(&memory_0, &.{
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
        // Control 52
        f.ref(&memory_3),
        // Control 53
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("1")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("1")),
            f.set("/input/instructions/1/type/bits", f.n("1")),
            f.set("/input/signature/parameters/0/bits", f.n("1")),
            f.set("/input/signature/returnType/bits", f.n("1")),
        }),
        // Control 54
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("8")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("8")),
            f.set("/input/instructions/1/type/bits", f.n("8")),
            f.set("/input/signature/parameters/0/bits", f.n("8")),
            f.set("/input/signature/returnType/bits", f.n("8")),
        }),
        // Control 55
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("64")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("64")),
            f.set("/input/instructions/1/type/bits", f.n("64")),
            f.set("/input/signature/parameters/0/bits", f.n("64")),
            f.set("/input/signature/returnType/bits", f.n("64")),
        }),
        // Control 56
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("256")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 57
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("512")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("512")),
            f.set("/input/instructions/1/type/bits", f.n("512")),
            f.set("/input/signature/parameters/0/bits", f.n("512")),
            f.set("/input/signature/returnType/bits", f.n("512")),
        }),
        // Control 58
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("8")),
            f.set("/input/instructions/1/rhs/value", f.n("1")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 59
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/lhs/index", f.n("1")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/value", f.n("1")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 60
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.remove("/input/instructions/1/lhs"),
            f.set("/input/instructions/1/rhs/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/value", f.n("1")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 61
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/kind", f.s("instruction")),
            f.remove("/input/instructions/1/rhs/type"),
            f.remove("/input/instructions/1/rhs/value"),
            f.add("/input/instructions/1/rhs/index", f.n("1")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 62
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.remove("/input/instructions/1/rhs"),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 63
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/lhs/index", f.n("1")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/value", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 64
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.remove("/input/instructions/1/lhs"),
            f.set("/input/instructions/1/rhs/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/value", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 65
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/kind", f.s("instruction")),
            f.remove("/input/instructions/1/rhs/type"),
            f.remove("/input/instructions/1/rhs/value"),
            f.add("/input/instructions/1/rhs/index", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 66
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.remove("/input/instructions/1/rhs"),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 67
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/lhs/index", f.n("1")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("8")),
            f.set("/input/instructions/1/rhs/value", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 68
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.remove("/input/instructions/1/lhs"),
            f.set("/input/instructions/1/rhs/type/bits", f.n("8")),
            f.set("/input/instructions/1/rhs/value", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 69
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/kind", f.s("instruction")),
            f.remove("/input/instructions/1/rhs/type"),
            f.remove("/input/instructions/1/rhs/value"),
            f.add("/input/instructions/1/rhs/index", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 70
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.remove("/input/instructions/1/rhs"),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 71
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("1")),
            f.set("/input/signature/parameters/0/bits", f.n("1")),
            f.set("/input/signature/returnType/bits", f.n("1")),
        }),
        // Control 72
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("1")),
            f.remove("/input/instructions/2/operand/index"),
            f.set("/input/instructions/2/operand/kind", f.s("constant")),
            f.add("/input/instructions/2/operand/type", f.obj(&.{
                .{ "bits", f.n("1") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("unsigned") },
            })),
            f.add("/input/instructions/2/operand/value", f.n("0")),
            f.set("/input/signature/parameters/0/bits", f.n("1")),
            f.set("/input/signature/returnType/bits", f.n("1")),
        }),
        // Control 73
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("3")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("2")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("3")),
            f.set("/input/signature/parameters/0/bits", f.n("3")),
            f.set("/input/signature/returnType/bits", f.n("3")),
        }),
        // Control 74
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("3")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("2")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("3")),
            f.remove("/input/instructions/2/operand/index"),
            f.set("/input/instructions/2/operand/kind", f.s("constant")),
            f.add("/input/instructions/2/operand/type", f.obj(&.{
                .{ "bits", f.n("3") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("unsigned") },
            })),
            f.add("/input/instructions/2/operand/value", f.n("0")),
            f.set("/input/signature/parameters/0/bits", f.n("3")),
            f.set("/input/signature/returnType/bits", f.n("3")),
        }),
        // Control 75
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("8")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("3")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("8")),
            f.set("/input/signature/parameters/0/bits", f.n("8")),
            f.set("/input/signature/returnType/bits", f.n("8")),
        }),
        // Control 76
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("8")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("3")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("8")),
            f.remove("/input/instructions/2/operand/index"),
            f.set("/input/instructions/2/operand/kind", f.s("constant")),
            f.add("/input/instructions/2/operand/type", f.obj(&.{
                .{ "bits", f.n("8") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("unsigned") },
            })),
            f.add("/input/instructions/2/operand/value", f.n("0")),
            f.set("/input/signature/parameters/0/bits", f.n("8")),
            f.set("/input/signature/returnType/bits", f.n("8")),
        }),
        // Control 77
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("64")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("6")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("64")),
            f.set("/input/signature/parameters/0/bits", f.n("64")),
            f.set("/input/signature/returnType/bits", f.n("64")),
        }),
        // Control 78
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("64")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("6")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("64")),
            f.remove("/input/instructions/2/operand/index"),
            f.set("/input/instructions/2/operand/kind", f.s("constant")),
            f.add("/input/instructions/2/operand/type", f.obj(&.{
                .{ "bits", f.n("64") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("unsigned") },
            })),
            f.add("/input/instructions/2/operand/value", f.n("0")),
            f.set("/input/signature/parameters/0/bits", f.n("64")),
            f.set("/input/signature/returnType/bits", f.n("64")),
        }),
        // Control 79
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("8")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 80
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("8")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.remove("/input/instructions/2/operand/index"),
            f.set("/input/instructions/2/operand/kind", f.s("constant")),
            f.add("/input/instructions/2/operand/type", f.obj(&.{
                .{ "bits", f.n("256") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("unsigned") },
            })),
            f.add("/input/instructions/2/operand/value", f.n("0")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 81
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("512")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("9")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("512")),
            f.set("/input/signature/parameters/0/bits", f.n("512")),
            f.set("/input/signature/returnType/bits", f.n("512")),
        }),
        // Control 82
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("512")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("9")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("512")),
            f.remove("/input/instructions/2/operand/index"),
            f.set("/input/instructions/2/operand/kind", f.s("constant")),
            f.add("/input/instructions/2/operand/type", f.obj(&.{
                .{ "bits", f.n("512") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("unsigned") },
            })),
            f.add("/input/instructions/2/operand/value", f.n("0")),
            f.set("/input/signature/parameters/0/bits", f.n("512")),
            f.set("/input/signature/returnType/bits", f.n("512")),
        }),
        // Control 83
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("3")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("2")),
            f.set("/input/instructions/1/rhs/value", f.n("3")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("3")),
            f.set("/input/signature/parameters/0/bits", f.n("3")),
            f.set("/input/signature/returnType/bits", f.n("3")),
        }),
        // Control 84
        f.derive(&memory_3, &.{
            f.set("/input/instructions/1/tag", f.s("shr")),
        }),
        // Control 85
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("256")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 86
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("8")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("8")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("8")),
            f.set("/input/signature/parameters/0/bits", f.n("8")),
            f.set("/input/signature/returnType/bits", f.n("8")),
        }),
        // Control 87
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("1")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("1")),
            f.set("/input/signature/parameters/0/bits", f.n("1")),
            f.set("/input/signature/returnType/bits", f.n("1")),
        }),
        // Control 88
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.remove("/input/instructions/1/lhs/index"),
            f.set("/input/instructions/1/lhs/kind", f.s("constant")),
            f.add("/input/instructions/1/lhs/type", f.obj(&.{
                .{ "bits", f.n("256") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("signed") },
            })),
            f.add("/input/instructions/1/lhs/value", f.n("1")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("8")),
            f.set("/input/instructions/1/rhs/value", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 89
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/type/signedness", f.s("signed")),
            f.set("/input/instructions/1/rhs/value", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 90
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.remove("/input/instructions/1/lhs/index"),
            f.set("/input/instructions/1/lhs/kind", f.s("constant")),
            f.add("/input/instructions/1/lhs/type", f.obj(&.{
                .{ "bits", f.n("256") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("signed") },
            })),
            f.add("/input/instructions/1/lhs/value", f.n("1")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/value", f.n("1")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 91
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/type/signedness", f.s("signed")),
            f.set("/input/instructions/1/rhs/value", f.n("1")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 92
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.remove("/input/instructions/1/lhs/index"),
            f.set("/input/instructions/1/lhs/kind", f.s("constant")),
            f.add("/input/instructions/1/lhs/type", f.obj(&.{
                .{ "bits", f.n("256") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("signed") },
            })),
            f.add("/input/instructions/1/lhs/value", f.n("1")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/value", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 93
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/type/signedness", f.s("signed")),
            f.set("/input/instructions/1/rhs/value", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 94
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("8")),
            f.set("/input/instructions/1/rhs/value", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("shr_exact")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 95
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("7")),
            f.set("/input/instructions/1/rhs/value", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("shl")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 96
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("8")),
            f.set("/input/instructions/1/rhs/value", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("bit_or")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 97
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.remove("/input/instructions/1/rhs/type/bits"),
            f.set("/input/instructions/1/rhs/type/kind", f.s("vector")),
            f.remove("/input/instructions/1/rhs/type/signedness"),
            f.set("/input/instructions/1/rhs/value", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("shr")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 98
        f.derive(&memory_3, &.{
            f.set("/input/instructions/1/tag", f.s("xor")),
        }),
        // Control 99
        f.derive(&memory_3, &.{
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.remove("/input/instructions/2/operand/index"),
            f.set("/input/instructions/2/operand/kind", f.s("constant")),
            f.add("/input/instructions/2/operand/type", f.obj(&.{
                .{ "bits", f.n("0") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("unsigned") },
            })),
            f.add("/input/instructions/2/operand/value", f.n("0")),
        }),
        // Control 100
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("1")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("1")),
            f.set("/input/signature/parameters/0/bits", f.n("1")),
            f.set("/input/signature/returnType/bits", f.n("1")),
        }),
        // Control 101
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("1")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("1")),
            f.remove("/input/instructions/2/operand/index"),
            f.set("/input/instructions/2/operand/kind", f.s("constant")),
            f.add("/input/instructions/2/operand/type", f.obj(&.{
                .{ "bits", f.n("1") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("unsigned") },
            })),
            f.add("/input/instructions/2/operand/value", f.n("0")),
            f.set("/input/signature/parameters/0/bits", f.n("1")),
            f.set("/input/signature/returnType/bits", f.n("1")),
        }),
        // Control 102
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("8")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("8")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("8")),
            f.set("/input/signature/parameters/0/bits", f.n("8")),
            f.set("/input/signature/returnType/bits", f.n("8")),
        }),
        // Control 103
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("8")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("8")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("8")),
            f.remove("/input/instructions/2/operand/index"),
            f.set("/input/instructions/2/operand/kind", f.s("constant")),
            f.add("/input/instructions/2/operand/type", f.obj(&.{
                .{ "bits", f.n("8") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("unsigned") },
            })),
            f.add("/input/instructions/2/operand/value", f.n("0")),
            f.set("/input/signature/parameters/0/bits", f.n("8")),
            f.set("/input/signature/returnType/bits", f.n("8")),
        }),
        // Control 104
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("64")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("64")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("64")),
            f.set("/input/signature/parameters/0/bits", f.n("64")),
            f.set("/input/signature/returnType/bits", f.n("64")),
        }),
        // Control 105
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("64")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("64")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("64")),
            f.remove("/input/instructions/2/operand/index"),
            f.set("/input/instructions/2/operand/kind", f.s("constant")),
            f.add("/input/instructions/2/operand/type", f.obj(&.{
                .{ "bits", f.n("64") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("unsigned") },
            })),
            f.add("/input/instructions/2/operand/value", f.n("0")),
            f.set("/input/signature/parameters/0/bits", f.n("64")),
            f.set("/input/signature/returnType/bits", f.n("64")),
        }),
        // Control 106
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("128")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("128")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("128")),
            f.set("/input/signature/parameters/0/bits", f.n("128")),
            f.set("/input/signature/returnType/bits", f.n("128")),
        }),
        // Control 107
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("128")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("128")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("128")),
            f.remove("/input/instructions/2/operand/index"),
            f.set("/input/instructions/2/operand/kind", f.s("constant")),
            f.add("/input/instructions/2/operand/type", f.obj(&.{
                .{ "bits", f.n("128") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("unsigned") },
            })),
            f.add("/input/instructions/2/operand/value", f.n("0")),
            f.set("/input/signature/parameters/0/bits", f.n("128")),
            f.set("/input/signature/returnType/bits", f.n("128")),
        }),
        // Control 108
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("256")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 109
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("256")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("256")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("256")),
            f.remove("/input/instructions/2/operand/index"),
            f.set("/input/instructions/2/operand/kind", f.s("constant")),
            f.add("/input/instructions/2/operand/type", f.obj(&.{
                .{ "bits", f.n("256") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("unsigned") },
            })),
            f.add("/input/instructions/2/operand/value", f.n("0")),
            f.set("/input/signature/parameters/0/bits", f.n("256")),
            f.set("/input/signature/returnType/bits", f.n("256")),
        }),
        // Control 110
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("512")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("512")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("512")),
            f.set("/input/signature/parameters/0/bits", f.n("512")),
            f.set("/input/signature/returnType/bits", f.n("512")),
        }),
        // Control 111
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("512")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("512")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("512")),
            f.remove("/input/instructions/2/operand/index"),
            f.set("/input/instructions/2/operand/kind", f.s("constant")),
            f.add("/input/instructions/2/operand/type", f.obj(&.{
                .{ "bits", f.n("512") },
                .{ "kind", f.s("int") },
                .{ "signedness", f.s("unsigned") },
            })),
            f.add("/input/instructions/2/operand/value", f.n("0")),
            f.set("/input/signature/parameters/0/bits", f.n("512")),
            f.set("/input/signature/returnType/bits", f.n("512")),
        }),
        // Control 112
        f.derive(&memory_3, &.{
            f.set("/input/instructions/0/type/bits", f.n("64")),
            f.set("/input/instructions/1/rhs/type/bits", f.n("32")),
            f.set("/input/instructions/1/rhs/value", f.n("1")),
            f.set("/input/instructions/1/tag", f.s("xor")),
            f.set("/input/instructions/1/type/bits", f.n("64")),
            f.set("/input/signature/parameters/0/bits", f.n("64")),
            f.set("/input/signature/returnType/bits", f.n("64")),
        }),
        // Control 113
        f.ref(&memory_4),
        // Control 114
        f.ref(&validity_1),
        // Control 115
        f.derive(&memory_4, &.{
            f.set("/input/sourceValidity/slices/0/source/sha256", f.s("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")),
        }),
        // Control 116
        f.derive(&validity_1, &.{
            f.set("/input/sourceValidity/slices/0/source/sha256", f.s("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 117
        f.derive(&memory_4, &.{
            f.set("/input/sourceValidity/slices/0/anchor/index", f.n("3")),
        }),
        // Control 118
        f.derive(&validity_1, &.{
            f.set("/input/sourceValidity/slices/0/anchor/index", f.n("3")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 119
        f.derive(&memory_4, &.{
            f.set("/input/sourceValidity/slices/0/anchor/index", f.n("20")),
        }),
        // Control 120
        f.derive(&validity_1, &.{
            f.set("/input/sourceValidity/slices/0/anchor/index", f.n("20")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 121
        f.derive(&memory_4, &.{
            f.set("/input/sourceValidity/slices/0/end/index", f.n("2")),
        }),
        // Control 122
        f.derive(&validity_1, &.{
            f.set("/input/sourceValidity/slices/0/end/index", f.n("2")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 123
        f.derive(&memory_4, &.{
            f.set("/input/sourceValidity/slices/0/anchor/inSupportedBody", f.b(false)),
        }),
        // Control 124
        f.derive(&validity_1, &.{
            f.set("/input/sourceValidity/slices/0/anchor/inSupportedBody", f.b(false)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 125
        f.derive(&memory_4, &.{
            f.add("/input/sourceValidity/slices/1", f.ref(&shared.air_memory_program_2_input_sourcevalidity_slices_28)),
        }),
        // Control 126
        f.derive(&validity_1, &.{
            f.add("/input/sourceValidity/slices/1", f.ref(&shared.audit_validity_1_input_sourcevalidity_slices_203)),
            f.add("/output/1", f.obj(&.{
                .{ "anchor", f.n("2") },
                .{ "bound", f.s("unboundedPointer") },
                .{ "path", f.arr(&.{}) },
                .{ "source", f.s("ss") },
                .{ "unsupported", .null },
            })),
        }),
        // Control 127
        f.derive(&memory_4, &.{
            f.set("/input/sourceValidity/slices/0/upperBound/kind", f.s("sliceLength")),
            f.remove("/input/sourceValidity/slices/0/upperBound/requiresMemoryValidity"),
            f.add("/input/sourceValidity/slices/0/upperBound/original", f.obj(&.{
                .{ "index", f.n("0") },
                .{ "kind", f.s("instruction") },
            })),
        }),
        // Control 128
        f.derive(&validity_1, &.{
            f.set("/input/sourceValidity/slices/0/upperBound/kind", f.s("sliceLength")),
            f.remove("/input/sourceValidity/slices/0/upperBound/requiresMemoryValidity"),
            f.add("/input/sourceValidity/slices/0/upperBound/original", f.obj(&.{
                .{ "index", f.n("0") },
                .{ "kind", f.s("instruction") },
            })),
            f.set("/output/0/bound", f.s("sliceLength")),
        }),
        // Control 129
        f.derive(&memory_4, &.{
            f.set("/input/sourceValidity/slices/0/upperBound/requiresMemoryValidity", f.n("1")),
        }),
        // Control 130
        f.derive(&validity_1, &.{
            f.set("/input/sourceValidity/slices/0/upperBound/requiresMemoryValidity", f.n("1")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 131
        f.derive(&memory_4, &.{
            f.set("/input/sourceValidity/slices/0/unsupportedReason", f.s("sentinel")),
        }),
        // Control 132
        f.derive(&validity_1, &.{
            f.set("/input/sourceValidity/slices/0/unsupportedReason", f.s("sentinel")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 133
        f.derive(&memory_4, &.{
            f.set("/input/sourceValidity/slices/0/upperBound", f.arr(&.{})),
        }),
        // Control 134
        f.derive(&validity_1, &.{
            f.set("/input/sourceValidity/slices/0/upperBound", f.arr(&.{})),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 135
        f.derive(&memory_4, &.{
            f.add("/input/sourceOperationTags/2", f.s("slice_length")),
        }),
        // Control 136
        f.derive(&validity_1, &.{
            f.add("/input/sourceOperationTags/2", f.s("slice_length")),
        }),
        // Control 137
        f.derive(&memory_0, &.{
            f.add("/input/configuration/arch", f.s("aarch64")),
            f.add("/input/configuration/endianness", f.s("little")),
            f.add("/input/configuration/os", f.s("macos")),
            f.add("/input/configuration/pointerBits", f.n("64")),
        }),
        // Control 138
        f.derive(&memory_0, &.{
            f.add("/input/configuration/arch", f.s("aarch64")),
            f.add("/input/configuration/endianness", f.s("little")),
            f.add("/input/configuration/os", f.s("macos")),
            f.add("/input/configuration/pointerBits", f.n("64")),
            f.set("/input/instructions/4/rhs/kind", f.s("instruction")),
            f.remove("/input/instructions/4/rhs/type"),
            f.remove("/input/instructions/4/rhs/value"),
            f.add("/input/instructions/4/rhs/index", f.n("4")),
        }),
        // Control 139
        f.ref(&memory_5),
        // Control 140
        f.derive(&memory_5, &.{
            f.set("/input/instructions/2/lhs/index", f.n("0")),
            f.set("/input/instructions/2/rhs/index", f.n("0")),
        }),
        // Control 141
        f.derive(&memory_5, &.{
            f.set("/input/instructions/2/lhs/index", f.n("0")),
            f.set("/input/instructions/2/rhs/index", f.n("2")),
        }),
        // Control 142
        f.derive(&memory_5, &.{
            f.remove("/input/instructions/2/lhs"),
        }),
        // Control 143
        f.derive(&memory_5, &.{
            f.set("/input/instructions/2/lhs/index", f.n("0")),
            f.add("/input/instructions/2/unexpected", f.b(true)),
        }),
        // Control 144
        f.derive(&memory_5, &.{
            f.set("/input/instructions/2/lhs/index", f.n("0")),
            f.set("/input/instructions/2/payloadVisited", f.b(false)),
        }),
        // Control 145
        f.derive(&memory_5, &.{
            f.set("/input/instructions/2/lhs/index", f.n("0")),
            f.set("/input/instructions/2/type/flags/isConst", f.b(false)),
            f.set("/input/signature/returnType/flags/isConst", f.b(false)),
        }),
        // Control 146
        f.derive(&memory_5, &.{
            f.set("/input/instructions/2/lhs/index", f.n("0")),
            f.set("/input/instructions/2/type/flags/size", f.s("many")),
            f.set("/input/signature/returnType/flags/size", f.s("many")),
        }),
        // Control 147
        f.derive(&memory_5, &.{
            f.set("/input/instructions/2/lhs/index", f.n("0")),
            f.set("/input/instructions/2/type/child/bits", f.n("64")),
            f.set("/input/instructions/2/type/pointeeLayout/alignment", f.n("8")),
            f.set("/input/instructions/2/type/pointeeLayout/bytes", f.n("8")),
        }),
        // Control 148
        f.derive(&memory_5, &.{
            f.set("/input/instructions/2/lhs/index", f.n("0")),
            f.set("/reject", f.b(false)),
            f.add("/output", f.obj(&.{
                .{ "slice_elem_ptr", f.n("1") },
            })),
        }),
        // Control 149
        f.derive(&memory_4, &.{
            f.set("/input/configuration/pointerBits", f.n("32")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 150
        f.derive(&validity_1, &.{
            f.set("/input/configuration/pointerBits", f.n("32")),
        }),
        // Control 151
        f.derive(&memory_4, &.{
            f.set("/input/configuration/endianness", f.s("big")),
        }),
        // Control 152
        f.derive(&validity_1, &.{
            f.set("/input/configuration/endianness", f.s("big")),
        }),
        // Control 153
        f.derive(&memory_4, &.{
            f.set("/input/configuration/arch", f.s("x86_64")),
        }),
        // Control 154
        f.derive(&validity_1, &.{
            f.set("/input/configuration/arch", f.s("x86_64")),
        }),
        // Control 155
        f.derive(&memory_4, &.{
            f.set("/input/configuration/os", f.s("linux")),
        }),
        // Control 156
        f.derive(&validity_1, &.{
            f.set("/input/configuration/os", f.s("linux")),
        }),
        // Control 157
        f.ref(&memory_6),
        // Control 158
        f.ref(&validity_7),
        // Control 159
        f.derive(&memory_4, &.{
            f.set("/input/instructions/2/rhs/index", f.n("0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 160
        f.derive(&validity_1, &.{
            f.set("/input/instructions/2/rhs/index", f.n("0")),
        }),
        // Control 161
        f.derive(&memory_4, &.{
            f.set("/input/instructions/3/tag", f.s("ret_load")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 162
        f.derive(&validity_1, &.{
            f.set("/input/instructions/3/tag", f.s("ret_load")),
        }),
        // Control 163
        f.ref(&memory_8),
        // Control 164
        f.ref(&memory_8),
        // Control 165
        f.derive(&memory_8, &.{
            f.set("/input/instructions/3/fieldIndex", f.n("0")),
        }),
        // Control 166
        f.derive(&memory_8, &.{
            f.set("/input/instructions/3/operand/index", f.n("3")),
        }),
        // Control 167
        f.derive(&memory_8, &.{
            f.set("/input/instructions/3/type/flags/isConst", f.b(true)),
        }),
        // Control 168
        f.derive(&memory_8, &.{
            f.set("/input/instructions/3/operand/index", f.n("0")),
        }),
        // Control 169
        f.derive(&memory_8, &.{
            f.set("/input/instructions/4/tag", f.s("memcpy")),
        }),
        // Control 170
        f.derive(&memory_8, &.{
            f.add("/input/sourceValidity/slices/0", f.obj(&.{})),
        }),
        // Control 171
        f.derive(&validity_1, &.{
            f.add("/input/body/4", f.n("4")),
            f.add("/input/body/5", f.n("5")),
            f.add("/input/body/6", f.n("6")),
            f.remove("/input/instructions/3"),
            f.remove("/input/instructions/2"),
            f.remove("/input/instructions/1"),
            f.remove("/input/instructions/0"),
            f.add("/input/instructions/0", f.ref(&shared.air_aggregate_program_4_input_instructions_35)),
            f.add("/input/instructions/1", f.obj(&.{
                .{ "allocationKind", f.s("stack") },
                .{ "index", f.n("1") },
                .{ "payloadVisited", f.b(true) },
                .{ "tag", f.s("alloc") },
                .{ "type", f.obj(&.{
                    .{ "child", f.ref(&shared.struct_274) },
                    .{ "flags", f.ref(&shared.air_aggregate_program_4_input_instructions_type_flags_41) },
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
            })),
            f.add("/input/instructions/2", f.obj(&.{
                .{ "index", f.n("2") },
                .{ "lhs", f.obj(&.{
                    .{ "index", f.n("1") },
                    .{ "kind", f.s("instruction") },
                }) },
                .{ "payloadVisited", f.b(true) },
                .{ "rhs", f.obj(&.{
                    .{ "fields", f.ref(&shared.air_aggregate_program_4_input_instructions_rhs_fields_44) },
                    .{ "kind", f.s("aggregate") },
                    .{ "type", f.ref(&shared.struct_274) },
                }) },
                .{ "tag", f.s("store") },
                .{ "type", f.obj(&.{
                    .{ "kind", f.s("void") },
                }) },
            })),
            f.add("/input/instructions/3", f.ref(&shared.air_aggregate_program_4_input_instructions_45)),
            f.add("/input/instructions/4", f.ref(&shared.air_aggregate_program_4_input_instructions_47)),
            f.add("/input/instructions/5", f.obj(&.{
                .{ "index", f.n("5") },
                .{ "operand", f.obj(&.{
                    .{ "index", f.n("1") },
                    .{ "kind", f.s("instruction") },
                }) },
                .{ "payloadVisited", f.b(true) },
                .{ "tag", f.s("load") },
                .{ "type", f.ref(&shared.struct_274) },
            })),
            f.add("/input/instructions/6", f.obj(&.{
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
            })),
            f.remove("/input/signature/parameters/0"),
            f.remove("/input/signature/returnType/bits"),
            f.set("/input/signature/returnType/kind", f.s("struct")),
            f.remove("/input/signature/returnType/signedness"),
            f.add("/input/signature/returnType/containerLayout", f.s("auto")),
            f.add("/input/signature/returnType/fields", f.ref(&shared.air_aggregate_program_4_input_instructions_type_child_fields_39)),
            f.add("/input/signature/returnType/identity", f.ref(&shared.audit_input_instructions_1_type_child_identity_275)),
            f.add("/input/signature/returnType/layout", f.obj(&.{
                .{ "alignment", f.n("8") },
                .{ "bytes", f.n("16") },
                .{ "kind", f.s("abi") },
            })),
            f.remove("/input/sourceValidity/slices/0/anchor"),
            f.remove("/input/sourceValidity/slices/0/end"),
            f.remove("/input/sourceValidity/slices/0/source"),
            f.remove("/input/sourceValidity/slices/0/start"),
            f.remove("/input/sourceValidity/slices/0/unsupportedReason"),
            f.remove("/input/sourceValidity/slices/0/upperBound"),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 172
        f.derive(&memory_8, &.{
            f.remove("/input/body/4"),
        }),
        // Control 173
        f.derive(&memory_8, &.{
            f.add("/input/sourceOperationTags/2", f.s("slice_length")),
        }),
        // Control 174
        f.derive(&memory_8, &.{
            f.remove("/input/instructions/2/rhs/fields/1"),
        }),
        // Control 175
        f.derive(&memory_8, &.{
            f.set("/input/instructions/2/rhs/fields/0/type/bits", f.n("32")),
        }),
        // Control 176
        f.derive(&memory_8, &.{
            f.set("/input/instructions/2/rhs/fields/1/value", f.n("18446744073709551616")),
        }),
        // Control 177
        f.derive(&memory_8, &.{
            f.add("/input/instructions/2/rhs/fields/0/value", f.n("0")),
        }),
        // Control 178
        f.ref(&memory_9),
        // Control 179
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("3")),
        }),
        // Control 180
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("8")),
        }),
        // Control 181
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.b(true)),
        }),
        // Control 182
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4.0")),
        }),
        // Control 183
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.set("/input/instructions/4/type/flags/alignment", f.n("2")),
            f.set("/input/instructions/5/type/child/flags/alignment", f.n("2")),
            f.set("/input/instructions/7/type/child/flags/alignment", f.n("2")),
            f.set("/input/instructions/8/type/flags/alignment", f.n("2")),
        }),
        // Control 184
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.set("/input/instructions/9/type/flags/alignment", f.n("4")),
            f.set("/reject", f.b(false)),
            f.add("/output", f.obj(&.{
                .{ "alloc", f.n("1") },
                .{ "load", f.n("1") },
                .{ "slice", f.n("1") },
                .{ "slice_elem_ptr", f.n("1") },
                .{ "store", f.n("2") },
            })),
        }),
        // Control 185
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.set("/input/instructions/3/type/pointeeLayout/alignment", f.n("4")),
        }),
        // Control 186
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.set("/input/signature/parameters/0/child/bits", f.n("8")),
            f.set("/input/signature/parameters/0/flags/alignment", f.n("4")),
            f.set("/input/signature/parameters/0/flags/size", f.s("many")),
            f.set("/input/signature/parameters/0/pointeeLayout/alignment", f.n("1")),
            f.set("/input/signature/parameters/0/pointeeLayout/bytes", f.n("1")),
        }),
        // Control 187
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.set("/input/signature/parameters/0/child/bits", f.n("64")),
            f.set("/input/signature/parameters/0/pointeeLayout/alignment", f.n("8")),
            f.set("/input/signature/parameters/0/pointeeLayout/bytes", f.n("8")),
        }),
        // Control 188
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
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
        }),
        // Control 189
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.set("/input/signature/genericInstance", f.b(true)),
        }),
        // Control 190
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.set("/input/signature/noaliasBits", f.n("1")),
        }),
        // Control 191
        f.derive(&memory_9, &.{
            f.set("/input/configuration/endianness", f.s("big")),
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
        }),
        // Control 192
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.set("/input/instructions/11/operand/kind", f.s("instruction")),
            f.add("/input/instructions/11/operand/index", f.n("9")),
        }),
        // Control 193
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.set("/input/instructions/11/operand/kind", f.s("instruction")),
            f.add("/input/instructions/11/operand/index", f.n("5")),
        }),
        // Control 194
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.set("/input/instructions/9/tag", f.s("ptr_add")),
        }),
        // Control 195
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.set("/input/instructions/6/rhs/index", f.n("5")),
        }),
        // Control 196
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.remove("/input/instructions/10/lhs"),
            f.remove("/input/instructions/10/rhs"),
            f.set("/input/instructions/10/tag", f.s("load")),
            f.set("/input/instructions/10/type/kind", f.s("int")),
            f.add("/input/instructions/10/type/bits", f.n("8")),
            f.add("/input/instructions/10/type/signedness", f.s("unsigned")),
            f.add("/input/instructions/10/operand", f.obj(&.{
                .{ "index", f.n("9") },
                .{ "kind", f.s("instruction") },
            })),
        }),
        // Control 197
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.remove("/input/instructions/10/lhs"),
            f.remove("/input/instructions/10/rhs"),
            f.set("/input/instructions/10/tag", f.s("slice_len")),
            f.set("/input/instructions/10/type/kind", f.s("int")),
            f.add("/input/instructions/10/type/bits", f.n("64")),
            f.add("/input/instructions/10/type/signedness", f.s("unsigned")),
            f.add("/input/instructions/10/operand", f.obj(&.{
                .{ "index", f.n("8") },
                .{ "kind", f.s("instruction") },
            })),
        }),
        // Control 198
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.remove("/input/instructions/10/lhs"),
            f.remove("/input/instructions/10/rhs"),
            f.set("/input/instructions/10/tag", f.s("slice_ptr")),
            f.set("/input/instructions/10/type/kind", f.s("pointer")),
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
            f.add("/input/instructions/10/operand", f.obj(&.{
                .{ "index", f.n("8") },
                .{ "kind", f.s("instruction") },
            })),
        }),
        // Control 199
        f.derive(&memory_9, &.{
            f.set("/input/instructions/0/type/flags/isConst", f.b(true)),
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.set("/input/signature/parameters/0/flags/isConst", f.b(true)),
        }),
        // Control 200
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.set("/input/instructions/9/type/flags/isConst", f.b(true)),
        }),
        // Control 201
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.set("/input/instructions/10/rhs/index", f.n("1")),
        }),
        // Control 202
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.remove("/input/instructions/8/type/child"),
            f.remove("/input/instructions/8/type/flags"),
            f.set("/input/instructions/8/type/kind", f.s("int")),
            f.remove("/input/instructions/8/type/layout"),
            f.remove("/input/instructions/8/type/pointeeLayout"),
            f.remove("/input/instructions/8/type/sentinel"),
            f.add("/input/instructions/8/type/bits", f.n("8")),
            f.add("/input/instructions/8/type/signedness", f.s("unsigned")),
        }),
        // Control 203
        f.ref(&memory_10),
        // Control 204
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.set("/input/instructions/3/type/flags/isVolatile", f.b(true)),
        }),
        // Control 205
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/child/bits", f.n("64")),
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
        }),
        // Control 206
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
        }),
        // Control 207
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
        }),
        // Control 208
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.set("/input/instructions/4/rhs/value", f.n("3")),
        }),
        // Control 209
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.set("/input/instructions/4/rhs/value", f.n("5")),
        }),
        // Control 210
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.set("/input/instructions/4/rhs/kind", f.s("instruction")),
            f.remove("/input/instructions/4/rhs/type"),
            f.remove("/input/instructions/4/rhs/value"),
            f.add("/input/instructions/4/rhs/index", f.n("1")),
        }),
        // Control 211
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.remove("/input/instructions/4/type/child"),
            f.remove("/input/instructions/4/type/flags"),
            f.set("/input/instructions/4/type/kind", f.s("void")),
            f.remove("/input/instructions/4/type/layout"),
            f.remove("/input/instructions/4/type/pointeeLayout"),
            f.remove("/input/instructions/4/type/sentinel"),
        }),
        // Control 212
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.set("/input/instructions/4/type/child/bits", f.n("32")),
            f.set("/input/instructions/4/type/flags/alignment", .null),
            f.set("/input/instructions/4/type/pointeeLayout/alignment", f.n("4")),
            f.set("/input/instructions/4/type/pointeeLayout/bytes", f.n("4")),
        }),
        // Control 213
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.set("/input/instructions/6/rhs/index", f.n("0")),
        }),
        // Control 214
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.set("/input/instructions/6/lhs/index", f.n("0")),
        }),
        // Control 215
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.set("/input/instructions/5/allocationKind", f.s("heap")),
        }),
        // Control 216
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.set("/input/instructions/7/type/flags/isConst", f.b(false)),
        }),
        // Control 217
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.set("/input/instructions/9/lhs/index", f.n("1")),
        }),
        // Control 218
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
            f.set("/input/instructions/9/rhs/index", f.n("9")),
        }),
        // Control 219
        f.derive(&memory_9, &.{
            f.set("/input/instructions/3/type/flags/alignment", f.n("4")),
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
        }),
        // Control 220
        f.ref(&memory_11),
        // Control 221
        f.ref(&memory_11),
        // Control 222
        f.derive(&memory_4, &.{
            f.set("/input/instructions/2/tag", f.s("ptr_elem_ptr")),
            f.set("/input/instructions/2/type/flags/size", f.s("one")),
            f.set("/input/instructions/2/type/layout/bytes", f.n("8")),
            f.remove("/input/sourceValidity/slices/0"),
            f.remove("/output/slice"),
            f.add("/output/ptr_elem_ptr", f.n("1")),
        }),
        // Control 223
        f.derive(&memory_4, &.{
            f.set("/input/instructions/2/tag", f.s("ptr_elem_ptr")),
            f.set("/input/instructions/2/type/flags/size", f.s("many")),
            f.set("/input/instructions/2/type/layout/bytes", f.n("8")),
            f.remove("/input/sourceValidity/slices/0"),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 224
        f.derive(&memory_4, &.{
            f.set("/input/instructions/2/tag", f.s("ptr_elem_ptr")),
            f.set("/input/instructions/2/type/flags/isConst", f.b(false)),
            f.set("/input/instructions/2/type/flags/size", f.s("one")),
            f.set("/input/instructions/2/type/layout/bytes", f.n("8")),
            f.remove("/input/sourceValidity/slices/0"),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 225
        f.derive(&memory_4, &.{
            f.set("/input/instructions/2/rhs/index", f.n("2")),
            f.set("/input/instructions/2/tag", f.s("ptr_elem_ptr")),
            f.set("/input/instructions/2/type/flags/size", f.s("one")),
            f.set("/input/instructions/2/type/layout/bytes", f.n("8")),
            f.remove("/input/sourceValidity/slices/0"),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 226
        f.derive(&memory_4, &.{
            f.set("/input/instructions/2/rhs/index", f.n("0")),
            f.set("/input/instructions/2/tag", f.s("ptr_elem_ptr")),
            f.set("/input/instructions/2/type/flags/size", f.s("one")),
            f.set("/input/instructions/2/type/layout/bytes", f.n("8")),
            f.remove("/input/sourceValidity/slices/0"),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 227
        f.derive(&memory_4, &.{
            f.remove("/input/instructions/0/type/child/bits"),
            f.set("/input/instructions/0/type/child/kind", f.s("void")),
            f.remove("/input/instructions/0/type/child/signedness"),
            f.set("/input/instructions/0/type/pointeeLayout/bytes", f.n("0")),
            f.set("/input/instructions/2/tag", f.s("ptr_elem_ptr")),
            f.set("/input/instructions/2/type/flags/size", f.s("one")),
            f.set("/input/instructions/2/type/layout/bytes", f.n("8")),
            f.remove("/input/signature/parameters/0/child/bits"),
            f.set("/input/signature/parameters/0/child/kind", f.s("void")),
            f.remove("/input/signature/parameters/0/child/signedness"),
            f.set("/input/signature/parameters/0/pointeeLayout/bytes", f.n("0")),
            f.remove("/input/sourceValidity/slices/0"),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 228
        f.derive(&memory_4, &.{
            f.set("/input/instructions/0/type/flags/size", f.s("one")),
            f.set("/input/instructions/2/tag", f.s("ptr_elem_ptr")),
            f.set("/input/instructions/2/type/flags/size", f.s("one")),
            f.set("/input/instructions/2/type/layout/bytes", f.n("8")),
            f.set("/input/signature/parameters/0/flags/size", f.s("one")),
            f.remove("/input/sourceValidity/slices/0"),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 229
        f.derive(&memory_11, &.{
            f.remove("/input/instructions/2/body/1"),
            f.remove("/input/instructions/2/body/0"),
        }),
        // Control 230
        f.derive(&memory_11, &.{
            f.remove("/input/instructions/2/body/1"),
        }),
        // Control 231
        f.derive(&memory_11, &.{
            f.add("/input/instructions/2/body/2", f.n("6")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 232
        f.derive(&memory_11, &.{
            f.add("/input/instructions/2/body/1", f.n("3")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 233
        f.derive(&memory_11, &.{
            f.remove("/input/instructions/2/body/1"),
            f.remove("/input/instructions/2/body/0"),
            f.add("/input/instructions/2/body/0", f.n("2")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 234
        f.derive(&memory_11, &.{
            f.remove("/input/instructions/4/elseBody/0"),
            f.add("/input/instructions/4/elseBody/0", f.n("5")),
            f.add("/input/instructions/4/elseBody/1", f.n("6")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 235
        f.derive(&memory_11, &.{
            f.set("/input/instructions/6/tag", f.s("br")),
            f.set("/input/instructions/6/target", f.n("1")),
            f.add("/input/instructions/6/operand", f.obj(&.{
                .{ "index", f.n("5") },
                .{ "kind", f.s("instruction") },
            })),
        }),
        // Control 236
        f.derive(&memory_11, &.{
            f.set("/input/instructions/2/type/kind", f.s("void")),
        }),
        // Control 237
        f.derive(&memory_11, &.{
            f.add("/input/instructions/2/extra", f.b(true)),
        }),
        // Control 238
        f.derive(&memory_11, &.{
            f.set("/input/instructions/6/type/kind", f.s("void")),
        }),
        // Control 239
        f.derive(&memory_11, &.{
            f.add("/input/instructions/6/extra", f.b(true)),
        }),
        // Control 240
        f.derive(&memory_11, &.{
            f.set("/input/instructions/3/lhs/index", f.n("5")),
        }),
        // Control 241
        f.derive(&memory_11, &.{
            f.set("/input/instructions/5/rhs/kind", f.s("instruction")),
            f.remove("/input/instructions/5/rhs/type"),
            f.remove("/input/instructions/5/rhs/value"),
            f.add("/input/instructions/5/rhs/index", f.n("5")),
        }),
        // Control 242
        f.derive(&memory_11, &.{
            f.set("/input/instructions/7/operand/index", f.n("5")),
        }),
        // Control 243
        f.derive(&memory_11, &.{
            f.set("/input/instructions/8/operand/index", f.n("3")),
        }),
        // Control 244
        f.derive(&memory_11, &.{
            f.set("/input/instructions/8/operand/index", f.n("2")),
        }),
        // Control 245
        f.ref(&memory_12),
        // Control 246
        f.derive(&memory_11, &.{
            f.set("/input/instructions/6/target", f.n("0")),
        }),
        // Control 247
        f.derive(&memory_11, &.{
            f.set("/input/instructions/6/target", f.n("1")),
        }),
        // Control 248
        f.derive(&memory_11, &.{
            f.set("/input/instructions/6/target", f.n("5")),
        }),
        // Control 249
        f.derive(&memory_11, &.{
            f.set("/input/instructions/6/target", f.n("6")),
        }),
        // Control 250
        f.derive(&memory_11, &.{
            f.set("/input/instructions/6/target", f.n("8")),
        }),
        // Control 251
        f.derive(&memory_11, &.{
            f.set("/input/instructions/6/target", f.n("-1")),
        }),
        // Control 252
        f.derive(&memory_11, &.{
            f.set("/input/instructions/6/target", f.n("9")),
        }),
        // Control 253
        f.derive(&memory_11, &.{
            f.set("/input/instructions/6/target", f.b(true)),
        }),
        // Control 254
        f.derive(&memory_11, &.{
            f.set("/input/instructions/7/target", f.n("2")),
        }),
        // Control 255
        f.derive(&memory_11, &.{
            f.remove("/input/instructions/8/operand"),
            f.set("/input/instructions/8/tag", f.s("repeat")),
            f.add("/input/instructions/8/target", f.n("2")),
        }),
        // Control 256
        f.derive(&memory_11, &.{
            f.set("/input/instructions/5/tag", f.s("call")),
        }),
        // Control 257
        f.derive(&memory_11, &.{
            f.set("/input/instructions/5/tag", f.s("ret_load")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 258
        f.derive(&memory_11, &.{
            f.set("/input/instructions/5/tag", f.s("unreach")),
        }),
        // Control 259
        f.derive(&memory_11, &.{
            f.set("/input/instructions/5/tag", f.s("future")),
        }),
        // Control 260
        f.ref(&memory_13),
        // Control 261
        f.derive(&memory_13, &.{
            f.remove("/input/specialization"),
        }),
        // Control 262
        f.derive(&memory_13, &.{
            f.add("/input/configuration/arch", f.s("aarch64")),
            f.add("/input/configuration/endianness", f.s("little")),
            f.add("/input/configuration/os", f.s("macos")),
            f.add("/input/configuration/pointerBits", f.n("64")),
            f.set("/input/signature/callingConvention", f.obj(&.{
                .{ "auto", f.obj(&.{}) },
            })),
        }),
        // Control 263
        f.derive(&memory_0, &.{
            f.add("/input/configuration/arch", f.s("aarch64")),
            f.add("/input/configuration/endianness", f.s("little")),
            f.add("/input/configuration/os", f.s("macos")),
            f.add("/input/configuration/pointerBits", f.n("64")),
        }),
        // Control 264
        f.derive(&memory_0, &.{
            f.add("/input/configuration/arch", f.s("aarch64")),
            f.add("/input/configuration/endianness", f.s("little")),
            f.add("/input/configuration/os", f.s("macos")),
            f.add("/input/configuration/pointerBits", f.n("64")),
        }),
        // Control 265
        f.derive(&memory_0, &.{
            f.add("/input/configuration/arch", f.s("aarch64")),
            f.add("/input/configuration/endianness", f.s("little")),
            f.add("/input/configuration/os", f.s("macos")),
            f.add("/input/configuration/pointerBits", f.n("64")),
        }),
        // Control 266
        f.derive(&memory_0, &.{
            f.add("/input/configuration/arch", f.s("aarch64")),
            f.add("/input/configuration/endianness", f.s("little")),
            f.add("/input/configuration/os", f.s("macos")),
            f.add("/input/configuration/pointerBits", f.n("64")),
        }),
        // Control 267
        f.derive(&memory_0, &.{
            f.set("/input/instructions/4/tag", f.s("future_op")),
            f.set("/input/name", f.s("fixture.other")),
        }),
        // Control 268
        f.ref(&signatures_2),
        // Control 269
        f.derive(&signatures_2, &.{
            f.set("/input/move_back/signature/parameters/0/flags/isConst", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 270
        f.ref(&signatures_2),
        // Control 271
        f.ref(&signatures_2),
        // Control 272
        f.ref(&signatures_2),
        // Control 273
        f.ref(&signatures_2),
        // Control 274
        f.ref(&signatures_2),
        // Control 275
        f.derive(&signatures_2, &.{
            f.set("/input/move_back/signature/parameters/0/flags/size", f.s("slice")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 276
        f.derive(&signatures_2, &.{
            f.set("/input/load_store/signature/parameters/0/flags/isConst", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 277
        f.ref(&signatures_2),
        // Control 278
        f.ref(&signatures_2),
        // Control 279
        f.ref(&signatures_2),
        // Control 280
        f.ref(&signatures_2),
        // Control 281
        f.ref(&signatures_2),
        // Control 282
        f.derive(&signatures_2, &.{
            f.set("/input/load_store/signature/parameters/0/flags/size", f.s("slice")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 283
        f.derive(&signatures_2, &.{
            f.set("/input/slice_fields/signature/parameters/0/flags/isConst", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 284
        f.ref(&signatures_2),
        // Control 285
        f.ref(&signatures_2),
        // Control 286
        f.ref(&signatures_2),
        // Control 287
        f.ref(&signatures_2),
        // Control 288
        f.ref(&signatures_2),
        // Control 289
        f.derive(&signatures_2, &.{
            f.set("/input/slice_fields/signature/parameters/0/flags/size", f.s("slice")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 290
        f.derive(&signatures_2, &.{
            f.set("/input/buffer_alias/signature/parameters/0/flags/isConst", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 291
        f.ref(&signatures_2),
        // Control 292
        f.ref(&signatures_2),
        // Control 293
        f.ref(&signatures_2),
        // Control 294
        f.ref(&signatures_2),
        // Control 295
        f.ref(&signatures_2),
        // Control 296
        f.derive(&signatures_2, &.{
            f.set("/input/buffer_alias/signature/parameters/0/flags/size", f.s("slice")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 297
        f.derive(&signatures_2, &.{
            f.set("/input/initialize_slice/signature/parameters/0/flags/isConst", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 298
        f.ref(&signatures_2),
        // Control 299
        f.ref(&signatures_2),
        // Control 300
        f.ref(&signatures_2),
        // Control 301
        f.ref(&signatures_2),
        // Control 302
        f.ref(&signatures_2),
        // Control 303
        f.derive(&signatures_2, &.{
            f.set("/input/initialize_slice/signature/parameters/0/flags/size", f.s("slice")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 304
        f.derive(&signatures_2, &.{
            f.set("/input/initialize_length/signature/parameters/0/flags/isConst", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 305
        f.ref(&signatures_2),
        // Control 306
        f.ref(&signatures_2),
        // Control 307
        f.ref(&signatures_2),
        // Control 308
        f.ref(&signatures_2),
        // Control 309
        f.ref(&signatures_2),
        // Control 310
        f.derive(&signatures_2, &.{
            f.set("/input/initialize_length/signature/parameters/0/flags/size", f.s("slice")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 311
        f.derive(&signatures_2, &.{
            f.set("/input/unaligned_volatile/signature/parameters/0/flags/isConst", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 312
        f.derive(&signatures_2, &.{
            f.set("/input/unaligned_volatile/signature/parameters/0/flags/isVolatile", f.b(false)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 313
        f.ref(&signatures_2),
        // Control 314
        f.ref(&signatures_2),
        // Control 315
        f.ref(&signatures_2),
        // Control 316
        f.derive(&signatures_2, &.{
            f.set("/input/unaligned_volatile/signature/parameters/0/flags/alignment", .null),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 317
        f.derive(&signatures_2, &.{
            f.set("/input/unaligned_volatile/signature/parameters/0/flags/size", f.s("slice")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 318
        f.derive(&signatures_2, &.{
            f.set("/input/allow_zero/signature/parameters/0/flags/isConst", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 319
        f.ref(&signatures_2),
        // Control 320
        f.derive(&signatures_2, &.{
            f.set("/input/allow_zero/signature/parameters/0/flags/allowZero", f.b(false)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 321
        f.ref(&signatures_2),
        // Control 322
        f.ref(&signatures_2),
        // Control 323
        f.ref(&signatures_2),
        // Control 324
        f.derive(&signatures_2, &.{
            f.set("/input/allow_zero/signature/parameters/0/flags/size", f.s("slice")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 325
        f.derive(&signatures_2, &.{
            f.set("/input/packed_pointer/signature/parameters/0/flags/isConst", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 326
        f.ref(&signatures_2),
        // Control 327
        f.ref(&signatures_2),
        // Control 328
        f.derive(&signatures_2, &.{
            f.set("/input/packed_pointer/signature/parameters/0/flags/bitOffset", f.n("0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 329
        f.derive(&signatures_2, &.{
            f.set("/input/packed_pointer/signature/parameters/0/flags/hostSizeBytes", f.n("0")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 330
        f.derive(&signatures_2, &.{
            f.set("/input/packed_pointer/signature/parameters/0/flags/alignment", .null),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 331
        f.derive(&signatures_2, &.{
            f.set("/input/packed_pointer/signature/parameters/0/flags/size", f.s("slice")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 332
        f.derive(&signatures_2, &.{
            f.set("/input/opaque_pointer/signature/parameters/0/flags/isConst", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 333
        f.ref(&signatures_2),
        // Control 334
        f.ref(&signatures_2),
        // Control 335
        f.ref(&signatures_2),
        // Control 336
        f.ref(&signatures_2),
        // Control 337
        f.ref(&signatures_2),
        // Control 338
        f.derive(&signatures_2, &.{
            f.set("/input/opaque_pointer/signature/parameters/0/flags/size", f.s("slice")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 339
        f.derive(&signatures_2, &.{
            f.set("/input/undefined_store/signature/parameters/0/flags/isConst", f.b(true)),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 340
        f.ref(&signatures_2),
        // Control 341
        f.ref(&signatures_2),
        // Control 342
        f.ref(&signatures_2),
        // Control 343
        f.ref(&signatures_2),
        // Control 344
        f.ref(&signatures_2),
        // Control 345
        f.derive(&signatures_2, &.{
            f.set("/input/undefined_store/signature/parameters/0/flags/size", f.s("slice")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
    };
};
