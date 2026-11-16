/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Counter.Spec
import Compiler.Tutorial.Counter.V1.Generated

/-! Handwritten proofs about the generated version 1 program, for every byte.
These theorems establish model behavior, not Zig frontend/backend correctness. -/
namespace Compiler.Tutorial.Counter.V1
open Compiler.ZigAir Compiler.ZigAir.Scalar

theorem advance_correct (x : Int) (lo : 0 ≤ x) (hi : x < 256) :
    Generated.fn_advance.run [.int false 8 x] =
      .ok (.int false 8 (Spec.advance 1 x)) := by
  by_cases increment : x < 255
  · have result_lo : 0 ≤ x + 1 := by omega
    have result_hi : x + 1 < 256 := by omega
    have cap : x + 1 ≤ 255 := by omega
    simp [Generated.fn_advance, Spec.advance, Int.min_eq_left cap,
      Program.run, Code.eval, Control.Code.eval, controlSemantics, Outcome.ofControl,
      Prim.eval, Ref.eval, Control.Env.set, Value.hasType, Value.type, Value.valid,
      Ty.contains, Ty.lower, Ty.upper, integer, Arithmetic.eval, Comparison.eval,
      bind, Except.bind, lo, hi, increment, result_lo, result_hi]
  · have at_cap : x = 255 := by omega
    subst x
    rfl

theorem advance_safe (x : Int) (lo : 0 ≤ x) (hi : x < 256) :
    ∃ result, Generated.fn_advance.run [.int false 8 x] = .ok (.int false 8 result) ∧
      x ≤ result ∧ result ≤ 255 := by
  exact ⟨Spec.advance 1 x, advance_correct x lo hi, Spec.bounds 1 x (by omega) (by omega)⟩

end Compiler.Tutorial.Counter.V1
