// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.

pub const common = @import("common.zig");
pub const air = @import("air.zig");
pub const admission = @import("admission.zig");
pub const atomic_publication = @import("atomic_publication.zig");
pub const target = @import("target.zig");
pub const proof_replay = @import("proof_replay.zig");
pub const client = @import("client.zig");
pub const project = @import("project.zig");
pub const bundled_compiler = @import("bundled_compiler.zig");

pub const component = @import("component.zig");
pub const translate = @import("translate.zig");
pub const source = @import("source.zig");
pub const runtime = @import("runtime.zig");
pub const patch = @import("patch.zig");
pub const toolchain = @import("toolchain.zig");
pub const capture = @import("capture.zig");
pub const capture_stdlib = @import("capture_stdlib.zig");
pub const Arguments = @import("arguments.zig").Arguments;
pub const project_root = @import("build_options").project_root;

pub const version = "0.17.1";
pub const revision = "be248cc1fdc3cc654f9ec8ba68514bcb93b204fe";

test {
    _ = common;
    _ = air;
}

pub const specialization = @import("specialization.zig");

pub const word_swap = @import("word_swap.zig");

pub const audit = @import("audit.zig");
pub const provenance = @import("provenance.zig");
pub const counter = @import("counter.zig");
pub const buffer = @import("buffer.zig");
pub const tutorial = @import("tutorial.zig");
pub const benchmark = @import("benchmark.zig");
pub const certificate = @import("certificate.zig");
pub const specialized_source = @import("specialized_source.zig");
pub const declaration_source = @import("declaration_source.zig");

pub const evidence = @import("evidence.zig");
pub const files = @import("files.zig");
pub const call_closure = @import("call_closure.zig");
pub const lean_toolchain = @import("build_options").lean_toolchain;
