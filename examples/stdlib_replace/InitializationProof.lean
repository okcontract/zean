/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Components.Replace.Controls

-- Expected rejection: a valid writable heap can contain unreadable words.
open Compiler.Components.Replace.Controls
example : result (run incomplete view) = some (.ok (.scalar .unit)) := by
  rw [missing_initialization_faults]
  rfl
