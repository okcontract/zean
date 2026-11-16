/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Copy.Controls

-- Expected rejection: a length argument does not establish accessible storage.
open Compiler.Tutorial.Copy.Controls
example : result (run caller { target with length := 4 } { source with length := 4 }) =
    some (.ok (.scalar .unit)) := by
  rw [exaggerated_length_faults]
  rfl
