/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MachineProofs

/-! Structured verification conditions for arbitrary admitted control trees.
The user supplies assertions at loop headers. All other program points are
handled structurally. Safety concerns every finite execution prefix; this
module deliberately makes no termination claim. -/
namespace Compiler.ZigAir.Control.Verification
open Machine

inductive Flow (Value : Type) where
  | returned (value : Value)
  | jumped (target : Nat) (value : Value) (env : Env Value)
  | repeated (target : Nat) (env : Env Value)

abbrev Assertion (Value State : Type) := Env Value → State → Prop
abbrev Invariants (Value State : Type) := Nat → Assertion Value State
abbrev Post (Value State : Type) := Flow Value → State → Prop
abbrev Errors (Fault State : Type) := Fault → State → Prop

variable (sem : Semantics Ty Prim Ref Value Fault State) (args : List Value)
    (invariants : Invariants Value State)

def blockPost (id : Nat) (ty : Ty) (next : Assertion Value State)
    (post : Post Value State) (errors : Errors Fault State) : Post Value State
  | .jumped target value env, state =>
    if target = id then
      if sem.hasType value ty then next (env.set id value) state
      else errors sem.malformed state
    else post (.jumped target value env) state
  | .repeated target env, state =>
    if target = id then errors sem.malformed state else post (.repeated target env) state
  | flow, state => post flow state

def loopPost (id : Nat) (invariant : Assertion Value State)
    (post : Post Value State) (errors : Errors Fault State) : Post Value State
  | .repeated target env, state => if target = id then invariant env state else post (.repeated target env) state
  | .jumped target value env, state =>
    if target = id then errors sem.malformed state else post (.jumped target value env) state
  | flow, state => post flow state

/-- A structural precondition, with a supplied invariant at each loop header.
Faults are obligations too, including faults from unused instructions. -/
def pre (code : Code Ty Prim Ref true) (post : Post Value State) (errors : Errors Fault State)
    (env : Env Value) (state : State) : Prop :=
  match code with
  | .bind id ty prim next =>
    let (result, after) := sem.evalPrim prim args env state
    match result with
    | .error fault => errors fault after
    | .ok value => if sem.hasType value ty then pre next post errors (env.set id value) after
      else errors sem.malformed after
  | .branch ref yes no =>
    match sem.evalRef ref env with
    | .error fault => errors fault state
    | .ok value => match sem.truth value with
      | none => errors sem.malformed state
      | some flag => if flag then pre yes post errors env state else pre no post errors env state
  | .block id ty body next =>
    pre body (blockPost sem id ty (pre next post errors) post errors) errors env state
  | .loop _ id body =>
    invariants id env state ∧ ∀ other heap, invariants id other heap →
      pre body (loopPost sem id (invariants id) post errors) errors other heap
  | .repeat _ target => post (.repeated target env) state
  | .jump target ref =>
    match sem.evalRef ref env with
    | .error fault => errors fault state
    | .ok value => post (.jumped target value env) state
  | .ret ref =>
    match sem.evalRef ref env with
    | .error fault => errors fault state
    | .ok value => post (.returned value) state

theorem blockPost_mono (id : Nat) (ty : Ty) (next next' : Assertion Value State)
    (post post' : Post Value State) (errors errors' : Errors Fault State)
    (hn : ∀ env state, next env state → next' env state)
    (hp : ∀ flow state, post flow state → post' flow state)
    (he : ∀ fault state, errors fault state → errors' fault state)
    (flow : Flow Value) (state : State) (h : blockPost sem id ty next post errors flow state) :
    blockPost sem id ty next' post' errors' flow state := by
  cases flow with
  | returned value => exact hp _ _ h
  | jumped target value env =>
    simp only [blockPost] at h ⊢
    split at h
    · rename_i catches
      simp only [catches, ↓reduceIte]
      split at h
      · rename_i typed
        simpa only [typed, ↓reduceIte] using hn _ _ h
      · rename_i typed
        simpa only [typed, Bool.false_eq_true, ↓reduceIte] using he _ _ h
    · rename_i misses
      simpa only [misses, ↓reduceIte] using hp _ _ h
  | repeated target env =>
    simp only [blockPost] at h ⊢
    by_cases catches : target = id
    · simp only [catches, ↓reduceIte] at h ⊢; exact he _ _ h
    · simp only [catches, ↓reduceIte] at h ⊢; exact hp _ _ h

theorem loopPost_mono (id : Nat) (invariant : Assertion Value State)
    (post post' : Post Value State) (errors errors' : Errors Fault State)
    (hp : ∀ flow state, post flow state → post' flow state)
    (he : ∀ fault state, errors fault state → errors' fault state)
    (flow : Flow Value) (state : State) (h : loopPost sem id invariant post errors flow state) :
    loopPost sem id invariant post' errors' flow state := by
  cases flow with
  | returned value => exact hp _ _ h
  | jumped target value env =>
    simp only [loopPost] at h ⊢
    by_cases catches : target = id
    · simp only [catches, ↓reduceIte] at h ⊢; exact he _ _ h
    · simp only [catches, ↓reduceIte] at h ⊢; exact hp _ _ h
  | repeated target env =>
    simp only [loopPost] at h ⊢
    by_cases catches : target = id
    · simp only [catches, ↓reduceIte] at h ⊢; exact h
    · simp only [catches, ↓reduceIte] at h ⊢; exact hp _ _ h

theorem pre_mono (code : Code Ty Prim Ref true)
    (post post' : Post Value State) (errors errors' : Errors Fault State)
    (hp : ∀ flow state, post flow state → post' flow state)
    (he : ∀ fault state, errors fault state → errors' fault state)
    (env : Env Value) (state : State) (h : pre sem args invariants code post errors env state) :
    pre sem args invariants code post' errors' env state := by
  induction code generalizing post post' env state with
  | bind id ty prim next ih =>
    cases evaluated : sem.evalPrim prim args env state with
    | mk result after =>
      simp only [pre, evaluated] at h ⊢
      cases result with
      | error fault => exact he _ _ h
      | ok value =>
        by_cases typed : sem.hasType value ty = true
        · simp only [typed, ↓reduceIte] at h ⊢; exact ih post post' hp _ _ h
        · simp only [typed, Bool.false_eq_true, ↓reduceIte] at h ⊢; exact he _ _ h
  | branch ref yes no ihYes ihNo =>
    cases evaluated : sem.evalRef ref env with
    | error fault => simp only [pre, evaluated] at h ⊢; exact he _ _ h
    | ok value =>
      cases truth : sem.truth value with
      | none => simp only [pre, evaluated, truth] at h ⊢; exact he _ _ h
      | some flag =>
        cases flag <;> simp only [pre, evaluated, truth, ↓reduceIte, Bool.false_eq_true] at h ⊢
        · exact ihNo post post' hp _ _ h
        · exact ihYes post post' hp _ _ h
  | block id ty body next ihBody ihNext =>
    exact ihBody _ _
      (blockPost_mono sem id ty _ _ post post' errors errors'
        (fun env state h => ihNext post post' hp env state h) hp he) _ _ h
  | loop enabled id body ih =>
    exact ⟨h.1, fun other heap hi => ih _ _
      (loopPost_mono sem id (invariants id) post post' errors errors' hp he) _ _ (h.2 other heap hi)⟩
  | «repeat» enabled target => exact hp _ _ h
  | jump target ref =>
    cases evaluated : sem.evalRef ref env <;> simp only [pre, evaluated] at h ⊢
    · exact he _ _ h
    · exact hp _ _ h
  | ret ref =>
    cases evaluated : sem.evalRef ref env <;> simp only [pre, evaluated] at h ⊢
    · exact he _ _ h
    · exact hp _ _ h

variable (post : Post Value State) (errors : Errors Fault State)

/-- Stack frames connect local obligations to the invocation's postconditions. -/
inductive Stack : List (Frame Ty Prim Ref) → Post Value State → Prop
  | nil : Stack [] (fun flow state => match flow with
      | .repeated .. => errors sem.malformed state
      | _ => post flow state)
  | block {frames localPost} (outer : Stack frames localPost) (id ty next) :
      Stack (.block id ty next :: frames)
        (blockPost sem id ty (pre sem args invariants next localPost errors) localPost errors)
  | loop {frames localPost} (outer : Stack frames localPost) (id body)
      (bodySafe : ∀ env state, invariants id env state →
        pre sem args invariants body (loopPost sem id (invariants id) localPost errors) errors env state) :
      Stack (.loop id body :: frames) (loopPost sem id (invariants id) localPost errors)

def Terminal : Outcome Value Fault State → Prop
  | .returned value state => post (.returned value) state
  | .jumped target value env state => post (.jumped target value env) state
  | .fault fault state => errors fault state

def Certified : Execution Ty Prim Ref Value Fault State → Prop
  | .finished outcome => Terminal post errors outcome
  | .suspended config => ∃ localPost,
      Stack sem args invariants post errors config.frames localPost ∧
      pre sem args invariants config.code localPost errors config.env config.state

theorem Stack.returned {frames localPost} (stack : Stack sem args invariants post errors frames localPost)
    (value : Value) (state : State) (h : localPost (.returned value) state) :
    post (.returned value) state := by
  induction stack with
  | nil => exact h
  | block _ _ _ _ ih => exact ih h
  | loop _ _ _ _ ih => exact ih h

theorem Stack.jump {frames localPost} (stack : Stack sem args invariants post errors frames localPost)
    (target : Nat) (value : Value) (env : Env Value) (state : State)
    (h : localPost (.jumped target value env) state) :
    Certified sem args invariants post errors (Machine.jump sem target value env state frames) := by
  induction stack with
  | nil => exact h
  | block outer id ty next ih =>
    simp only [blockPost] at h
    simp only [Machine.jump]
    by_cases catches : target = id
    · simp only [catches, ↓reduceIte] at h ⊢
      by_cases typed : sem.hasType value ty = true
      · simp only [typed, ↓reduceIte] at h ⊢
        exact ⟨_, outer, h⟩
      · simpa only [typed, Bool.false_eq_true, ↓reduceIte, Certified, Terminal] using h
    · simp only [catches, ↓reduceIte] at h ⊢
      exact ih h
  | loop outer id body bodySafe ih =>
    simp only [loopPost] at h
    simp only [Machine.jump]
    by_cases catches : target = id
    · simpa only [catches, ↓reduceIte, Certified, Terminal] using h
    · simp only [catches, ↓reduceIte] at h ⊢
      exact ih h

theorem Stack.backedge {frames localPost} (stack : Stack sem args invariants post errors frames localPost)
    (target : Nat) (env : Env Value) (state : State) (h : localPost (.repeated target env) state) :
    Certified sem args invariants post errors (Machine.backedge sem target env state frames) := by
  induction stack with
  | nil => exact h
  | block outer id ty next ih =>
    simp only [blockPost] at h
    simp only [Machine.backedge]
    by_cases catches : target = id
    · simpa only [catches, ↓reduceIte, Certified, Terminal] using h
    · simp only [catches, ↓reduceIte] at h ⊢
      exact ih h
  | loop outer id body bodySafe ih =>
    simp only [loopPost] at h
    simp only [Machine.backedge]
    by_cases catches : target = id
    · simp only [catches, ↓reduceIte] at h ⊢
      exact ⟨_, Stack.loop outer id body bodySafe, bodySafe env state h⟩
    · simp only [catches, ↓reduceIte] at h ⊢
      exact ih h

/-- One concrete machine step preserves the certificate, or satisfies the
terminal postcondition. This connects the structural rules to execution. -/
theorem step_certified (config : Config Ty Prim Ref Value State)
    (h : Certified sem args invariants post errors (.suspended config)) :
    Certified sem args invariants post errors (Machine.step sem args config) := by
  obtain ⟨localPost, stack, h⟩ := h
  rcases config with ⟨code, env, state, frames⟩
  cases code with
  | bind id ty prim next =>
    cases evaluated : sem.evalPrim prim args env state with
    | mk result after =>
      simp only [pre, Machine.step, evaluated] at h ⊢
      cases result with
      | error fault => exact h
      | ok value =>
        by_cases typed : sem.hasType value ty = true
        · simp only [typed, ↓reduceIte] at h ⊢
          exact ⟨localPost, stack, h⟩
        · simpa only [typed, Bool.false_eq_true, ↓reduceIte, Certified, Terminal] using h
  | branch ref yes no =>
    cases evaluated : sem.evalRef ref env with
    | error fault => simpa only [pre, evaluated, Machine.step, Certified, Terminal] using h
    | ok value =>
      cases truth : sem.truth value with
      | none => simpa only [pre, evaluated, truth, Machine.step, Certified, Terminal] using h
      | some flag =>
        cases flag <;> simp only [pre, evaluated, truth, Machine.step, ↓reduceIte, Bool.false_eq_true] at h ⊢
        all_goals exact ⟨localPost, stack, h⟩
  | block id ty body next => exact ⟨_, Stack.block stack id ty next, h⟩
  | loop enabled id body =>
    exact ⟨_, Stack.loop stack id body h.2, h.2 env state h.1⟩
  | «repeat» enabled target => exact stack.backedge sem args invariants post errors target env state h
  | jump target ref =>
    simp only [pre] at h
    simp only [Machine.step]
    generalize sem.evalRef ref env = evaluated at h ⊢
    cases evaluated with
    | error fault => exact h
    | ok value => exact stack.jump sem args invariants post errors target value env state h
  | ret ref =>
    simp only [pre] at h
    simp only [Machine.step]
    generalize sem.evalRef ref env = evaluated at h ⊢
    cases evaluated with
    | error fault => exact h
    | ok value => exact stack.returned sem args invariants post errors value state h

/-- Safety for every finite execution prefix, including suspended loops.
A valid heap alone would not establish this: faults must satisfy `errors`. -/
theorem advance_certified (fuel : Nat) (execution : Execution Ty Prim Ref Value Fault State)
    (h : Certified sem args invariants post errors execution) :
    Certified sem args invariants post errors (advance sem args fuel execution) := by
  induction fuel generalizing execution with
  | zero => exact h
  | succ fuel ih => cases execution with
    | finished => exact h
    | suspended config => exact ih _ (step_certified sem args invariants post errors config h)

theorem steps_certified {first last : Execution Ty Prim Ref Value Fault State}
    (steps : Steps sem args first last) (h : Certified sem args invariants post errors first) :
    Certified sem args invariants post errors last := by
  induction steps with
  | refl => exact h
  | step config _ ih => exact ih (step_certified sem args invariants post errors config h)

/-- Termination is a separate obligation. A natural-number ranking must decrease
at every suspended transition; terminal outcomes need no successor measure. -/
theorem terminates_of_rank (invariant : Config Ty Prim Ref Value State → Prop)
    (rank : Config Ty Prim Ref Value State → Nat)
    (decreases : ∀ config, invariant config →
      match Machine.step sem args config with
      | .finished _ => True
      | .suspended next => invariant next ∧ rank next < rank config)
    (config : Config Ty Prim Ref Value State) (initial : invariant config) :
    ∃ outcome, Steps sem args (.suspended config) (.finished outcome) := by
  have next := decreases config initial
  cases reached : Machine.step sem args config with
  | finished outcome =>
    exact ⟨outcome, Steps.step config (by rw [reached]; exact .refl _)⟩
  | suspended after =>
    simp only [reached] at next
    obtain ⟨outcome, tail⟩ := terminates_of_rank invariant rank decreases after next.1
    exact ⟨outcome, Steps.step config (by rw [reached]; exact tail)⟩
termination_by rank config
decreasing_by
  have h := decreases config initial
  rw [reached] at h
  exact h.2

end Compiler.ZigAir.Control.Verification
