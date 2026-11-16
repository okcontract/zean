// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.

/// Advance a 32-bit counter by two, saturating at 4294967295.
pub export fn advance(value: u32) u32 {
    return if (value < 4294967294) value + 2 else 4294967295;
}
