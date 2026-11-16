/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.ControlWP
import Compiler.ZigAir.MemoryExecutionProofs

/-! Invocation contracts for arbitrary supported memory AIR, with optional
loop invariants. Safety excludes faults via the exception postcondition and is
independent of termination. The interpreter's argument checks and cleanup remain
part of the contract. These are model guarantees, not source/backend refinement. -/
namespace Compiler.ZigAir.MemoryAir.Verify
open Memory Std.WP Lean.Order
open Control.Verification Control.Machine

abbrev Invariants := Control.Verification.Invariants Value State
abbrev Postcondition := Value → State → Prop
abbrev FaultCondition := Fault → State → Prop

structure Invocation where
  program : Program true
  args : List Value
  invariants : Invariants := fun _ _ _ => False

def finishPost (ty : Ty) (mark : Nat) (post : Postcondition) (errors : FaultCondition) :
    Control.Verification.Post Value State
  | .returned value, state => if value.hasType ty then post value (cleanup mark state)
      else errors .malformed (cleanup mark state)
  | _, state => errors .malformed (cleanup mark state)

theorem finishPost_mono (ty : Ty) (mark : Nat) (post post' : Postcondition) (errors errors' : FaultCondition)
    (hp : post ⊑ post') (he : errors ⊑ errors') (flow : Flow Value) (state : State)
    (h : finishPost ty mark post errors flow state) : finishPost ty mark post' errors' flow state := by
  cases flow with
  | returned value =>
    simp only [finishPost] at h ⊢
    by_cases typed : value.hasType ty = true
    · simp only [typed, ↓reduceIte] at h ⊢; exact hp _ _ h
    · simp only [typed, Bool.false_eq_true, ↓reduceIte] at h ⊢; exact he _ _ h
  | jumped | repeated => exact he _ _ h

instance invocationWP : WP Invocation Value (State → Prop) FaultCondition where
  wpTrans call := ⟨fun post errors state =>
    if call.program.accepts call.args state then
      pre semantics call.args call.invariants call.program.body
        (finishPost call.program.returnType state.nextId post errors)
        (fun fault after => errors fault (cleanup state.nextId after)) (fun _ => none) state
    else errors .malformed state⟩
  wp_trans_monotone call post post' errors errors' he hp state h := by
    dsimp only at h ⊢
    by_cases accepted : call.program.accepts call.args state = true
    · simp only [accepted, ↓reduceIte] at h ⊢
      exact pre_mono semantics call.args call.invariants call.program.body _ _ _ _
        (finishPost_mono _ _ _ _ _ _ hp he) (fun fault after h => he fault _ h) _ _ h
    · simp only [accepted, Bool.false_eq_true, ↓reduceIte] at h ⊢; exact he _ _ h

def returnClean (mark : Nat) (value : Value) : EStateM Fault State Value :=
  fun state => .ok value (cleanup mark state)

def failClean (mark : Nat) (fault : Fault) : EStateM Fault State Value :=
  fun state => .error fault (cleanup mark state)

@[spec] theorem returnClean_spec (mark : Nat) (value : Value) (post : Postcondition) (errors : FaultCondition) :
    Triple (returnClean mark value) (fun state => post value (cleanup mark state)) post errors := ⟨fun _ h => h⟩

@[spec] theorem failClean_spec (mark : Nat) (fault : Fault) (post : Postcondition) (errors : FaultCondition) :
    Triple (failClean mark fault) (fun state => errors fault (cleanup mark state)) post errors := ⟨fun _ h => h⟩

def finalize (ty : Ty) (mark : Nat) : Flow Value → EStateM Fault State Value
  | .returned value => if value.hasType ty then returnClean mark value else failClean mark .malformed
  | _ => failClean mark .malformed

attribute [spec] finalize

theorem wp_finalize (ty : Ty) (mark : Nat) (flow : Flow Value) (post : Postcondition) (errors : FaultCondition) :
    wp (finalize ty mark flow) post errors = finishPost ty mark post errors flow := by
  funext state
  cases flow with
  | returned value => simp only [finalize, finishPost]; split <;> rfl
  | jumped | repeated => rfl

@[spec] theorem invocation_spec (parameters : List Ty) (returnType : Ty) (body : Control.Code Ty Prim Ref true)
    (args : List Value) (invariants : Invariants)
    (post : Postcondition) (errors : FaultCondition) :
    Triple (Invocation.mk ⟨parameters, returnType, body⟩ args invariants)
      (fun state => (⌜(Program.mk parameters returnType body).accepts args state = true⌝ ⇨
        wp (Task.code body (fun _ => none) : Task semantics args invariants)
          (fun flow => wp (finalize returnType state.nextId flow) post errors)
          (fun fault after => errors fault (cleanup state.nextId after)) state) ⊓
        (⌜(Program.mk parameters returnType body).accepts args state ≠ true⌝ ⇨ errors .malformed state)) post errors := by
  constructor
  intro state h
  simp only [meet_prop_eq_and, himp_prop_eq_imp, ofProp_prop_eq, wp_code, wp_finalize] at h
  change (if (Program.mk parameters returnType body).accepts args state then
    pre semantics args invariants body (finishPost returnType state.nextId post errors)
      (fun fault after => errors fault (cleanup state.nextId after)) (fun _ => none) state
    else errors .malformed state)
  split
  · rename_i accepted; exact h.1 accepted
  · rename_i rejected; exact h.2 rejected

def Observes (post : Postcondition) (errors : FaultCondition) : MemoryAir.Invocation → Prop
  | .finished (.ok value) state => post value state
  | .finished (.error fault) state => errors fault state
  | .suspended .. => True

/-- No finite fuel bound is a premise. Suspension is permitted, but a reached
fault must satisfy the exception contract. Cleanup occurs only on termination. -/
theorem sound (call : Invocation) (initial : State → Prop) (post : Postcondition) (errors : FaultCondition)
    (contract : Triple call initial post errors) (state : State) (accepted : initial state) (fuel : Nat) :
    Observes post errors (call.program.runFuel fuel call.args state) := by
  have h := contract.le_wp state accepted
  change (if call.program.accepts call.args state then
    pre semantics call.args call.invariants call.program.body
      (finishPost call.program.returnType state.nextId post errors)
      (fun fault after => errors fault (cleanup state.nextId after)) (fun _ => none) state
    else errors .malformed state) at h
  unfold Program.runFuel Program.start MemoryAir.Invocation.resume
  by_cases inputs : call.program.accepts call.args state = true
  · simp only [inputs, ↓reduceIte] at h ⊢
    have root : rootPost semantics (finishPost call.program.returnType state.nextId post errors)
        (fun fault after => errors fault (cleanup state.nextId after)) =
        finishPost call.program.returnType state.nextId post errors := by
      funext flow after
      cases flow <;> rfl
    have stack : Stack semantics call.args call.invariants
        (finishPost call.program.returnType state.nextId post errors)
        (fun fault after => errors fault (cleanup state.nextId after)) []
        (rootPost semantics (finishPost call.program.returnType state.nextId post errors)
          (fun fault after => errors fault (cleanup state.nextId after))) := Stack.nil
    rw [root] at stack
    have certified := advance_certified semantics call.args call.invariants
      (finishPost call.program.returnType state.nextId post errors)
      (fun fault after => errors fault (cleanup state.nextId after)) fuel
      (.suspended ⟨call.program.body, fun _ => none, state, []⟩)
      ⟨_, stack, h⟩
    change Certified _ _ _ _ _ (run semantics call.args fuel _) at certified
    cases executed : run semantics call.args fuel ⟨call.program.body, fun _ => none, state, []⟩ with
    | suspended config => simp only [Observes]
    | finished outcome =>
      simp only
      rw [executed] at certified
      cases outcome with
      | returned value after =>
        change (if value.hasType call.program.returnType then post value (cleanup state.nextId after)
          else errors .malformed (cleanup state.nextId after)) at certified
        simp only [MemoryAir.Invocation.finish, Program.finish]
        by_cases typed : value.hasType call.program.returnType = true
        · simpa only [typed, ↓reduceIte, Observes] using certified
        · simpa only [typed, Bool.false_eq_true, ↓reduceIte, Observes] using certified
      | jumped => exact certified
      | fault => exact certified
  · simpa only [inputs, Bool.false_eq_true, ↓reduceIte, Observes] using h

/-- Memory safety permits only explicitly modeled resource exhaustion.
A client can strengthen this to `False` when it has sufficient resource bounds. -/
def ResourceOnly : FaultCondition := fun fault _ => fault = .outOfMemory

def Safe (program : Program true) (args : List Value) (state : State) : Prop :=
  ∀ fuel fault after, program.runFuel fuel args state = .finished (.error fault) after → fault = .outOfMemory

theorem safe_of_contract (call : Invocation) (initial : State → Prop) (post : Postcondition)
    (contract : Triple call initial post ResourceOnly) (state : State) (accepted : initial state) :
    Safe call.program call.args state := by
  intro fuel fault after reached
  have h := sound call initial post ResourceOnly contract state accepted fuel
  rw [reached] at h
  exact h

/-- The same contract also applies to the finite `Program.run` interface. -/
theorem finite_sound (program : Program) (args : List Value) (initial : State → Prop)
    (post : Postcondition) (errors : FaultCondition)
    (contract : Triple (Invocation.mk program.enableLoops args (fun _ _ _ => False)) initial post errors)
    (state : State) (accepted : initial state) :
    match program.run args state with
    | (.ok value, after) => post value after
    | (.error fault, after) => errors fault after := by
  obtain ⟨fuel, completed⟩ := program.runFuel_finite args state
  have h := sound _ initial post errors contract state accepted fuel
  change Observes post errors (program.enableLoops.runFuel fuel args state) at h
  rw [completed] at h
  generalize program.run args state = execution at h ⊢
  cases execution with
  | mk result after => cases result <;> exact h

end Compiler.ZigAir.MemoryAir.Verify
