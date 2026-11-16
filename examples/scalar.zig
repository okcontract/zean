// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.

export fn choose(value: u8) u8 {
    return if (value < 128) value + 1 else value;
}
