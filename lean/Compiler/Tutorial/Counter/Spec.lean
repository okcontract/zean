/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.Scalar

/-! Handwritten specification shared by both counter versions.
The executable model uses mathematical integers with explicit byte bounds. -/
namespace Compiler.Tutorial.Counter.Spec

def advance (step x : Int) : Int := min (x + step) 255

theorem bounds (step x : Int) (step_nonnegative : 0 ≤ step) (below_cap : x ≤ 255) :
    x ≤ advance step x ∧ advance step x ≤ 255 := by
  constructor
  · exact Int.le_min.mpr ⟨by omega, below_cap⟩
  · exact Int.min_le_right _ _

end Compiler.Tutorial.Counter.Spec
