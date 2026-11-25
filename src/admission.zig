// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Versioned vocabulary gate, not a claim of complete source-validity capture.
const std = @import("std");
const c = @import("common.zig");
pub const schema = "zean.admission.v1";
pub const Origin = enum { air, source_and_air, debug_metadata };
pub const Operation = struct {
    name: []const u8,
    tags: []const u8,
    origin: Origin = .air,
    obligations: []const u8,
    interpretation: []const u8,
    controls: []const u8,
};
// Exact tokens, never prefixes. A listed tag still requires all decoder checks.
pub const operations = [_]Operation{
    .{ .name = "argument", .tags = "arg", .obligations = "signature, runtime parameter map, SSA ownership", .interpretation = "MemoryAir.Prim.argument", .controls = "test/native/cases/air.zig" },
    .{ .name = "arithmetic", .tags = "add sub mul add_safe sub_safe mul_safe add_wrap sub_wrap mul_wrap", .obligations = "widths, signedness, overflow mode, reached dead results", .interpretation = "Scalar.Arithmetic.eval", .controls = "test/native/cases/air.zig" },
    .{ .name = "unsigned_division", .tags = "div_trunc", .obligations = "matching positive-width unsigned operands and result, nonzero divisor", .interpretation = "Scalar.Prim.eval", .controls = "test/native/bulk_copy.zig" },
    .{ .name = "bitwise", .tags = "bit_and bit_or xor shr shl", .obligations = "unsigned widths and shift count", .interpretation = "Scalar.Prim.eval", .controls = "test/native/cases/air.zig" },
    .{ .name = "comparison", .tags = "cmp_eq cmp_neq cmp_lt cmp_lte cmp_gt cmp_gte min max", .obligations = "matching integer types or declared enum equality or inequality", .interpretation = "Scalar.Prim.eval", .controls = "test/native/bulk_copy.zig" },
    .{ .name = "integer_cast", .tags = "int_cast int_cast_safe bit_cast trunc", .obligations = "widths, range, signedness; byte contracts for specialized casts", .interpretation = "Scalar.Prim.eval", .controls = "test/native/cases/air.zig" },
    .{ .name = "boolean", .tags = "not", .obligations = "boolean operand and result", .interpretation = "MemoryAir.Prim.eval", .controls = "test/native/byte_reads.zig" },
    .{ .name = "error_values", .tags = "is_err is_non_err unwrap_errunion_payload unwrap_errunion_err wrap_errunion_payload wrap_errunion_err", .obligations = "concrete error names, void payload, checked type conversions, selected component present", .interpretation = "Memory.testError / Memory.unwrapError / Memory.wrapError", .controls = "test/native/error_status.zig" },
    .{ .name = "try", .tags = "try try_cold", .obligations = "void error-union payload, reached error arm, local branch destinations, typed success continuation", .interpretation = "Control.Code.branch / Memory.unwrapError", .controls = "test/native/error_status.zig" },
    .{ .name = "stack_allocation", .tags = "alloc", .obligations = "stack kind, complete layout, fresh lifetime, modeled room", .interpretation = "Memory.allocate", .controls = "lean/Compiler/Tests/ZigAir/MemoryResourceControls.lean" },
    .{ .name = "load", .tags = "load slice_elem_val ptr_elem_val", .obligations = "live provenance, logical extent, alignment, typed initialized storage", .interpretation = "Memory.load", .controls = "test/native/byte_reads.zig" },
    .{ .name = "store", .tags = "store store_safe", .obligations = "live writable provenance, extent, alignment, stored type", .interpretation = "Memory.store", .controls = "test/native/cases/air.zig" },
    .{ .name = "byte_copy", .tags = "memcpy", .origin = .source_and_air, .obligations = "original length equality, live extents, permission, non-overlap, initialization transport, prefix effects", .interpretation = "MemoryAir.Prim.checkCopyLengths / Memory.ByteRange.copy", .controls = "test/native/bulk_copy.zig" },
    .{ .name = "byte_move", .tags = "memmove", .origin = .source_and_air, .obligations = "original length equality, live extents, permission, overlap-safe initialization transport, prefix effects", .interpretation = "MemoryAir.Prim.checkCopyLengths / Memory.ByteRange.move", .controls = "test/native/bulk_copy.zig" },
    .{ .name = "undefined_slice_fill", .tags = "memset", .obligations = "writable scalar slice, exact undefined element type, live declared extent, prefix invalidation effects", .interpretation = "Memory.SliceInvalidation.run", .controls = "test/native/bulk_copy.zig" },
    .{ .name = "pointer_arithmetic", .tags = "ptr_add ptr_sub ptr_elem_ptr slice_elem_ptr", .obligations = "live allocation, arithmetic range, geometry, logical slice extent", .interpretation = "MemoryAir.Prim.eval", .controls = "test/native/bounded_slices.zig" },
    .{ .name = "view", .tags = "ptr_cast array_to_slice slice", .origin = .source_and_air, .obligations = "retained source slice bounds and unique anchor, original extent, permissions, complete view; explicit contracts for specialized casts", .interpretation = "Memory.pointerCast / Memory.sourceBounds / MemoryAir.Prim.eval", .controls = "test/native/bounded_slices.zig" },
    .{ .name = "slice_projection", .tags = "slice_len slice_ptr ptr_slice_len_ptr ptr_slice_ptr_ptr", .obligations = "slice owner, field geometry, permissions, element type", .interpretation = "MemoryAir.Prim.eval", .controls = "test/native/cases/air.zig" },
    .{ .name = "record_projection", .tags = "struct_field_ptr struct_field_ptr_index_0 struct_field_ptr_index_1 struct_field_ptr_index_2 struct_field_ptr_index_3", .obligations = "complete owner identity and layout, declared index, extent, permission, unused result for zero-storage fields", .interpretation = "Memory.fieldPointer / Memory.checkZeroField", .controls = "test/native/record_fields.zig" },
    .{ .name = "direct_call", .tags = "call call_never_inline call_never_tail", .obligations = "declaration owner, exact signature, source closure, specialization, calls permitted by the selected profile", .interpretation = "MemoryCall.Prim.eval / MemoryPartialCall.Prim.eval / MemoryCallMachine.step", .controls = "test/native/call_admission.zig" },
    .{ .name = "structured_control", .tags = "block cond_br br", .obligations = "SSA dominance, unique body ownership, typed targets, operation order", .interpretation = "Control.Machine.step", .controls = "test/native/cases/air.zig" },
    .{ .name = "integer_switch", .tags = "switch_br", .obligations = "disjoint typed arms, supported default or complete enum coverage", .interpretation = "Scalar.Prim.inRanges / Scalar.Prim.enumInTags / Control.Code.branch", .controls = "test/native/integer_switch.zig" },
    .{ .name = "loop", .tags = "loop repeat", .obligations = "enabled profile, enclosing target, prefix effects; client invariant for verification", .interpretation = "Control.Machine.step", .controls = "test/native/cases/air.zig" },
    .{ .name = "return", .tags = "ret ret_safe", .obligations = "signature result, cleanup; result type alone does not establish lifetime", .interpretation = "MemoryAir.Program.finish", .controls = "lean/Compiler/Tests/ZigAir/MemoryCallControls.lean" },
    .{ .name = "unreachable", .tags = "unreach", .obligations = "retain reached failure and preceding effects", .interpretation = "MemoryAir.Prim.eval", .controls = "test/native/byte_reads.zig" },
    .{ .name = "debug", .tags = "dbg_stmt dbg_var_val dbg_var_ptr dbg_arg_inline", .origin = .debug_metadata, .obligations = "exact tag, unit type and debugOnly flag", .interpretation = "erased metadata", .controls = "test/native/cases/air.zig" },
};

pub fn lookup(tag: []const u8) ?*const Operation {
    for (&operations) |*operation| {
        var tags = std.mem.tokenizeScalar(u8, operation.tags, ' ');
        while (tags.next()) |candidate| if (std.mem.eql(u8, tag, candidate)) return operation;
    }
    return null;
}

pub fn require(ctx: *c.Context, tag: []const u8) c.Error!void {
    if (lookup(tag) == null) return ctx.fail("operation absent from {s}: {s}", .{ schema, tag });
}

pub fn report(ctx: *c.Context) c.Error!c.Value {
    var call_profiles: c.Value = .{ .object = .empty };
    for (std.meta.tags(@import("types.zig").Profile)) |profile| {
        const capabilities = profile.capabilities();
        try call_profiles.object.put(ctx.allocator, profile.name(), .{ .string = if (capabilities.recursive_calls) "recursive" else if (capabilities.calls) "acyclic" else "unsupported" });
    }
    return ctx.parse(try ctx.json(.{
        .schema = schema,
        .directCallGraphs = call_profiles,
        .operations = operations,
        .coverage = "reached AIR vocabulary plus selected pre-elimination slice and copy obligations",
        .sourceRequirementsComplete = false,
        .sourceSafetyVerified = false,
        .nativeRefinementVerified = false,
        .admissionRequires = "profile, target, type, reference, layout, source-owner and specialization checks in addition to the vocabulary gate",
        .rejected = [_][]const u8{ "unknown reached tags", "unrecorded or unanchored slice obligations", "indirect calls", "native allocator vtables", "FFI", "volatile or atomic memory", "unsupported pointer and layout forms" },
    }));
}
