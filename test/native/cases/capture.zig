// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
// Immutable reference controls with shared fixtures and explicit mutations.
const f = @import("../fixtures.zig");
const shared = @import("shared.zig");
const golden = @import("golden.zig");

const fixture_0 = f.obj(&.{
    .{ "files", f.obj(&.{
        .{ "root.json", f.ref(&shared.capture_fixture_0_files_root_json_281) },
    }) },
    .{ "roots", f.arr(&.{
        f.s("fixture.add"),
    }) },
    .{ "sha", f.s("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") },
    .{ "mode", f.s("ReleaseFast") },
    .{ "output", f.obj(&.{
        .{ "fixture.add", f.obj(&.{
            .{ "file", f.s("root.json") },
            .{ "sha256", f.s("fd8d588ce1beee919ef9181b453329623303dfc186b023212a8e1eee54be13e5") },
            .{ "requested", f.b(true) },
            .{ "instructionCount", f.n("1") },
            .{ "sourceOperationTags", f.arr(&.{
                f.s("addwrap"),
                f.s("ret_node"),
            }) },
            .{ "sourceValiditySliceCount", f.n("0") },
            .{ "unsupportedPayloadCount", f.n("1") },
        }) },
    }) },
    .{ "reject", f.b(false) },
});

const fixture_1 = f.obj(&.{
    .{ "files", f.obj(&.{
        .{ "one.json", f.ref(&shared.capture_fixture_0_files_root_json_281) },
        .{ "two.json", f.ref(&shared.capture_fixture_0_files_root_json_281) },
    }) },
    .{ "roots", f.arr(&.{
        f.s("fixture.add"),
    }) },
    .{ "sha", f.s("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") },
    .{ "mode", f.s("ReleaseFast") },
    .{ "reject", f.b(true) },
});

pub const cases = blk: {
    @setEvalBranchQuota(50_000);
    break :blk [_]f.Value{
        // Control 0
        f.derive(&fixture_0, &.{
            f.text("/files/root.json", &.{
                .{ .at = 12, .old = "oksolc.fresh-air.v3", .new = "future" },
            }),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 1
        f.derive(&fixture_0, &.{
            f.text("/files/root.json", &.{
                .{ .at = 57, .old = "sema-before-", .new = "" },
            }),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 2
        f.derive(&fixture_0, &.{
            f.text("/files/root.json", &.{
                .{ .at = 120, .old = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", .new = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
            }),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 3
        f.derive(&fixture_0, &.{
            f.text("/files/root.json", &.{
                .{ .at = 224, .old = "fals", .new = "tru" },
            }),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 4
        f.derive(&fixture_0, &.{
            f.text("/files/root.json", &.{
                .{ .at = 249, .old = "{\"schema\": \"oksolc.source-validity.v1\", \"coverage\": \"runtime-slice-results\", \"complete\": false, \"slices\": []}", .new = "null" },
            }),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 5
        f.derive(&fixture_0, &.{
            f.text("/files/root.json", &.{
                .{ .at = 250, .old = "\"schema\": \"oksolc.source-validity.v1\", \"coverage\": \"runtime-slice-results\", \"complete\": false, \"slices\": []", .new = "" },
            }),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 6
        f.derive(&fixture_0, &.{
            f.text("/files/root.json", &.{
                .{ .at = 338, .old = "fals", .new = "tru" },
            }),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 7
        f.derive(&fixture_0, &.{
            f.text("/files/root.json", &.{
                .{ .at = 338, .old = "false", .new = "0" },
            }),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 8
        f.derive(&fixture_0, &.{
            f.text("/files/root.json", &.{
                .{ .at = 384, .old = "\"addwrap\", \"ret_node\"", .new = "" },
            }),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 9
        f.derive(&fixture_0, &.{
            f.text("/files/root.json", &.{
                .{ .at = 385, .old = "addwrap\", \"ret_node", .new = "ret\", \"ret" },
            }),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 10
        f.derive(&fixture_0, &.{
            f.text("/files/root.json", &.{
                .{ .at = 497, .old = "0", .new = "1" },
            }),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 11
        f.derive(&fixture_0, &.{
            f.text("/files/root.json", &.{
                .{ .at = 497, .old = "0", .new = "true" },
            }),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 12
        f.derive(&fixture_0, &.{
            f.text("/files/root.json", &.{
                .{ .at = 528, .old = "0, \"tag\": \"future_opcode\", \"unsupportedPayload\": true", .new = "1, \"tag\": \"ret\"" },
            }),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 13
        f.derive(&fixture_0, &.{
            f.text("/files/root.json", &.{
                .{ .at = 439, .old = "ReleaseFast", .new = "Debug" },
            }),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 14
        f.derive(&fixture_0, &.{
            f.text("/files/root.json", &.{
                .{ .at = 464, .old = "tru", .new = "fals" },
            }),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 15
        f.derive(&fixture_0, &.{
            f.text("/files/root.json", &.{
                .{ .at = 480, .old = "fals", .new = "tru" },
            }),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 16
        f.ref(&fixture_1),
        // Control 17
        f.derive(&fixture_1, &.{
            f.set("/files/two.json", f.obj(&.{
                .{ "symlink", f.s("one.json") },
            })),
        }),
        // Control 18
        f.derive(&fixture_0, &.{
            f.set("/roots/0", f.s("fixture.missing")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 19
        f.derive(&fixture_0, &.{
            f.add("/roots/1", f.s("fixture.add")),
            f.remove("/output"),
            f.set("/reject", f.b(true)),
        }),
        // Control 20
        f.ref(&fixture_0),
    };
};
