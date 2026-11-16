// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Validated model configurations. A name denotes one admitted configuration,
//! not a promise that arbitrary targets share these layouts.
const c = @import("common.zig");

pub const Model = enum { scalar, aarch64_macos_le64 };
pub const pointer_bits = 64;
pub const pointer_bytes = 8;
pub const pointer_alignment = 8;

pub fn admit(ctx: *c.Context, config: c.Value, memory: bool) c.Error!Model {
    try ctx.require(c.tag(config, "optimize", "ReleaseFast") and c.flag(config, "useLlvm", true) and c.flag(config, "isTest", false), "unsupported AIR build configuration");
    if (!memory) return .scalar;
    try ctx.require(c.tag(config, "arch", "aarch64") and c.tag(config, "os", "macos") and try ctx.nat(try ctx.field(config, "pointerBits"), pointer_bits) == pointer_bits and c.tag(config, "endianness", "little"), "unsupported memory target configuration");
    return .aarch64_macos_le64;
}
