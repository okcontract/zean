/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.Verify.Core

/-! The former finite-only WP controls use the common verification semantics.
The finite interpreter remains available through the proved `finite_sound`
bridge; it no longer has a second set of instruction specifications. -/
namespace Compiler.ZigAir.MemoryAir.Verify.FiniteControls
open Memory Std.WP Control.Verification
set_option maxRecDepth 4096

theorem missing_argument (state : State) :
    Triple (Task.code (.bind 0 (.scalar .unit) (.argument 0)
      (.ret (.constant (.scalar .unit)))) (fun _ => none) : Task semantics [] (fun _ _ _ => False))
      (fun before => before = state) (fun _ _ => False)
      (fun fault after => fault = .malformed ∧ after = state) := by
  air_vcgen

theorem argument_return (state : State) :
    Triple (Task.code (.bind 0 (.scalar .unit) (.argument 0) (.ret (.local 0))) (fun _ => none) :
      Task semantics [.scalar .unit] (fun _ _ _ => False))
      (fun before => before = state)
      (fun value after => value = .returned (.scalar .unit) ∧ after = state) (fun _ _ => False) := by
  air_vcgen

theorem store_then_fault (before after : State) (pointer value : Value)
    (pointerValid : pointer.valid = true) (valueValid : value.valid = true)
    (stored : store before pointer value = .ok after) :
    Triple (Task.code (.bind 0 (.scalar .unit) (.store (.constant pointer) (.constant value))
      (.bind 1 (.scalar .unit) (.argument 0) (.ret (.constant (.scalar .unit))))) (fun _ => none) :
      Task semantics [] (fun _ _ _ => False))
      (fun state => state = before) (fun _ _ => False)
      (fun fault state => fault = .malformed ∧ state = after) := by
  air_vcgen

theorem branch_selects_effect (state : State) (flag : Bool) :
    Triple (Task.code (.branch (.constant (.scalar (.bool flag)))
      (.ret (.constant (.scalar .unit)))
      (.bind 0 (.scalar .unit) (.argument 0) (.ret (.constant (.scalar .unit))))) (fun _ => none) :
      Task semantics [] (fun _ _ _ => False))
      (fun before => before = state)
      (fun exit after => flag = true ∧ exit = .returned (.scalar .unit) ∧ after = state)
      (fun fault after => flag = false ∧ fault = .malformed ∧ after = state) := by
  cases flag <;> air_vcgen

theorem block_carries_locals (state : State) :
    Triple (Task.code (.block 7 (.scalar .unit)
      (.bind 9 (.scalar .unit) (.argument 0) (.jump 7 (.local 9))) (.ret (.local 9))) (fun _ => none) :
      Task semantics [.scalar .unit] (fun _ _ _ => False))
      (fun before => before = state)
      (fun exit after => exit = .returned (.scalar .unit) ∧ after = state) (fun _ _ => False) := by
  air_vcgen

/-- The bound is a logical source extent. Both outcomes preserve the state;
success returns the exact unit value even when the bound is symbolic. -/
theorem source_bounds (state : State) (env : Env) (start finish : Ref) (count limit : Nat)
    (first : start.natural env = .ok 0) (last : finish.natural env = .ok count) :
    Triple (Atomic.mk (sem := semantics) (args := []) (.checkBounds start finish (.array limit)) env)
      (fun before => before = state)
      (fun value after => count ≤ limit ∧ value = .scalar .unit ∧ after = state)
      (fun fault after => limit < count ∧ fault = .sourceBounds ∧ after = state) := by
  by_cases fits : count ≤ limit
  all_goals set_option experimental.vcgen true in vcgen
  all_goals air_conditions
  all_goals simp_all [Bound.eval, checkSliceBounds, bind, Except.bind]
  all_goals split at * <;> simp_all

theorem finite_echo (state : State) (valid : state.valid = true) :
    (Program.mk [.scalar .unit] (.scalar .unit)
      (.bind 0 (.scalar .unit) (.argument 0) (.ret (.local 0)))).run [.scalar .unit] state =
        (.ok (.scalar .unit), state) := by
  have contract : Triple (Invocation.mk
      (Program.mk [.scalar .unit] (.scalar .unit)
        (.bind 0 (.scalar .unit) (.argument 0) (.ret (.local 0)))).enableLoops
      [.scalar .unit] (fun _ _ _ => False))
      (fun before => before = state) (fun value after => value = .scalar .unit ∧ after = state)
      (fun _ _ => False) := by
    air_vcgen
    air_finish
  have checked := finite_sound _ _ _ _ _ contract state rfl
  generalize (Program.mk [.scalar .unit] (.scalar .unit)
    (.bind 0 (.scalar .unit) (.argument 0) (.ret (.local 0)))).run [.scalar .unit] state = result at checked ⊢
  obtain ⟨result, after⟩ := result
  cases result with
  | error => exact False.elim checked
  | ok value => obtain ⟨rfl, rfl⟩ := checked; rfl

end Compiler.ZigAir.MemoryAir.Verify.FiniteControls
