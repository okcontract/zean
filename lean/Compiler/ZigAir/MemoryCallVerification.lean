/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryCallWP

namespace Compiler.ZigAir.MemoryCall
open Memory MemoryAir.Verify Control.Verification Std.WP Lean.Order

/-- A finite callee contract describes its actual result and reached state,
including failures; this bridge does not substitute the specification for code. -/
theorem Target.sound (target : Target) (args : List Value) (precondition : State → Prop)
    (post : Postcondition) (errors : FaultCondition)
    (contract : Triple (target.invoke args) precondition post errors)
    (initial : State) (accepted : precondition initial) :
    match target.execute args initial with
    | (.ok value, after) => post value after
    | (.error fault, after) => errors fault after := by
  have checked := contract.le_wp initial accepted
  simp only [wp, WP.wpTrans, Target.invoke] at checked
  generalize target.execute args initial = outcome at checked ⊢
  obtain ⟨outcome, after⟩ := outcome
  cases outcome <;> exact checked

/-- A body contract retains this invocation's cleanup mark, including when a
callee fails after modifying caller memory. -/
def BodyContract (program : Program true) (args : List Value) (invariants : Invariants)
    (initial : State) (post : Postcondition) (errors : FaultCondition) : Prop :=
  Triple (Task.code program.body (fun _ => none) : Task semantics args invariants)
    (fun state => state = initial)
    (finishPost program.returnType initial.nextId post errors)
    (fun fault state => errors fault (cleanup initial.nextId state))

theorem root_finish (type : Ty) (mark : Nat) (post : Postcondition) (errors : FaultCondition) :
    rootPost semantics (finishPost type mark post errors)
      (fun fault state => errors fault (cleanup mark state)) = finishPost type mark post errors := by
  funext flow state
  cases flow <;> rfl

def Observes (post : Postcondition) (errors : FaultCondition) : Execution → Prop
  | .finished (.ok value) state => post value state
  | .finished (.error fault) state => errors fault state
  | .suspended .. => True

/-- Every finite execution prefix excludes memory and scalar faults. As with
the call-free interface, modeled allocation exhaustion remains permitted. -/
def Safe (program : Program true) (args : List Value) (state : State) : Prop :=
  ∀ fuel fault after, program.runFuel fuel args state = .finished (.error fault) after →
    fault = .outOfMemory

theorem finish_observes (type : Ty) (mark : Nat) (post : Postcondition) (errors : FaultCondition)
    (outcome : Control.Outcome Value Fault State)
    (checked : Terminal (rootPost semantics (finishPost type mark post errors)
      (fun fault state => errors fault (cleanup mark state)))
      (fun fault state => errors fault (cleanup mark state)) outcome) :
    let (result, after) := MemoryAir.Program.finish type mark outcome
    Observes post errors (.finished result after) := by
  cases outcome with
  | returned value after =>
    simp only [MemoryAir.Program.finish, Terminal, root_finish, finishPost] at checked ⊢
    split at checked <;> simp_all only [Bool.false_eq_true, ↓reduceIte, Observes]
  | fault | jumped => exact checked

/-- Safety covers every caller prefix. Each call evaluates its finite callee
completely; its argument checks, internal faults and cleanup are part of that
actual evaluation, rather than an assumed transition. -/
theorem sound (program : Program true) (args : List Value) (invariants : Invariants)
    (initial : State) (post : Postcondition) (errors : FaultCondition)
    (accepted : program.accepts args initial = true)
    (contract : BodyContract program args invariants initial post errors) (fuel : Nat) :
    Observes post errors (program.runFuel fuel args initial) := by
  have rooted : Triple (Task.code program.body (fun _ => none) : Task semantics args invariants)
      (fun state => state = initial)
      (rootPost semantics (finishPost program.returnType initial.nextId post errors)
        (fun fault state => errors fault (cleanup initial.nextId state)))
      (fun fault state => errors fault (cleanup initial.nextId state)) := by
    rw [root_finish]; exact contract
  have checked := code_sound semantics args invariants program.body (fun _ => none) _ _ _ rooted initial rfl fuel
  simp only [Program.runFuel, accepted, ↓reduceIte, Execution.resume]
  cases reached : Control.Machine.run semantics args fuel ⟨program.body, fun _ => none, initial, []⟩ with
  | suspended config => trivial
  | finished outcome =>
    rw [reached] at checked
    exact finish_observes _ _ _ _ outcome checked

theorem safe_of_contract (program : Program true) (args : List Value) (invariants : Invariants)
    (initial : State) (post : Postcondition) (errors : FaultCondition)
    (accepted : program.accepts args initial = true)
    (contract : BodyContract program args invariants initial post errors)
    (onlyExhaustion : ∀ fault after, errors fault after → fault = .outOfMemory) :
    Safe program args initial := by
  intro fuel fault after reached
  have observed := sound program args invariants initial post errors accepted contract fuel
  rw [reached] at observed
  exact onlyExhaustion fault after observed

/-- Turn a separately verified finite call-enabled body into a reusable callee
contract. Callers can instantiate this theorem without unfolding its body. -/
theorem target_contract (program : Program) (args : List Value) (precondition : State → Prop)
    (post : Postcondition) (errors : FaultCondition)
    (accepted : ∀ state, precondition state → program.accepts args state = true)
    (body : ∀ state, precondition state → BodyContract program.enableLoops args
      (fun _ _ _ => False) state post errors) :
    Triple (program.target.invoke args) precondition post errors := by
  constructor
  intro state initial
  have contract := body state initial
  have rooted : Triple (Task.code program.body.enableLoops (fun _ => none) :
      Task semantics args (fun _ _ _ => False)) (fun before => before = state)
      (rootPost semantics (finishPost program.returnType state.nextId post errors)
        (fun fault after => errors fault (cleanup state.nextId after)))
      (fun fault after => errors fault (cleanup state.nextId after)) := by
    rw [root_finish]; exact contract
  have checked := finite_code_sound semantics args (fun _ _ _ => False) program.body (fun _ => none)
    _ _ _ rooted state rfl
  have finished := finish_observes program.returnType state.nextId post errors _ checked
  simp only [wp, WP.wpTrans, Target.invoke, Program.target, Program.run, accepted state initial, ↓reduceIte]
  generalize MemoryAir.Program.finish program.returnType state.nextId
    (program.body.eval semantics args (fun _ => none) state) = result at finished ⊢
  obtain ⟨result, after⟩ := result
  cases result <;> exact finished

end Compiler.ZigAir.MemoryCall
