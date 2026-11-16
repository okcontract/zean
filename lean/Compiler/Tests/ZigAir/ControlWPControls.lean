/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.ControlWP
import Compiler.ZigAir.MemoryAirLaws

namespace Compiler.ZigAir.Control.Verification.Controls
open Memory MemoryAir Std.WP Machine
set_option experimental.vcgen true

/-- Safety does not require termination, or a finite fuel assumption. -/
theorem endless_contract (env : MemoryAir.Env) :
    Triple (Task.code (.loop rfl 41 (.repeat rfl 41)) env : Task semantics [] (fun _ _ _ => True))
      (fun _ => True) (rootPost semantics (fun _ _ => False) (fun _ _ => False)) (fun _ _ => False) := by
  vcgen with finish

theorem endless_no_fault (env : MemoryAir.Env) (state : State) (fuel : Nat) (fault : Memory.Fault) (after : State) :
    run semantics [] fuel ⟨.loop rfl 41 (.repeat rfl 41), env, state, []⟩ ≠ .finished (.fault fault after) := by
  intro reached
  exact fault_of_contract semantics [] (fun _ _ _ => True) _ env _ _ _
    (endless_contract env) state trivial fuel fault after reached

/-- An invalid back edge cannot acquire a loop invariant from another label. -/
theorem invalid_backedge (env : MemoryAir.Env) (state : State) :
    ¬pre semantics [] (fun _ _ _ => True) (.loop rfl 41 (.repeat rfl 42))
      (rootPost semantics (fun _ _ => False) (fun _ _ => False)) (fun _ _ => False) env state := by
  simp [pre, loopPost, rootPost]
  exact ⟨state, trivial⟩

theorem block_carries_locals (state : State) (flag : Bool) :
    Triple (Task.code (.block 7 (.scalar .unit)
      (.bind 9 (.scalar .bool) (.argument 0) (.jump 7 (.constant (.scalar .unit)))) (.ret (.local 9))) (fun _ => none) :
        Task semantics [.scalar (.bool flag)] (fun _ _ _ => False))
      (fun before => before = state)
      (fun flow after => flow = .returned (.scalar (.bool flag)) ∧ after = state) (fun _ _ => False) := by
  vcgen simplifying_assumptions [Prim.eval_argument, Ref.eval_local]
  all_goals simp [semantics, Ref.eval_local, Ref.eval_constant, Prim.eval_argument, Control.Env.set] at *
  all_goals grind [value_valid_of_hasType, Value.hasType, Value.type, Scalar.Value.type,
    Value.valid, Scalar.Value.valid]

end Compiler.ZigAir.Control.Verification.Controls
