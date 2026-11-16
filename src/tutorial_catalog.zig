// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Handwritten tutorial adapter inventory. Generated models and proof clients
//! remain separate; generic client manifests do not depend on this catalog.
const std = @import("std");
const c = @import("common.zig");

const Version = struct { source: []const u8, module: []const u8 };
const counter_versions = [_]Version{
    .{ .source = "v1", .module = "V1" },
    .{ .source = "v2", .module = "V2" },
    .{ .source = "broken", .module = "Broken" },
    .{ .source = "u32", .module = "Wide" },
};
const buffer_versions = [_]Version{
    .{ .source = "v1", .module = "V1" },
    .{ .source = "v2", .module = "V2" },
    .{ .source = "broken", .module = "Broken" },
};
pub const Kind = enum {
    counter,
    buffer,
    copy,
    calls,
    stdlib_replace,
    ziglings,

    pub fn module(self: Kind) []const u8 {
        return switch (self) {
            .counter => "Counter",
            .buffer => "Buffer",
            .copy => "Copy",
            .calls => "Calls",
            .stdlib_replace => "Replace",
            .ziglings => "Ziglings",
        };
    }
    pub fn package(self: Kind, ctx: *c.Context) ![]const u8 {
        return switch (self) {
            .stdlib_replace => "Compiler.Components.Replace",
            else => ctx.fmt("Compiler.Tutorial.{s}", .{self.module()}),
        };
    }
    pub fn proofPath(self: Kind, ctx: *c.Context, name: []const u8) ![]const u8 {
        const directory = try ctx.allocator.dupe(u8, try self.package(ctx));
        std.mem.replaceScalar(u8, directory, '.', '/');
        return ctx.fmt("lean/{s}/{s}.lean", .{ directory, name });
    }
    pub fn sourceName(self: Kind) []const u8 {
        return if (self == .stdlib_replace) "replace" else @tagName(self);
    }
    pub fn roots(self: Kind) []const []const u8 {
        return switch (self) {
            .counter => &.{"counter.advance"},
            .buffer => &.{"buffer.replace"},
            .copy => &.{ "copy.copy", "copy.copy_word" },
            .calls => &.{"calls.update"},
            .stdlib_replace => &.{"replace.replace"},
            .ziglings => &.{ "ziglings.initialize_pair", "ziglings.missing_character", "ziglings.phrase_byte", "ziglings.exaggerated_byte" },
        };
    }
    pub fn translationRoots(self: Kind) []const []const u8 {
        return switch (self) {
            .stdlib_replace => &.{"mem.replaceScalar__func_0"},
            else => self.roots(),
        };
    }
    pub fn versions(self: Kind) []const Version {
        return switch (self) {
            .counter => &counter_versions,
            .buffer => &buffer_versions,
            .copy, .calls, .stdlib_replace, .ziglings => &.{.{ .source = "", .module = "" }},
        };
    }
    pub fn generatedModule(self: Kind, ctx: *c.Context, version: Version) ![]const u8 {
        return if (version.module.len == 0) ctx.fmt("{s}.Generated", .{try self.package(ctx)}) else ctx.fmt("{s}.{s}.Generated", .{ try self.package(ctx), version.module });
    }
    pub fn imports(self: Kind) []const []const u8 {
        if (self == .ziglings) return &.{
            "Compiler.ZigAir.MemoryAir",
            "Compiler.ZigAir.Verify.Words",
            "Compiler.ZigAir.Verify.Reads",
        };
        if (self == .stdlib_replace) return &.{
            "Compiler.ZigAir.MemoryExecution",
            "Compiler.ZigAir.Verify.Slices",
            "Compiler.ZigAir.MemorySliceWP",
            "Compiler.ZigAir.MemoryInitializedWords",
            "Compiler.ZigAir.MemorySliceAutomation",
        };
        if (self == .calls) return &.{
            "Compiler.ZigAir.MemoryCallMachineTermination",
            "Compiler.ZigAir.MemoryCallMachine",
            "Compiler.ZigAir.Verify.Machine",
            "Compiler.ZigAir.Verify.Words",
            "Compiler.ZigAir.MemoryCleanupContracts",
            "Compiler.Tutorial.Buffer.Contracts",
        };
        if (self == .copy) return &.{
            "Compiler.ZigAir.MemoryExecution",
            "Compiler.ZigAir.Verify.Words",
            "Compiler.ZigAir.MemoryBorrowedWords",
            "Compiler.ZigAir.MemoryBindings",
        };
        return if (self == .counter) &.{"Compiler.ZigAir.Scalar"} else &.{
            "Compiler.ZigAir.MemoryAir",
            "Compiler.ZigAir.MemoryAirLaws",
            "Compiler.ZigAir.MemoryStackPrefix",
            "Compiler.ZigAir.MemoryWordCopyFrame",
            "Compiler.ZigAir.MemoryWordCallFrame",
            "Compiler.ZigAir.MemoryWordArrayTypes",
            "Compiler.ZigAir.MemoryWordFrameVerification",
            "Compiler.ZigAir.Verify.Words",
        };
    }
    pub fn proofs(self: Kind) []const []const u8 {
        if (self == .ziglings) return &.{ "Initialization", "Bounds", "Proofs", "Controls" };
        if (self == .stdlib_replace) return &.{ "Proofs", "Controls" };
        if (self == .calls) return &.{"Proofs"};
        if (self == .copy) return &.{ "Helper", "Contracts", "Verification", "Proofs", "Controls" };
        return if (self == .counter) &.{ "V1/Proofs", "V2/Proofs", "Broken/Proofs", "Wide/Proofs", "Comparison" } else &.{ "Inputs", "Contracts", "Verification", "Proofs", "Broken/Proofs" };
    }
    pub fn negatives(self: Kind) []const []const u8 {
        if (self == .ziglings) return &.{ "InitializationProof", "BoundsProof" };
        if (self == .stdlib_replace) return &.{ "InitializationProof", "PermissionProof" };
        if (self == .calls) return &.{"BoundsProof"};
        if (self == .copy) return &.{ "InitializationProof", "BoundsProof", "OverlapProof" };
        return if (self == .counter) &.{ "StaleProof", "BrokenProof" } else &.{ "BrokenProof", "FrameProof" };
    }
};
