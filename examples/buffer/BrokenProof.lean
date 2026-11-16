/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Buffer.Broken.Proofs

-- Expected rejection: the modified guard reaches a memory-validity fault.
open Compiler.ZigAir.Memory Compiler.Tutorial.Buffer.Broken
example : boundary.1 = .ok (.scalar (.bool false)) := by
  rw [boundary_fault]
  rfl
