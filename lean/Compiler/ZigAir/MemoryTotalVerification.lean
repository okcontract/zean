/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryVerification
import Compiler.ZigAir.MemoryResources

/-! Separate contracts for fault freedom, termination and successful completion.
Neither a valid heap nor permission to exhaust resources establishes completion. -/
namespace Compiler.ZigAir.MemoryAir.Verify
open Memory Std.WP

def FaultFree (program : Program true) (args : List Value) (state : State) : Prop :=
  ∀ fuel fault after, program.runFuel fuel args state ≠ .finished (.error fault) after

def Terminates (program : Program true) (args : List Value) (state : State) : Prop :=
  ∃ fuel result after, program.runFuel fuel args state = .finished result after

def Completes (program : Program true) (args : List Value) (state : State)
    (post : Postcondition) : Prop :=
  ∃ fuel value after, program.runFuel fuel args state = .finished (.ok value) after ∧ post value after

theorem faultFree_of_contract (call : Invocation) (initial : State → Prop) (post : Postcondition)
    (contract : Triple call initial post (fun _ _ => False)) (state : State)
    (accepted : initial state) : FaultFree call.program call.args state := by
  intro fuel fault after reached
  have checked := sound call initial post _ contract state accepted fuel
  rw [reached] at checked
  exact checked

/-- Total correctness requires both a fault-free contract and termination.
A resource-only contract is deliberately insufficient for this rule. -/
theorem completes_of_contract (call : Invocation) (initial : State → Prop) (post : Postcondition)
    (contract : Triple call initial post (fun _ _ => False)) (state : State)
    (accepted : initial state) (terminates : Terminates call.program call.args state) :
    Completes call.program call.args state post := by
  obtain ⟨fuel, result, after, reached⟩ := terminates
  have checked := sound call initial post _ contract state accepted fuel
  rw [reached] at checked
  cases result with
  | error fault => exact False.elim checked
  | ok value => exact ⟨fuel, value, after, reached, checked⟩

/-- Finite admitted code terminates structurally; it still needs a fault-free
contract (including resource room) before successful completion follows. -/
theorem finite_terminates (program : Program) (args : List Value) (state : State) :
    Terminates program.enableLoops args state := by
  obtain ⟨fuel, reached⟩ := program.runFuel_finite args state
  exact ⟨fuel, (program.run args state).1, (program.run args state).2, reached⟩

theorem finite_completes (program : Program) (args : List Value) (initial : State → Prop)
    (post : Postcondition)
    (contract : Triple (Invocation.mk program.enableLoops args (fun _ _ _ => False))
      initial post (fun _ _ => False)) (state : State) (accepted : initial state) :
    Completes program.enableLoops args state post :=
  completes_of_contract _ initial post contract state accepted (finite_terminates program args state)

end Compiler.ZigAir.MemoryAir.Verify
