/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Counter.Wide.Generated

/-! The same reasoning covers all 2^32 inputs without enumerating them. -/
namespace Compiler.Tutorial.Counter.Wide
open Compiler.ZigAir Compiler.ZigAir.Scalar

def specification (x : Int) : Int := min (x + 2) 4294967295

theorem advance_correct (x : Int) (lo : 0 ≤ x) (hi : x < 4294967296) :
    Generated.fn_advance.run [.int false 32 x] =
      .ok (.int false 32 (specification x)) := by
  by_cases increment : x < 4294967294
  · have result_lo : 0 ≤ x + 2 := by omega
    have result_hi : x + 2 < 4294967296 := by omega
    have cap : x + 2 ≤ 4294967295 := by omega
    simp [Generated.fn_advance, specification, Int.min_eq_left cap,
      Program.run, Code.eval, Control.Code.eval, controlSemantics, Outcome.ofControl,
      Prim.eval, Ref.eval, Control.Env.set, Value.hasType, Value.type, Value.valid,
      Ty.contains, Ty.lower, Ty.upper, integer, Arithmetic.eval, Comparison.eval,
      bind, Except.bind, lo, hi, increment, result_lo, result_hi]
  · have cap : 4294967295 ≤ x + 2 := by omega
    simp [Generated.fn_advance, specification, Int.min_eq_right cap,
      Program.run, Code.eval, Control.Code.eval, controlSemantics, Outcome.ofControl,
      Prim.eval, Ref.eval, Control.Env.set, Value.hasType, Value.type, Value.valid,
      Ty.contains, Ty.lower, Ty.upper, integer, Arithmetic.eval, Comparison.eval,
      bind, Except.bind, lo, hi, increment]

theorem advance_safe (x : Int) (lo : 0 ≤ x) (hi : x < 4294967296) :
    ∃ result, Generated.fn_advance.run [.int false 32 x] = .ok (.int false 32 result) ∧
      x ≤ result ∧ result ≤ 4294967295 := by
  refine ⟨specification x, advance_correct x lo hi, ?_, ?_⟩
  all_goals simp only [specification]; omega

end Compiler.Tutorial.Counter.Wide
