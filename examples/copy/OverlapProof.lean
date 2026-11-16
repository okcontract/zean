/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Copy.Controls

-- Expected rejection: this forward copy does not preserve an overlapping source.
open Compiler.ZigAir.Memory Compiler.ZigAir.Memory.WordArray Compiler.Tutorial.Copy.Controls
example : load (run shared ⟨0, 1, 3⟩ source).state (source.pointer 1) = .ok (number 20) := by
  rw [overlapping_copy_changes_source]
  rfl
