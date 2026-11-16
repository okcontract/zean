/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Counter.V1.Proofs
import Compiler.Tutorial.Counter.V2.Proofs
import Compiler.Tutorial.Counter.Broken.Proofs
import Compiler.Tutorial.Counter.Wide.Proofs

/-! Handwritten comparison of the two generated programs after the source update. -/
namespace Compiler.Tutorial.Counter

theorem update_progress (x : Int) (lo : 0 ≤ x) (hi : x < 256) :
    ∃ before after,
      V1.Generated.fn_advance.run [.int false 8 x] = .ok (.int false 8 before) ∧
      V2.Generated.fn_advance.run [.int false 8 x] = .ok (.int false 8 after) ∧
      before ≤ after ∧ after ≤ before + 1 := by
  refine ⟨Spec.advance 1 x, Spec.advance 2 x,
    V1.advance_correct x lo hi, V2.advance_correct x lo hi, ?_, ?_⟩
  all_goals simp only [Spec.advance]; omega

theorem old_contract_is_false_for_v2 :
    V2.Generated.fn_advance.run [.int false 8 0] ≠ .ok (.int false 8 1) := by
  change (Except.ok (Compiler.ZigAir.Scalar.Value.int false 8 2) :
    Compiler.ZigAir.Scalar.Result) ≠ .ok (.int false 8 1)
  simp

end Compiler.Tutorial.Counter
