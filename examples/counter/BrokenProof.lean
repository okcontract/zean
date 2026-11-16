/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Counter.Broken.Generated

-- Intentionally false: the +2 edit retained the old +1 guard.
example : Compiler.Tutorial.Counter.Broken.Generated.fn_advance.run
    [.int false 8 254] = .ok (.int false 8 255) := by
  rfl
