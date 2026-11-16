/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Buffer.Broken.Proofs

-- Expected rejection even though the write stays inside the backing allocation.
open Compiler.ZigAir.Memory Compiler.Tutorial.Buffer.Broken
example : load escaped.2 (whole.pointer 2) = load caller (whole.pointer 2) := by
  rw [escaped_changes_neighbor.1, escaped_changes_neighbor.2]
  rfl
