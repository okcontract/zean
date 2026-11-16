/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Counter.Broken.Generated

/-! A concrete witness for the intentionally broken source update.
Unchecked ReleaseFast overflow is illegal behavior in the scalar model. -/
namespace Compiler.Tutorial.Counter.Broken

theorem overflow_at_254 :
    Generated.fn_advance.run [.int false 8 254] = .error .illegalBehavior := by
  rfl

theorem saturation_contract_is_false :
    Generated.fn_advance.run [.int false 8 254] ≠ .ok (.int false 8 255) := by
  rw [overflow_at_254]
  simp

end Compiler.Tutorial.Counter.Broken
