/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Calls.Generated

open Compiler.ZigAir.Memory Compiler.Tutorial.Calls

-- The actual captured callee rejects an empty logical buffer, even though the
-- supplied pointer has a valid pointer type. This deliberately false result
-- must fail after fresh regeneration as well as against the retained model.
example : (Compiler.ZigAir.MemoryCallMachine.run Generated.functions 100 Generated.FunctionId.fn_update
    [.pointer (.pointer true true (.scalar (.int false 32))) ⟨0, 0⟩,
      .scalar (.int false 64 0), .scalar (.int false 64 0), .scalar (.int false 32 7)] {}) =
    .finished (.ok (.scalar (.bool true))) {} := by
  rfl
