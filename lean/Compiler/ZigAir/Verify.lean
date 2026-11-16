/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.Verify.Machine
import Compiler.ZigAir.Verify.Records
import Compiler.ZigAir.Verify.Lifetimes
import Compiler.ZigAir.Verify.Slices
import Compiler.ZigAir.Verify.Reads
import Compiler.ZigAir.Verify.Bytes

/-! Convenience import for all verification domains. Prefer `Verify.Core`,
`Verify.Machine`, `Verify.Records`, `Verify.Words`, `Verify.Slices`,
`Verify.Reads` or `Verify.Bytes` when a smaller interface suffices.
`MemoryAir.Verify.finite_sound` connects contracts to the finite evaluator;
`sound` covers every resumable machine prefix. -/
