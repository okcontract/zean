/-
// Copyright (C) 2026 OKcontract Pte. Ltd.
// SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryScalarBytes
import Compiler.ZigAir.MemoryByteCopy
import Compiler.ZigAir.MemoryStackFrame

/-! Byte-range operations for captured AIR. Reads resolve the original typed
integer leaves; padding and undefined storage never acquire invented bytes.
Writes use the ordinary byte store. A failed copy retains its completed prefix.
The caller's slice checks and the non-overlap requirement remain explicit. -/
