// Copyright (C) 2026 OKcontract Pte. Ltd.
// SPDX-License-Identifier: Apache-2.0
//! Verification-only source requirements. No AIR instructions are inserted.
//! This is selected coverage, not a proof that all Zig validity is preserved.
const std = @import("std");
const Air = @import("Air.zig");
const Sema = @import("Sema.zig");
const Type = @import("Type.zig");
const Zcu = @import("Zcu.zig");

pub const Slice = struct {
    src: Zcu.LazySrcLoc,
    /// Before the fresh result instruction, after the bound operands exist.
    /// A reused/constant result has no unique execution position and rejects.
    anchor: ?Air.Inst.Index,
    start: Air.Inst.Ref,
    end: Air.Inst.Ref,
    bound: union(enum) { array: u64, slice: Air.Inst.Ref, unbounded, unsupported },
    unsupported: ?enum { sentinel, c_pointer } = null,
};

pub const Copy = struct {
    instruction: ?Air.Inst.Index,
    destination_length: Air.Inst.Ref,
    source_length: Air.Inst.Ref,
    destination: Air.Inst.Ref = .none,
    source: Air.Inst.Ref = .none,
};

/// The original lengths survive slice decay and static array-pointer upgrades.
pub fn recordCopy(sema: *Sema, result: Air.Inst.Ref, destination: Air.Inst.Ref, source: Air.Inst.Ref, destination_length: Air.Inst.Ref, source_length: Air.Inst.Ref) std.mem.Allocator.Error!void {
    if (sema.pt.zcu.comp.semantic_export_dir == null) return;
    try sema.semantic_export_copies.append(sema.gpa, .{
        .instruction = result.toIndex(),
        .destination_length = destination_length,
        .source_length = source_length,
        .destination = destination,
        .source = source,
    });
}

pub fn recordErasedCopy(sema: *Sema, comptime_block: bool, destination: Air.Inst.Ref, source: Air.Inst.Ref) std.mem.Allocator.Error!void {
    if (comptime_block or destination == .none or source == .none or destination == source) return;
    if (destination.toIndex() != null or source.toIndex() != null)
        try recordCopy(sema, .none, .none, .none, destination, source);
}

pub fn recordSlice(
    sema: *Sema,
    comptime_block: bool,
    src: Zcu.LazySrcLoc,
    result: Air.Inst.Ref,
    first_result_index: usize,
    original: Air.Inst.Ref,
    slice_ty: Type,
    array_ty: Type,
    start: Air.Inst.Ref,
    end: Air.Inst.Ref,
    explicit_sentinel: bool,
) std.mem.Allocator.Error!void {
    const zcu = sema.pt.zcu;
    if (zcu.comp.semantic_export_dir == null or comptime_block) return;
    var item: Slice = .{
        .src = src,
        .anchor = if (result.toIndex()) |index|
            (if (@backingInt(index) >= first_result_index) index else null)
        else
            null,
        .start = start,
        .end = end,
        .bound = if (array_ty.zigTypeTag(zcu) == .array)
            .{ .array = array_ty.arrayLen(zcu) }
        else if (slice_ty.isSlice(zcu))
            .{ .slice = original }
        else
            .unbounded,
    };
    if (explicit_sentinel or slice_ty.sentinel(zcu) != null or array_ty.sentinel(zcu) != null) {
        item.unsupported = .sentinel;
        item.bound = .unsupported;
    } else if (slice_ty.isCPtr(zcu)) {
        item.unsupported = .c_pointer;
        item.bound = .unsupported;
    }
    // Sema owns this list until successful AIR transfer. OOM fails analysis;
    // it must never leave a successful export with an omitted requirement.
    try sema.semantic_export_slices.append(sema.gpa, item);
}
