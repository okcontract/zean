// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Runtime verification kernels derived from Ziglings 038 and 054.
//! These kernels isolate initialization and pointer extent; see README.md for
//! the differences from the pinned exercises and the scope of the proofs.

/// Exercise 038: both character gold fields must be initialized before reading.
/// The caller supplies two writable u32 slots and an index below two.
pub export fn initialize_pair(gold: [*]u32, first: u32, second: u32, index: usize) u32 {
    gold[0] = first;
    gold[1] = second;
    return gold[index];
}

/// Deliberately broken model control. Never run on uninitialized native storage.
pub export fn missing_character(gold: [*]u32, first: u32, second: u32, index: usize) u32 {
    _ = second;
    gold[0] = first;
    return gold[index];
}

/// Exercise 054: a many-pointer needs an extent before it can become a slice.
/// The caller supplies length initialized bytes in one live allocation.
pub export fn phrase_byte(bytes: [*]const u8, length: usize, index: usize) u8 {
    if (index >= length) return 0;
    return bytes[0..length][index];
}

/// Deliberately broken model control: inventing a larger slice is not a proof
/// that the extra byte exists. Never run outside the native allocation.
pub export fn exaggerated_byte(bytes: [*]const u8, length: usize, index: usize) u8 {
    if (index >= length + 1) return 0;
    return bytes[0 .. length + 1][index];
}
