/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Copy.Controls

-- Expected rejection: heap validity does not imply initialized source words.
open Compiler.Tutorial.Copy.Controls
example : result (run incomplete target source) = some (.ok (.scalar .unit)) := by
  rw [missing_initialization_faults]
  rfl
