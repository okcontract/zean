/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryPartialCallStability
import Compiler.ZigAir.MemoryCallVerification

namespace Compiler.ZigAir.MemoryPartialCall
open Memory MemoryAir.Verify Control.Verification Std.WP Lean.Order

def Target.invoke (target : Target) (budget : Nat) (args : List Value) : EStateM Signal State Value :=
  fun state => match target.observe budget args state with
    | (.ok value, after) => .ok value after
    | (.error signal, after) => .error signal after

/-- Suspension is an unfinished observation, never an allowed memory fault. -/
def errorsWithPending (errors : FaultCondition) : Signal → State → Prop
  | .pending, _ => True
  | .fault fault, state => errors fault state

structure Contract (target : Target) where
  precondition : List Value → State → Prop
  postcondition : List Value → State → Value → State → Prop
  exceptions : List Value → State → Signal → State → Prop
  checked : ∀ budget args before, precondition args before →
    Triple (target.invoke budget args) (fun state => state = before)
      (postcondition args before) (exceptions args before)

theorem Contract.apply (contract : Contract target) (budget : Nat) (args : List Value)
    (post : Postcondition) (errors : Signal → State → Prop) :
    Triple (target.invoke budget args)
      (fun state => ⌜contract.precondition args state⌝ ⊓
        ((⨅ value, ⨅ after, ⌜contract.postcondition args state value after⌝ ⇨ post value after) ⊓
         (⨅ signal, ⨅ after, ⌜contract.exceptions args state signal after⌝ ⇨ errors signal after))) post errors := by
  constructor
  intro state h
  simp only [meet_prop_eq_and, iInf_prop_eq_forall, himp_prop_eq_imp, ofProp_prop_eq] at h
  have checked := (contract.checked budget args state h.1).le_wp state rfl
  simp only [wp, WP.wpTrans, Target.invoke] at checked ⊢
  generalize target.observe budget args state = result at checked ⊢
  obtain ⟨result, after⟩ := result
  cases result with
  | ok value => exact h.2.1 value after checked
  | error signal => exact h.2.2 signal after checked

def BodyContract (program : Program) (budget : Nat) (args : List Value) (invariants : Invariants)
    (initial : State) (post : Postcondition) (errors : FaultCondition) : Prop :=
  Triple (Task.code program.body (fun _ => none) : Task (semantics budget) args invariants)
    (fun state => state = initial)
    (finishPost program.returnType initial.nextId post errors)
    (errorsWithPending (fun fault state => errors fault (cleanup initial.nextId state)))

def Observes (post : Postcondition) (errors : FaultCondition) : Observation → Prop
  | .finished (.ok value) state => post value state
  | .finished (.error fault) state => errors fault state
  | .pending _ => True

def Safe (program : Program) (args : List Value) (state : State) : Prop :=
  ∀ budget fault after, program.observe budget args state = .finished (.error fault) after →
    fault = .outOfMemory

theorem root_finish (budget : Nat) (type : Ty) (mark : Nat) (post : Postcondition) (errors : FaultCondition) :
    rootPost (semantics budget) (finishPost type mark post errors)
      (errorsWithPending (fun fault state => errors fault (cleanup mark state))) =
      finishPost type mark post errors := by
  funext flow state
  cases flow <;> rfl

theorem finish_observes (budget : Nat) (type : Ty) (mark : Nat)
    (post : Postcondition) (errors : FaultCondition) (outcome : Control.Outcome Value Signal State)
    (checked : Terminal (rootPost (semantics budget) (finishPost type mark post errors)
      (errorsWithPending (fun fault state => errors fault (cleanup mark state))))
      (errorsWithPending (fun fault state => errors fault (cleanup mark state))) outcome) :
    Observes post errors (finish type mark outcome) := by
  cases outcome with
  | returned value state =>
    simp only [finish, MemoryAir.Program.finish, Terminal, root_finish, finishPost] at checked ⊢
    split at checked <;> simp_all only [Bool.false_eq_true, ↓reduceIte, Observes]
  | fault signal state => cases signal <;> exact checked
  | jumped => exact checked

/-- A contract for every budget covers faults reached inside a callee as well
as work after the callee returns. No exhausted observation permits continuation. -/
theorem sound (program : Program) (budget : Nat) (args : List Value) (invariants : Invariants)
    (initial : State) (post : Postcondition) (errors : FaultCondition)
    (accepted : program.accepts args initial = true)
    (contract : BodyContract program budget args invariants initial post errors) :
    Observes post errors (program.observe budget args initial) := by
  have rooted : Triple (Task.code program.body (fun _ => none) : Task (semantics budget) args invariants)
      (fun state => state = initial)
      (rootPost (semantics budget) (finishPost program.returnType initial.nextId post errors)
        (errorsWithPending (fun fault state => errors fault (cleanup initial.nextId state))))
      (errorsWithPending (fun fault state => errors fault (cleanup initial.nextId state))) := by
    rw [root_finish]; exact contract
  have checked := code_sound (semantics budget) args invariants program.body (fun _ => none)
    _ _ _ rooted initial rfl budget
  simp only [Program.observe, accepted, ↓reduceIte]
  cases reached : Control.Machine.run (semantics budget) args budget
      ⟨program.body, fun _ => none, initial, []⟩ with
  | suspended => trivial
  | finished outcome =>
    rw [reached] at checked
    exact finish_observes budget _ _ _ _ _ checked

theorem safe_of_contract (program : Program) (args : List Value) (invariants : Invariants)
    (initial : State) (post : Postcondition) (errors : FaultCondition)
    (accepted : program.accepts args initial = true)
    (contracts : ∀ budget, BodyContract program budget args invariants initial post errors)
    (onlyExhaustion : ∀ fault after, errors fault after → fault = .outOfMemory) : Safe program args initial := by
  intro budget fault after reached
  have checked := sound program budget args invariants initial post errors accepted (contracts budget)
  rw [reached] at checked
  exact onlyExhaustion fault after checked

/-- Reuse the actual looping callee's checked body contract. Pending observations
have no return value and therefore provide no continuation postcondition. -/
theorem Target.loop_contract (program : MemoryCall.Program true) (budget : Nat) (args : List Value)
    (precondition : State → Prop) (post : Postcondition) (errors : FaultCondition)
    (observed : ∀ state, precondition state → MemoryCall.Observes post errors (program.runFuel budget args state)) :
    Triple ((Target.loop program).invoke budget args) precondition post (errorsWithPending errors) := by
  constructor
  intro state initial
  have checked := observed state initial
  simp only [wp, WP.wpTrans, Target.invoke, Target.loop]
  generalize program.runFuel budget args state = result at checked ⊢
  cases result with
  | suspended => trivial
  | finished result state => cases result <;> exact checked

theorem Target.finite_contract (target : MemoryCall.Target) (budget : Nat) (args : List Value)
    (precondition : State → Prop) (post : Postcondition) (errors : FaultCondition)
    (contract : Triple (target.invoke args) precondition post errors) :
    Triple ((Target.finite target).invoke budget args) precondition post (errorsWithPending errors) := by
  constructor
  intro state initial
  have checked := MemoryCall.Target.sound target args precondition post errors contract state initial
  simp only [wp, WP.wpTrans, Target.invoke, Target.finite, liftResult]
  generalize target.execute args state = result at checked ⊢
  obtain ⟨result, after⟩ := result
  cases result <;> exact checked

/-- A verified caller is itself reusable at the next acyclic call boundary. -/
theorem target_contract (program : Program) (budget : Nat) (args : List Value)
    (precondition : State → Prop) (post : Postcondition) (errors : FaultCondition)
    (invariants : Invariants)
    (accepted : ∀ state, precondition state → program.accepts args state = true)
    (contract : ∀ state, precondition state → BodyContract program budget args invariants state post errors) :
    Triple (program.target.invoke budget args) precondition post (errorsWithPending errors) := by
  constructor
  intro state initial
  have checked := sound program budget args invariants state post errors
    (accepted state initial) (contract state initial)
  simp only [wp, WP.wpTrans, Target.invoke, Program.target]
  generalize program.observe budget args state = result at checked ⊢
  cases result with
  | pending => trivial
  | finished result after => cases result <;> exact checked

@[spec high] theorem memory_spec (budget : Nat) (operation : MemoryAir.Prim)
    (args : List Value) (env : MemoryAir.Env) (post : Postcondition) (errors : Signal → State → Prop) :
    Triple (Atomic.mk (sem := semantics budget) (args := args) (.memory operation) env)
      (wp (Atomic.mk (sem := MemoryAir.semantics) (args := args) operation env)
        post (fun fault => errors (.fault fault))) post errors := by
  constructor
  intro state checked
  rw [wp_atomic] at checked ⊢
  simp only [MemoryAir.semantics] at checked
  simp only [semantics, Prim.eval, liftResult]
  generalize operation.eval args env state = result at checked ⊢
  obtain ⟨result, after⟩ := result
  cases result <;> exact checked

@[spec] theorem call_spec (budget : Nat) (target : Target) (arguments : List MemoryAir.Ref)
    (args : List Value) (env : MemoryAir.Env) (post : Postcondition) (errors : Signal → State → Prop) :
    Triple (Atomic.mk (sem := semantics budget) (args := args) (.call target arguments) env)
      (wp (MemoryCall.readArguments arguments env)
        (fun values => wp (target.invoke budget values) post errors)
        (fun fault => errors (.fault fault))) post errors := by
  constructor
  intro state checked
  rw [wp_atomic]
  simp only [wp, WP.wpTrans, semantics, Prim.eval, MemoryCall.readArguments] at checked ⊢
  cases read : arguments.mapM (fun ref => ref.eval env) with
  | error fault => simpa only [read] using checked
  | ok values =>
    simp only [read] at checked ⊢
    unfold Target.invoke at checked
    generalize target.observe budget values state = result at checked ⊢
    obtain ⟨result, after⟩ := result
    cases result <;> exact checked

end Compiler.ZigAir.MemoryPartialCall
