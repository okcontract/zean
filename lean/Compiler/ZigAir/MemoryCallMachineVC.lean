/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryCallMachineRules

/-! Structural verification conditions for the canonical call machine.
These are propositions, not an evaluator: calls use the actual invocation WP,
and loop back edges require the supplied invariant. Control-flow assertions
share the existing structured-control vocabulary and block/loop handlers. -/
namespace Compiler.ZigAir.MemoryCallMachine.VC
open Memory Std.WP Control.Verification

abbrev Invariants := Control.Verification.Invariants Value State
abbrev Post := Control.Verification.Post Value State
abbrev Frames := List (Control.Machine.Frame Ty Prim MemoryAir.Ref)

def effect (program : Program) (resources : ResourcePolicy) (args : List Value)
    (operation : Prim) (env : MemoryAir.Env) (post : Postcondition) (errors : Exceptions)
    (state : State) : Prop :=
  match operation with
  | .memory operation =>
    let (result, after) := operation.eval args env state
    match result with
    | .ok value => post value after
    | .error fault => errors fault after
  | .call target references =>
    match references.mapM (fun ref => ref.eval env) with
    | .error fault => errors fault state
    | .ok values => wp (invoke program target values resources) post errors state

theorem effect_mono (program : Program) (resources : ResourcePolicy) (args : List Value)
    (operation : Prim) (env : MemoryAir.Env) (post post' : Postcondition) (errors errors' : Exceptions)
    (hp : ∀ value state, post value state → post' value state)
    (he : ∀ fault state, errors fault state → errors' fault state)
    (state : State) (checked : effect program resources args operation env post errors state) :
    effect program resources args operation env post' errors' state := by
  cases operation with
  | memory operation =>
    simp only [effect] at checked ⊢
    generalize operation.eval args env state = result at checked ⊢
    obtain ⟨result, after⟩ := result
    cases result with
    | ok value => exact hp _ _ checked
    | error fault => exact he _ _ checked
  | call target references =>
    simp only [effect] at checked ⊢
    generalize references.mapM (fun ref => ref.eval env) = result at checked ⊢
    cases result with
    | error fault => exact he _ _ checked
    | ok values => exact fun fuel => Observes.mono _ _ _ _ hp he _ (checked fuel)

variable (program : Program) (resources : ResourcePolicy) (args : List Value) (invariants : Invariants)

/-- Only loop headers need client assertions. Calls retain actual execution,
including faults and suspension; no assumed return value is introduced. -/
def pre (code : Code) (post : Post) (errors : Exceptions)
    (env : MemoryAir.Env) (state : State) : Prop :=
  match code with
  | .bind id ty operation next =>
    effect program resources args operation env
      (fun value after => if value.hasType ty then pre next post errors (env.set id value) after
        else errors .malformed after) errors state
  | .branch ref yes no =>
    match ref.eval env with
    | .error fault => errors fault state
    | .ok value => match MemoryAir.semantics.truth value with
      | none => errors .malformed state
      | some flag => if flag then pre yes post errors env state else pre no post errors env state
  | .block id ty body next =>
    pre body (blockPost localSemantics id ty (pre next post errors) post errors) errors env state
  | .loop _ id body =>
    invariants id env state ∧ ∀ other heap, invariants id other heap →
      pre body (loopPost localSemantics id (invariants id) post errors) errors other heap
  | .repeat _ target => post (.repeated target env) state
  | .jump target ref =>
    match ref.eval env with
    | .error fault => errors fault state
    | .ok value => post (.jumped target value env) state
  | .ret ref =>
    match ref.eval env with
    | .error fault => errors fault state
    | .ok value => post (.returned value) state

theorem pre_mono (code : Code) (post post' : Post) (errors errors' : Exceptions)
    (hp : ∀ flow state, post flow state → post' flow state)
    (he : ∀ fault state, errors fault state → errors' fault state)
    (env : MemoryAir.Env) (state : State) (h : pre program resources args invariants code post errors env state) :
    pre program resources args invariants code post' errors' env state := by
  induction code generalizing post post' env state with
  | bind id ty operation next ih =>
    apply effect_mono program resources args operation env _ _ errors errors' _ he state h
    intro value after checked
    by_cases typed : value.hasType ty = true
    · simp only [typed, ↓reduceIte] at checked ⊢; exact ih post post' hp _ _ checked
    · simp only [typed, Bool.false_eq_true, ↓reduceIte] at checked ⊢; exact he _ _ checked
  | branch ref yes no ihYes ihNo =>
    cases evaluated : ref.eval env with
    | error fault => simp only [pre, evaluated] at h ⊢; exact he _ _ h
    | ok value =>
      cases truth : MemoryAir.semantics.truth value with
      | none => simp only [pre, evaluated, truth] at h ⊢; exact he _ _ h
      | some flag =>
        cases flag <;> simp only [pre, evaluated, truth, ↓reduceIte, Bool.false_eq_true] at h ⊢
        · exact ihNo post post' hp _ _ h
        · exact ihYes post post' hp _ _ h
  | block id ty body next ihBody ihNext =>
    exact ihBody _ _
      (blockPost_mono localSemantics id ty _ _ post post' errors errors'
        (fun env state h => ihNext post post' hp env state h) hp he) _ _ h
  | loop enabled id body ih =>
    exact ⟨h.1, fun other heap hi => ih _ _
      (loopPost_mono localSemantics id (invariants id) post post' errors errors' hp he) _ _ (h.2 other heap hi)⟩
  | «repeat» enabled target => exact hp _ _ h
  | jump target ref =>
    cases evaluated : ref.eval env <;> simp only [pre, evaluated] at h ⊢
    · exact he _ _ h
    · exact hp _ _ h
  | ret ref =>
    cases evaluated : ref.eval env <;> simp only [pre, evaluated] at h ⊢
    · exact he _ _ h
    · exact hp _ _ h

variable (post : Post) (errors : Exceptions)

/-- Local frame assertions preserve current environments and memory across
breaks, nested loops and helper calls. A loop certificate includes preservation. -/
inductive Stack : Frames → Post → Prop
  | nil : Stack [] (fun flow state => match flow with
      | .repeated .. => errors .malformed state
      | _ => post flow state)
  | block {frames localPost} (outer : Stack frames localPost) (id ty next) :
      Stack (.block id ty next :: frames)
        (blockPost localSemantics id ty (pre program resources args invariants next localPost errors) localPost errors)
  | loop {frames localPost} (outer : Stack frames localPost) (id body)
      (bodySafe : ∀ env state, invariants id env state →
        pre program resources args invariants body (loopPost localSemantics id (invariants id) localPost errors) errors env state) :
      Stack (.loop id body :: frames) (loopPost localSemantics id (invariants id) localPost errors)

def Certified : Control.Machine.Execution Ty Prim MemoryAir.Ref Value Fault State → Prop
  | .finished outcome => Terminal post errors outcome
  | .suspended config => ∃ localPost,
      Stack program resources args invariants post errors config.frames localPost ∧
      pre program resources args invariants config.code localPost errors config.env config.state

end Compiler.ZigAir.MemoryCallMachine.VC
