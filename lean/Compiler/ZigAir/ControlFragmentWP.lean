/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.ControlWP

/-! Compositional contracts for inline instruction fragments. A fragment is
program data, and its contract can be reused before any continuation. The
prependCode rule is proved against the same structured precondition semantics;
it does not introduce a runtime call or skip instructions. -/
namespace Compiler.ZigAir.Control.Verification
open Std.WP Lean.Order

structure Instruction (Ty Prim : Type) where
  id : Nat
  type : Ty
  operation : Prim

def prependCode (instructions : List (Instruction Ty Prim)) (next : Code Ty Prim Ref true) : Code Ty Prim Ref true :=
  instructions.foldr (fun instruction rest => .bind instruction.id instruction.type instruction.operation rest) next

def fragmentPre (sem : Semantics Ty Prim Ref Value Fault State) (args : List Value) :
    List (Instruction Ty Prim) → Env Value → (Env Value → State → Prop) → Errors Fault State → State → Prop
  | [], env, post, _, state => post env state
  | instruction :: rest, env, post, errors, state =>
    let (result, after) := sem.evalPrim instruction.operation args env state
    match result with
    | .error fault => errors fault after
    | .ok value => if sem.hasType value instruction.type then
        fragmentPre sem args rest (env.set instruction.id value) post errors after
      else errors sem.malformed after

theorem fragmentPre_mono (sem : Semantics Ty Prim Ref Value Fault State) (args : List Value)
    (instructions : List (Instruction Ty Prim)) (env : Env Value)
    (post post' : Env Value → State → Prop) (errors errors' : Errors Fault State)
    (hp : post ⊑ post') (he : errors ⊑ errors') (state : State)
    (h : fragmentPre sem args instructions env post errors state) :
    fragmentPre sem args instructions env post' errors' state := by
  induction instructions generalizing env state with
  | nil => exact hp _ _ h
  | cons instruction rest ih =>
    simp only [fragmentPre] at h ⊢
    cases evaluated : sem.evalPrim instruction.operation args env state with
    | mk result after =>
      simp only [evaluated] at h ⊢
      cases result with
      | error fault => exact he _ _ h
      | ok value =>
        by_cases typed : sem.hasType value instruction.type = true
        · simp only [typed, ↓reduceIte] at h ⊢; exact ih _ _ h
        · simp only [typed, Bool.false_eq_true, ↓reduceIte] at h ⊢; exact he _ _ h

structure Fragment (sem : Semantics Ty Prim Ref Value Fault State) (args : List Value) where
  instructions : List (Instruction Ty Prim)
  env : Env Value

instance fragmentWP (sem : Semantics Ty Prim Ref Value Fault State) (args : List Value) :
    WP (Fragment sem args) (Env Value) (State → Prop) (Errors Fault State) where
  wpTrans fragment := ⟨fragmentPre sem args fragment.instructions fragment.env⟩
  wp_trans_monotone fragment post post' errors errors' he hp :=
    fragmentPre_mono sem args fragment.instructions fragment.env post post' errors errors' hp he

theorem wp_fragment (sem : Semantics Ty Prim Ref Value Fault State) (args : List Value)
    (instructions : List (Instruction Ty Prim)) (env : Env Value) (post : Env Value → State → Prop)
    (errors : Errors Fault State) :
    wp (Fragment.mk (sem := sem) (args := args) instructions env) post errors =
      fragmentPre sem args instructions env post errors := rfl

@[spec] theorem fragment_nil_spec (sem : Semantics Ty Prim Ref Value Fault State) (args : List Value)
    (env : Env Value) (post : Env Value → State → Prop) (errors : Errors Fault State) :
    Triple (Fragment.mk (sem := sem) (args := args) [] env) (post env) post errors := ⟨fun _ h => h⟩

@[spec] theorem fragment_cons_spec (sem : Semantics Ty Prim Ref Value Fault State) (args : List Value)
    (instruction : Instruction Ty Prim) (rest : List (Instruction Ty Prim)) (env : Env Value)
    (post : Env Value → State → Prop) (errors : Errors Fault State) :
    Triple (Fragment.mk (sem := sem) (args := args) (instruction :: rest) env)
      (wp (Atomic.mk (sem := sem) (args := args) instruction.operation env)
        (fun value state =>
          (⌜sem.hasType value instruction.type = true⌝ ⇨
            wp (Fragment.mk (sem := sem) (args := args) rest (env.set instruction.id value)) post errors state) ⊓
          (⌜sem.hasType value instruction.type ≠ true⌝ ⇨ errors sem.malformed state)) errors) post errors := by
  constructor
  intro state h
  rw [wp_atomic] at h
  rw [wp_fragment]
  cases evaluated : sem.evalPrim instruction.operation args env state with
  | mk result after =>
    simp only [fragmentPre, evaluated] at h ⊢
    cases result with
    | error fault => exact h
    | ok value =>
      simp only [meet_prop_eq_and, himp_prop_eq_imp, ofProp_prop_eq] at h
      by_cases typed : sem.hasType value instruction.type = true
      · simpa only [typed, ↓reduceIte, wp_fragment] using h.1 typed
      · simpa only [typed, Bool.false_eq_true, ↓reduceIte] using h.2 typed

theorem pre_prefix (sem : Semantics Ty Prim Ref Value Fault State) (args : List Value)
    (invariants : Invariants Value State) (instructions : List (Instruction Ty Prim))
    (next : Code Ty Prim Ref true) (env : Env Value) (post : Post Value State) (errors : Errors Fault State)
    (state : State) :
    pre sem args invariants (prependCode instructions next) post errors env state =
      fragmentPre sem args instructions env (pre sem args invariants next post errors) errors state := by
  induction instructions generalizing env state with
  | nil => rfl
  | cons instruction rest ih =>
    simp only [prependCode, List.foldr_cons, pre, fragmentPre]
    cases evaluated : sem.evalPrim instruction.operation args env state with
    | mk result after =>
      simp only [evaluated]
      cases result with
      | error => rfl
      | ok value =>
        simp only
        split
        · exact ih _ _
        · rfl

@[spec high] theorem prefix_spec (sem : Semantics Ty Prim Ref Value Fault State) (args : List Value)
    (invariants : Invariants Value State) (instructions : List (Instruction Ty Prim))
    (next : Code Ty Prim Ref true) (env : Env Value) (post : Post Value State) (errors : Errors Fault State) :
    Triple (Task.code (prependCode instructions next) env : Task sem args invariants)
      (wp (Fragment.mk (sem := sem) (args := args) instructions env)
        (fun env => wp (Task.code next env : Task sem args invariants) post errors) errors) post errors := by
  constructor
  intro state h
  change fragmentPre sem args instructions env (pre sem args invariants next post errors) errors state at h
  rw [wp_code, pre_prefix]
  exact h

/-- Reuse a checked helper contract before an arbitrary continuation. The
helper's exception condition is retained, including its reached state. -/
theorem prefix_contract (sem : Semantics Ty Prim Ref Value Fault State) (args : List Value)
    (invariants : Invariants Value State) (instructions : List (Instruction Ty Prim))
    (next : Code Ty Prim Ref true) (env : Env Value) (initial : State → Prop)
    (middle : Env Value → State → Prop) (post : Post Value State) (errors : Errors Fault State)
    (helper : Triple (Fragment.mk (sem := sem) (args := args) instructions env) initial middle errors)
    (continuation : ∀ locals, Triple (Task.code next locals : Task sem args invariants)
      (middle locals) post errors) :
    Triple (Task.code (prependCode instructions next) env : Task sem args invariants) initial post errors := by
  constructor
  intro state accepted
  apply (prefix_spec sem args invariants instructions next env post errors).le_wp state
  exact WP.wp_consequence _ middle _ errors (fun locals => (continuation locals).le_wp)
    state (helper.le_wp state accepted)

end Compiler.ZigAir.Control.Verification
