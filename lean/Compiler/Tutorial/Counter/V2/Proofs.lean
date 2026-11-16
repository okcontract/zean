/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Counter.Spec
import Compiler.Tutorial.Counter.V2.Generated

/-! Handwritten proof update: the step is now two and the safe-add guard is 254.
The shared bounds specification and theorem statement for safety are reused. -/
namespace Compiler.Tutorial.Counter.V2
open Compiler.ZigAir Compiler.ZigAir.Scalar

theorem advance_correct (x : Int) (lo : 0 ≤ x) (hi : x < 256) :
    Generated.fn_advance.run [.int false 8 x] =
      .ok (.int false 8 (Spec.advance 2 x)) := by
  by_cases increment : x < 254
  · have result_lo : 0 ≤ x + 2 := by omega
    have result_hi : x + 2 < 256 := by omega
    have cap : x + 2 ≤ 255 := by omega
    simp [Generated.fn_advance, Spec.advance, Int.min_eq_left cap,
      Program.run, Code.eval, Control.Code.eval, controlSemantics, Outcome.ofControl,
      Prim.eval, Ref.eval, Control.Env.set, Value.hasType, Value.type, Value.valid,
      Ty.contains, Ty.lower, Ty.upper, integer, Arithmetic.eval, Comparison.eval,
      bind, Except.bind, lo, hi, increment, result_lo, result_hi]
  · have cap : 255 ≤ x + 2 := by omega
    simp [Generated.fn_advance, Spec.advance, Int.min_eq_right cap,
      Program.run, Code.eval, Control.Code.eval, controlSemantics, Outcome.ofControl,
      Prim.eval, Ref.eval, Control.Env.set, Value.hasType, Value.type, Value.valid,
      Ty.contains, Ty.lower, Ty.upper, integer, Arithmetic.eval, Comparison.eval,
      bind, Except.bind, lo, hi, increment]

theorem advance_safe (x : Int) (lo : 0 ≤ x) (hi : x < 256) :
    ∃ result, Generated.fn_advance.run [.int false 8 x] = .ok (.int false 8 result) ∧
      x ≤ result ∧ result ≤ 255 := by
  exact ⟨Spec.advance 2 x, advance_correct x lo hi, Spec.bounds 2 x (by omega) (by omega)⟩

end Compiler.Tutorial.Counter.V2
