/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Components.Replace.Controls

-- Expected rejection: initialization does not grant write permission.
open Compiler.Components.Replace.Controls
example : result (run readonly view) = some (.ok (.scalar .unit)) := by
  rw [missing_permission_faults]
  rfl
