/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryCall
import Compiler.ZigAir.MemoryCallArguments

/-! Call rules reuse a callee contract without unfolding the callee at a call
site. Fault postconditions retain the callee's reached state. In particular,
cleanup is not rollback, and returned pointer usability is a postcondition. -/
namespace Compiler.ZigAir.MemoryCall
open Memory MemoryAir.Verify Control.Verification Std.WP Lean.Order

def Target.invoke (target : Target) (args : List Value) : EStateM Fault State Value :=
  fun state => match target.execute args state with
    | (.ok value, after) => .ok value after
    | (.error fault, after) => .error fault after

/-- A relational callee specification can retain its caller's initial state.
This is a proved contract, not an executable replacement for the callee. -/
structure Contract (target : Target) where
  precondition : List Value → State → Prop
  postcondition : List Value → State → Value → State → Prop
  exceptions : List Value → State → Fault → State → Prop
  checked : ∀ args before, precondition args before →
    Triple (target.invoke args) (fun state => state = before) (postcondition args before) (exceptions args before)

theorem Contract.apply (contract : Contract target) (args : List Value)
    (post : Postcondition) (errors : FaultCondition) :
    Triple (target.invoke args)
      (fun state => ⌜contract.precondition args state⌝ ⊓
        ((⨅ value, ⨅ after, ⌜contract.postcondition args state value after⌝ ⇨ post value after) ⊓
         (⨅ fault, ⨅ after, ⌜contract.exceptions args state fault after⌝ ⇨ errors fault after))) post errors := by
  constructor
  intro state h
  simp only [meet_prop_eq_and, iInf_prop_eq_forall, himp_prop_eq_imp, ofProp_prop_eq] at h
  have checked := (contract.checked args state h.1).le_wp state rfl
  simp only [wp, WP.wpTrans, Target.invoke] at checked ⊢
  generalize target.execute args state = result at checked ⊢
  obtain ⟨result, after⟩ := result
  cases result with
  | ok value => exact h.2.1 value after checked
  | error fault => exact h.2.2 fault after checked

theorem Target.memory_contract (program : MemoryAir.Program) (args : List Value)
    (initial : State → Prop) (post : Postcondition) (errors : FaultCondition)
    (contract : Triple (Invocation.mk program.enableLoops args (fun _ _ _ => False)) initial post errors) :
    Triple ((Target.ofMemory program).invoke args) initial post errors := by
  constructor
  intro state accepted
  have checked := finite_sound program args initial post errors contract state accepted
  simp only [wp, WP.wpTrans]
  unfold Target.invoke Target.ofMemory
  dsimp only
  generalize program.run args state = result at checked ⊢
  obtain ⟨result, after⟩ := result
  cases result <;> exact checked

@[spec high] theorem primitive_spec (operation : MemoryAir.Prim) (args : List Value) (env : MemoryAir.Env)
    (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) (.memory operation) env)
      (wp (Atomic.mk (sem := MemoryAir.semantics) (args := args) operation env) post errors) post errors :=
  ⟨fun _ h => h⟩


@[spec] theorem call_spec (target : Target) (arguments : List MemoryAir.Ref)
    (args : List Value) (env : MemoryAir.Env) (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) (.call target arguments) env)
      (wp (readArguments arguments env) (fun values => wp (target.invoke values) post errors) errors) post errors := by
  constructor
  intro state h
  rw [wp_atomic]
  simp only [wp, WP.wpTrans] at h
  simp only [semantics, Prim.eval, readArguments] at h ⊢
  cases evaluated : arguments.mapM (fun ref => ref.eval env) with
  | error fault => simpa only [evaluated] using h
  | ok values =>
    simp only [evaluated] at h ⊢
    unfold Target.invoke at h
    generalize target.execute values state = execution at h ⊢
    obtain ⟨result, after⟩ := execution
    cases result <;> exact h

end Compiler.ZigAir.MemoryCall
