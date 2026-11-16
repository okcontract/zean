/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryCallMachineVC

namespace Compiler.ZigAir.MemoryCallMachine
open Memory Std.WP

/-- A finite caller observation needs only bounded continuation observations.
The callee contract still covers every prefix, including nontermination. This
is the induction bridge for loops containing calls; it assumes no safe back edge. -/
theorem Ensures.attach_observes (program : Program) (resources : ResourcePolicy)
    (callers : List Caller) (post middle : Postcondition) (errors failures : Exceptions)
    (fuel : Nat) (first : Execution) (consistent : Uses resources first)
    (checked : Ensures program first middle failures)
    (success : ∀ value state, middle value state → ∀ budget, budget ≤ fuel →
      Observes post errors (advance program budget (MemoryCallMachine.attach resources callers (.finished (.ok value) state))))
    (failure : ∀ fault state, failures fault state → ∀ budget, budget ≤ fuel →
      Observes post errors (advance program budget (MemoryCallMachine.attach resources callers (.finished (.error fault) state)))) :
    Observes post errors (advance program fuel (MemoryCallMachine.attach resources callers first)) := by
  induction fuel generalizing first with
  | zero =>
    cases first with
    | suspended => trivial
    | finished result state => cases result with
      | ok value => exact success value state (checked 0) 0 (Nat.le_refl _)
      | error fault => exact failure fault state (checked 0) 0 (Nat.le_refl _)
  | succ fuel ih =>
    cases first with
    | finished result state => cases result with
      | ok value => exact success value state (checked 0) _ (Nat.le_refl _)
      | error fault => exact failure fault state (checked 0) _ (Nat.le_refl _)
    | suspended config =>
      change Observes post errors (advance program fuel
        (step program { config with callers := config.callers ++ callers }))
      rw [step_attach, consistent]
      apply ih (step program config)
      · simpa only [Uses] using consistent ▸ uses_step program config
      · exact fun budget => checked (budget + 1)
      · exact fun value state h budget bound => success value state h budget (Nat.le_trans bound (Nat.le_succ _))
      · exact fun fault state h budget bound => failure fault state h budget (Nat.le_trans bound (Nat.le_succ _))

namespace VC
open Control.Verification
private theorem reference_eq (ref : MemoryAir.Ref) (env : MemoryAir.Env) :
    localSemantics.evalRef ref env = ref.eval env := rfl
private theorem truth_eq (value : Value) : localSemantics.truth value = MemoryAir.semantics.truth value := rfl
private theorem malformed_eq : localSemantics.malformed = .malformed := rfl
variable (program : Program) (resources : ResourcePolicy) (args : List Value)
    (invariants : Invariants) (post : Post) (errors : Exceptions)

theorem Stack.returned {frames localPost}
    (stack : Stack program resources args invariants post errors frames localPost)
    (value : Value) (state : State) (h : localPost (.returned value) state) : post (.returned value) state := by
  induction stack with
  | nil => exact h
  | block _ _ _ _ ih => exact ih h
  | loop _ _ _ _ ih => exact ih h

theorem Stack.jump {frames localPost}
    (stack : Stack program resources args invariants post errors frames localPost)
    (target : Nat) (value : Value) (env : MemoryAir.Env) (state : State)
    (h : localPost (.jumped target value env) state) :
    Certified program resources args invariants post errors (Control.Machine.jump localSemantics target value env state frames) := by
  induction stack with
  | nil => exact h
  | block outer id ty next ih =>
    simp only [blockPost] at h
    simp only [Control.Machine.jump]
    by_cases catches : target = id
    · simp only [catches, ↓reduceIte] at h ⊢
      by_cases typed : value.hasType ty = true
      · simp only [localSemantics, MemoryAir.semantics, typed, ↓reduceIte] at h ⊢
        exact ⟨_, outer, h⟩
      · simpa only [localSemantics, MemoryAir.semantics, typed, Bool.false_eq_true, ↓reduceIte, Certified, Terminal] using h
    · simp only [catches, ↓reduceIte] at h ⊢
      exact ih h
  | loop outer id body bodySafe ih =>
    simp only [loopPost] at h
    simp only [Control.Machine.jump]
    by_cases catches : target = id
    · simpa only [catches, ↓reduceIte, Certified, Terminal] using h
    · simp only [catches, ↓reduceIte] at h ⊢
      exact ih h

theorem Stack.backedge {frames localPost}
    (stack : Stack program resources args invariants post errors frames localPost)
    (target : Nat) (env : MemoryAir.Env) (state : State) (h : localPost (.repeated target env) state) :
    Certified program resources args invariants post errors (Control.Machine.backedge localSemantics target env state frames) := by
  induction stack with
  | nil => exact h
  | block outer id ty next ih =>
    simp only [blockPost] at h
    simp only [Control.Machine.backedge]
    by_cases catches : target = id
    · simpa only [catches, ↓reduceIte, Certified, Terminal] using h
    · simp only [catches, ↓reduceIte] at h ⊢
      exact ih h
  | loop outer id body bodySafe ih =>
    simp only [loopPost] at h
    simp only [Control.Machine.backedge]
    by_cases catches : target = id
    · simp only [catches, ↓reduceIte] at h ⊢
      exact ⟨_, Stack.loop outer id body bodySafe, bodySafe env state h⟩
    · simp only [catches, ↓reduceIte] at h ⊢
      exact ih h

/-- Local instructions preserve the structural certificate. Calls are handled
separately by their actual invocation contract, never by `localSemantics`. -/
theorem local_step_certified (config : Local)
    (ordinary : ∀ id type target refs next, config.code ≠ .bind id type (.call target refs) next)
    (h : Certified program resources args invariants post errors (.suspended config)) :
    Certified program resources args invariants post errors (Control.Machine.step localSemantics args config) := by
  obtain ⟨localPost, stack, h⟩ := h
  rcases config with ⟨code, env, state, frames⟩
  cases code with
  | bind id ty operation next =>
    cases operation with
    | call target refs => exact False.elim (ordinary id ty target refs next rfl)
    | memory operation =>
      cases evaluated : operation.eval args env state with
      | mk result after =>
        simp only [pre, effect, Control.Machine.step, localSemantics, MemoryAir.semantics, evaluated] at h ⊢
        cases result with
        | error fault => exact h
        | ok value =>
          by_cases typed : value.hasType ty = true
          · simp only [typed, ↓reduceIte] at h ⊢
            exact ⟨localPost, stack, h⟩
          · simpa only [typed, Bool.false_eq_true, ↓reduceIte, Certified, Terminal] using h
  | branch ref yes no =>
    cases evaluated : ref.eval env with
    | error fault => simpa only [pre, Control.Machine.step, reference_eq, evaluated, Certified, Terminal] using h
    | ok value =>
      cases truth : MemoryAir.semantics.truth value with
      | none => simpa only [pre, Control.Machine.step, reference_eq, truth_eq, evaluated, truth, malformed_eq, Certified, Terminal] using h
      | some flag =>
        cases flag <;> simp only [pre, Control.Machine.step, reference_eq, truth_eq, evaluated, truth, ↓reduceIte, Bool.false_eq_true] at h ⊢
        all_goals exact ⟨localPost, stack, h⟩
  | block id ty body next => exact ⟨_, Stack.block stack id ty next, h⟩
  | loop enabled id body => exact ⟨_, Stack.loop stack id body h.2, h.2 env state h.1⟩
  | «repeat» enabled target => exact stack.backedge program resources args invariants post errors target env state h
  | jump target ref =>
    simp only [pre] at h
    simp only [Control.Machine.step, localSemantics, MemoryAir.semantics]
    generalize ref.eval env = evaluated at h ⊢
    cases evaluated with
    | error fault => exact h
    | ok value => exact stack.jump program resources args invariants post errors target value env state h
  | ret ref =>
    simp only [pre] at h
    simp only [Control.Machine.step, localSemantics, MemoryAir.semantics]
    generalize ref.eval env = evaluated at h ⊢
    cases evaluated with
    | error fault => exact h
    | ok value => exact stack.returned program resources args invariants post errors value state h

def finishFlow (program : Program) (scope : Scope) : Flow Value → Task
  | .returned value => leave program scope (.ok value)
  | .jumped .. | .repeated .. => leave program scope (.error .malformed)

def finishPost (program : Program) (scope : Scope) (post : Postcondition) (errors : Exceptions) : Post :=
  fun flow => wp (finishFlow program scope flow) post errors

def finishErrors (program : Program) (scope : Scope) (post : Postcondition) (errors : Exceptions) : Exceptions :=
  fun fault => wp (leave program scope (.error fault)) post errors

private def liftLocal (program : Program) (scope : Scope) :
    Control.Machine.Execution Ty Prim MemoryAir.Ref Value Fault State → Execution
  | .suspended cursor => .suspended (scope.config cursor.code cursor.env cursor.frames cursor.state)
  | .finished (.returned value state) => (leave program scope (.ok value)).start state
  | .finished (.fault fault state) => (leave program scope (.error fault)).start state
  | .finished (.jumped _ _ _ state) => (leave program scope (.error .malformed)).start state

private theorem step_local (program : Program) (scope : Scope) (cursor : Local)
    (ordinary : ∀ id type target refs next, cursor.code ≠ .bind id type (.call target refs) next) :
    step program (scope.config cursor.code cursor.env cursor.frames cursor.state) =
      liftLocal program scope (Control.Machine.step localSemantics scope.arguments cursor) := by
  obtain ⟨code, env, state, frames⟩ := cursor
  cases code with
  | bind id type operation next => cases operation with
    | memory => rfl
    | call target refs => exact False.elim (ordinary id type target refs next rfl)
  | _ => rfl

/-- Structural certificates imply every finite observation of the actual
call-stack interpreter. Strong induction pays for the call transition before
using a callee summary; loop back edges never assume their own conclusion. -/
theorem certified_sound (program : Program) (scope : Scope) (invariants : Invariants)
    (post : Postcondition) (errors : Exceptions) (fuel : Nat) (cursor : Local)
    (checked : Certified program scope.resources scope.arguments invariants
      (finishPost program scope post errors) (finishErrors program scope post errors) (.suspended cursor)) :
    Observes post errors (advance program fuel
      (.suspended (scope.config cursor.code cursor.env cursor.frames cursor.state))) := by
  induction fuel using Nat.strongRecOn generalizing cursor with
  | ind fuel ih =>
    cases fuel with
    | zero => trivial
    | succ fuel =>
      change Observes post errors (advance program fuel
        (step program (scope.config cursor.code cursor.env cursor.frames cursor.state)))
      have ordinary (notCall : ∀ id type target refs next, cursor.code ≠ .bind id type (.call target refs) next) :
          Observes post errors (advance program fuel
            (step program (scope.config cursor.code cursor.env cursor.frames cursor.state))) := by
        rw [step_local program scope cursor notCall]
        have next := local_step_certified program scope.resources scope.arguments invariants
          (finishPost program scope post errors) (finishErrors program scope post errors) cursor notCall checked
        cases reached : Control.Machine.step localSemantics scope.arguments cursor with
        | suspended after =>
          rw [reached] at next
          exact ih fuel (by omega) after next
        | finished outcome =>
          rw [reached] at next
          cases outcome with
          | returned value state => exact next fuel
          | fault fault state => exact next fuel
          | jumped target value env state => exact next fuel
      obtain ⟨code, env, state, frames⟩ := cursor
      cases code with
      | bind id type operation next =>
        cases operation with
        | memory operation => exact ordinary (by intros; simp)
        | call target references =>
          obtain ⟨localPost, stack, h⟩ := checked
          simp only [pre, effect] at h
          rw [step_call program _ id type target references next rfl]
          simp only [Scope.config]
          cases read : references.mapM (fun ref => ref.eval env) with
          | error fault =>
            simp only [read] at h ⊢
            exact h fuel
          | ok values =>
            simp only [read] at h ⊢
            apply Ensures.attach_observes program scope.resources _ post _ errors _ fuel _
              (uses_start program target values state scope.resources) h
            · intro value after continuation budget bound
              by_cases typed : value.hasType type = true
              · simp only [typed, ↓reduceIte] at continuation
                simp only [attach, typed, ↓reduceIte]
                exact ih budget (by omega) ⟨next, env.set id value, after, frames⟩ ⟨localPost, stack, continuation⟩
              · simp only [typed, Bool.false_eq_true, ↓reduceIte] at continuation
                simp only [attach, typed, Bool.false_eq_true, ↓reduceIte]
                exact continuation budget
            · intro fault after continuation budget _bound
              exact continuation budget
      | _ => exact ordinary (by intros; simp)

/-- A generated body can be verified structurally with loop invariants and
checked helper contracts, then used through the ordinary execution WP. -/
theorem body_sound (program : Program) (scope : Scope) (invariants : Invariants)
    (code : Code) (env : MemoryAir.Env) (post : Postcondition) (errors : Exceptions)
    (state : State)
    (checked : pre program scope.resources scope.arguments invariants code
      (finishPost program scope post errors) (finishErrors program scope post errors) env state) :
    Ensures program ((execute program scope code env).start state) post errors := by
  intro fuel
  apply certified_sound program scope invariants post errors fuel ⟨code, env, state, []⟩
  refine ⟨_, Stack.nil, ?_⟩
  exact pre_mono program scope.resources scope.arguments invariants code _ _ _ _
    (fun flow heap h => by cases flow <;> exact h) (fun _ _ h => h) env state checked

end VC
end Compiler.ZigAir.MemoryCallMachine
