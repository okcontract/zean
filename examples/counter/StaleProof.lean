/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Counter.V2.Generated

-- Intentionally false: version 2 advances zero to two, not one.
-- `zig build counter-stale-proof` checks both failure and the rfl diagnostic.
example : Compiler.Tutorial.Counter.V2.Generated.fn_advance.run
    [.int false 8 0] = .ok (.int false 8 1) := by
  rfl
