// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.

/// Intentionally broken update: the old guard does not protect addition by two.
pub export fn advance(value: u8) u8 {
    return if (value < 255) value + 2 else 255;
}
