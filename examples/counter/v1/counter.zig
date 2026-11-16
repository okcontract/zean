// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.

/// Advance a byte counter by one, saturating at 255.
pub export fn advance(value: u8) u8 {
    return if (value < 255) value + 1 else 255;
}
