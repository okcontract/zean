/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.ControlVerification
import Compiler.ZigAir.MachineRefinement
import Std.WP

/-! Std.WP integration for structured control, including loop invariants.
`Task` is a verification language: `code` denotes the actual control tree;
`checkpoint` is an invariant obligation used only by the loop rule. The public
soundness theorem requires a `code` contract and connects it to the machine. -/
namespace Compiler.ZigAir.Control.Verification
open Std.WP Lean.Order Machine

inductive Task (sem : Semantics Ty Prim Ref Value Fault State) (args : List Value)
    (invariants : Invariants Value State) where
  | code (body : Code Ty Prim Ref true) (env : Env Value)
  | pure (flow : Flow Value)
  | fail (fault : Fault)
  | checkpoint (assertion : State → Prop)

variable (sem : Semantics Ty Prim Ref Value Fault State) (args : List Value)
    (invariants : Invariants Value State)

instance taskWP : WP (Task sem args invariants) (Flow Value) (State → Prop) (Errors Fault State) where
  wpTrans task := ⟨fun post errors state => match task with
    | .code body env => pre sem args invariants body post errors env state
    | .pure flow => post flow state
    | .fail fault => errors fault state
    | .checkpoint assertion => assertion state⟩
  wp_trans_monotone task post post' errors errors' he hp state h := by
    cases task with
    | code body env => exact pre_mono sem args invariants body post post' errors errors' hp he env state h
    | pure flow => exact hp _ _ h
    | fail fault => exact he _ _ h
    | checkpoint => exact h

theorem wp_code (body : Code Ty Prim Ref true) (env : Env Value) (post : Post Value State)
    (errors : Errors Fault State) (state : State) :
    wp (Task.code (sem := sem) (args := args) (invariants := invariants) body env) post errors state =
      pre sem args invariants body post errors env state := rfl

theorem wp_fail (fault : Fault) (post : Post Value State) (errors : Errors Fault State) :
    wp (Task.fail fault : Task sem args invariants) post errors = errors fault := rfl

@[spec] theorem pure_spec (flow : Flow Value) (post : Post Value State) (errors : Errors Fault State) :
    Triple (Task.pure (sem := sem) (args := args) (invariants := invariants) flow)
      (post flow) post errors := ⟨fun _ h => h⟩

@[spec] theorem fail_spec (fault : Fault) (post : Post Value State) (errors : Errors Fault State) :
    Triple (Task.fail (sem := sem) (args := args) (invariants := invariants) fault)
      (errors fault) post errors := ⟨fun _ h => h⟩

@[spec] theorem checkpoint_spec (assertion : State → Prop) (post : Post Value State) (errors : Errors Fault State) :
    Triple (Task.checkpoint (sem := sem) (args := args) (invariants := invariants) assertion)
      assertion post errors := ⟨fun _ h => h⟩

structure Atomic (sem : Semantics Ty Prim Ref Value Fault State) (args : List Value) where
  prim : Prim
  env : Env Value

instance atomicWP : WP (Atomic sem args) Value
    (State → Prop) (Errors Fault State) where
  wpTrans task := ⟨fun post errors state =>
    let (result, after) := sem.evalPrim task.prim args task.env state
    match result with
    | .ok value => post value after
    | .error fault => errors fault after⟩
  wp_trans_monotone task post post' errors errors' he hp state h := by
    dsimp only at h ⊢
    cases evaluated : sem.evalPrim task.prim args task.env state with
    | mk result after =>
      simp only [evaluated] at h ⊢
      cases result with
      | ok value => exact hp _ _ h
      | error fault => exact he _ _ h

theorem wp_atomic (prim : Prim) (env : Env Value) (post : Value → State → Prop)
    (errors : Errors Fault State) (state : State) :
    wp (Atomic.mk (sem := sem) (args := args) prim env) post errors state =
      (let (result, after) := sem.evalPrim prim args env state
       match result with | .ok value => post value after | .error fault => errors fault after) := rfl

@[spec low] theorem atomic_spec (prim : Prim) (env : Env Value)
    (post : Value → State → Prop) (errors : Errors Fault State) :
    Triple (Atomic.mk (sem := sem) (args := args) prim env)
      (fun state =>
        (⨅ value, ⨅ after, ⌜sem.evalPrim prim args env state = (.ok value, after)⌝ ⇨ post value after) ⊓
        (⨅ fault, ⨅ after, ⌜sem.evalPrim prim args env state = (.error fault, after)⌝ ⇨ errors fault after))
      post errors := by
  constructor
  intro state h
  simp only [meet_prop_eq_and, iInf_prop_eq_forall, himp_prop_eq_imp, ofProp_prop_eq] at h
  change (let (result, after) := sem.evalPrim prim args env state
          match result with | .ok value => post value after | .error fault => errors fault after)
  cases evaluated : sem.evalPrim prim args env state with
  | mk result after => cases result with
    | ok value => exact h.1 value after evaluated
    | error fault => exact h.2 fault after evaluated

@[spec] theorem bind_spec (id : Nat) (ty : Ty) (prim : Prim) (next : Code Ty Prim Ref true)
    (env : Env Value) (post : Post Value State) (errors : Errors Fault State) :
    Triple (Task.code (.bind id ty prim next) env : Task sem args invariants)
      (wp (Atomic.mk (sem := sem) (args := args) prim env)
        (fun value state =>
          (⌜sem.hasType value ty = true⌝ ⇨
            wp (Task.code next (env.set id value) : Task sem args invariants) post errors state) ⊓
          (⌜sem.hasType value ty ≠ true⌝ ⇨ errors sem.malformed state)) errors) post errors := by
  constructor
  intro state h
  rw [wp_atomic] at h
  change pre sem args invariants (.bind id ty prim next) post errors env state
  cases evaluated : sem.evalPrim prim args env state with
  | mk result after =>
    simp only [pre, evaluated] at h ⊢
    cases result with
    | error fault => exact h
    | ok value =>
      simp only [meet_prop_eq_and, himp_prop_eq_imp, ofProp_prop_eq] at h
      by_cases typed : sem.hasType value ty = true
      · simpa only [typed, ↓reduceIte, wp_code] using h.1 typed
      · simpa only [typed, Bool.false_eq_true, ↓reduceIte] using h.2 typed

@[spec] theorem ret_spec (ref : Ref) (env : Env Value) (post : Post Value State) (errors : Errors Fault State) :
    Triple (Task.code (.ret ref) env : Task sem args invariants)
      (fun state =>
        (⨅ value, ⌜sem.evalRef ref env = .ok value⌝ ⇨ post (.returned value) state) ⊓
        (⨅ fault, ⌜sem.evalRef ref env = .error fault⌝ ⇨ errors fault state)) post errors := by
  constructor
  intro state h
  simp only [meet_prop_eq_and, iInf_prop_eq_forall, himp_prop_eq_imp, ofProp_prop_eq] at h
  change pre sem args invariants (.ret ref) post errors env state
  cases evaluated : sem.evalRef ref env with
  | ok value => simpa only [pre, evaluated] using h.1 value evaluated
  | error fault => simpa only [pre, evaluated] using h.2 fault evaluated

@[spec] theorem jump_spec (target : Nat) (ref : Ref) (env : Env Value)
    (post : Post Value State) (errors : Errors Fault State) :
    Triple (Task.code (.jump target ref) env : Task sem args invariants)
      (fun state =>
        (⨅ value, ⌜sem.evalRef ref env = .ok value⌝ ⇨ post (.jumped target value env) state) ⊓
        (⨅ fault, ⌜sem.evalRef ref env = .error fault⌝ ⇨ errors fault state)) post errors := by
  constructor
  intro state h
  simp only [meet_prop_eq_and, iInf_prop_eq_forall, himp_prop_eq_imp, ofProp_prop_eq] at h
  change pre sem args invariants (.jump target ref) post errors env state
  cases evaluated : sem.evalRef ref env with
  | ok value => simpa only [pre, evaluated] using h.1 value evaluated
  | error fault => simpa only [pre, evaluated] using h.2 fault evaluated

@[spec] theorem repeat_spec (target : Nat) (env : Env Value)
    (post : Post Value State) (errors : Errors Fault State) :
    Triple (Task.code (.repeat rfl target) env : Task sem args invariants)
      (post (.repeated target env)) post errors := ⟨fun _ h => h⟩

@[spec] theorem branch_spec (ref : Ref) (yes no : Code Ty Prim Ref true) (env : Env Value)
    (post : Post Value State) (errors : Errors Fault State) :
    Triple (Task.code (.branch ref yes no) env : Task sem args invariants)
      (wp (match sem.evalRef ref env with
        | .error fault => (Task.fail fault : Task sem args invariants)
        | .ok value => match sem.truth value with
          | none => .fail sem.malformed
          | some true => .code yes env
          | some false => .code no env) post errors) post errors := by
  constructor
  intro state h
  change pre sem args invariants (.branch ref yes no) post errors env state
  cases evaluated : sem.evalRef ref env with
  | error fault => simpa only [pre, evaluated, wp_fail] using h
  | ok value =>
    cases truth : sem.truth value with
    | none => simpa only [pre, evaluated, truth, wp_fail] using h
    | some flag =>
      cases flag <;> simpa only [pre, evaluated, truth, Bool.false_eq_true, ↓reduceIte, wp_code] using h

def onBlock (id : Nat) (ty : Ty) (next : Code Ty Prim Ref true) : Flow Value → Task sem args invariants
  | .jumped target value env => if target = id then
      if sem.hasType value ty then .code next (env.set id value) else .fail sem.malformed
    else .pure (.jumped target value env)
  | .repeated target env => if target = id then .fail sem.malformed else .pure (.repeated target env)
  | flow => .pure flow

def onLoop (id : Nat) : Flow Value → Task sem args invariants
  | .repeated target env => if target = id then .checkpoint (invariants id env) else .pure (.repeated target env)
  | .jumped target value env => if target = id then .fail sem.malformed else .pure (.jumped target value env)
  | flow => .pure flow

attribute [spec] onBlock onLoop

theorem wp_onBlock (id : Nat) (ty : Ty) (next : Code Ty Prim Ref true)
    (post : Post Value State) (errors : Errors Fault State) (flow : Flow Value) :
    wp (onBlock sem args invariants id ty next flow) post errors =
      blockPost sem id ty (pre sem args invariants next post errors) post errors flow := by
  funext state
  cases flow with
  | returned value => rfl
  | jumped target value env =>
    simp only [onBlock, blockPost]
    split
    · split <;> rfl
    · rfl
  | repeated target env => simp only [onBlock, blockPost]; split <;> rfl

theorem wp_onLoop (id : Nat) (post : Post Value State) (errors : Errors Fault State)
    (flow : Flow Value) :
    wp (onLoop sem args invariants id flow) post errors =
      loopPost sem id (invariants id) post errors flow := by
  funext state
  cases flow with
  | returned value => rfl
  | jumped target value env => simp only [onLoop, loopPost]; split <;> rfl
  | repeated target env => simp only [onLoop, loopPost]; split <;> rfl

@[spec] theorem block_spec (id : Nat) (ty : Ty) (body next : Code Ty Prim Ref true) (env : Env Value)
    (post : Post Value State) (errors : Errors Fault State) :
    Triple (Task.code (.block id ty body next) env : Task sem args invariants)
      (wp (Task.code body env : Task sem args invariants)
        (fun flow => wp (onBlock sem args invariants id ty next flow) post errors) errors) post errors := by
  constructor
  intro state h
  change pre sem args invariants (.block id ty body next) post errors env state
  simpa only [wp_code, wp_onBlock, pre] using h

@[spec] theorem loop_spec (id : Nat) (body : Code Ty Prim Ref true) (env : Env Value)
    (post : Post Value State) (errors : Errors Fault State) :
    Triple (Task.code (.loop rfl id body) env : Task sem args invariants)
      (fun state => ⌜invariants id env state⌝ ⊓
        (⨅ other, ⨅ heap, ⌜invariants id other heap⌝ ⇨
          wp (Task.code body other : Task sem args invariants)
            (fun flow => wp (onLoop sem args invariants id flow) post errors) errors heap)) post errors := by
  constructor
  intro state h
  change pre sem args invariants (.loop rfl id body) post errors env state
  simpa only [pre, meet_prop_eq_and, iInf_prop_eq_forall, himp_prop_eq_imp, ofProp_prop_eq,
    wp_code, wp_onLoop] using h

/-- A back edge escaping the invocation is malformed, never successful. -/
def rootPost (post : Post Value State) (errors : Errors Fault State) : Post Value State :=
  fun flow state => match flow with
  | .repeated .. => errors sem.malformed state
  | _ => post flow state

/-- A vcgen contract proves safety and the terminal contract for every execution
budget. It does not assume that the machine eventually returns. -/
theorem code_sound (body : Code Ty Prim Ref true) (env : Env Value)
    (initial : State → Prop) (post : Post Value State) (errors : Errors Fault State)
    (contract : Triple (Task.code body env : Task sem args invariants)
      initial (rootPost sem post errors) errors)
    (state : State) (accepted : initial state) (fuel : Nat) :
    Certified sem args invariants post errors (run sem args fuel ⟨body, env, state, []⟩) := by
  exact advance_certified sem args invariants post errors fuel _
    ⟨rootPost sem post errors, Stack.nil, contract.le_wp state accepted⟩

theorem fault_of_contract (body : Code Ty Prim Ref true) (env : Env Value)
    (initial : State → Prop) (post : Post Value State) (errors : Errors Fault State)
    (contract : Triple (Task.code body env : Task sem args invariants)
      initial (rootPost sem post errors) errors)
    (state : State) (accepted : initial state) (fuel : Nat) (fault : Fault) (after : State)
    (reached : run sem args fuel ⟨body, env, state, []⟩ = .finished (.fault fault after)) :
    errors fault after := by
  have checked := code_sound sem args invariants body env initial post errors contract state accepted fuel
  rw [reached] at checked
  exact checked

/-- The same structural contract applies to any finite interpreter instance,
including a call-enabled instance. No second set of finite WP rules is needed. -/
theorem finite_code_sound (body : Code Ty Prim Ref) (env : Env Value)
    (initial : State → Prop) (post : Post Value State) (errors : Errors Fault State)
    (contract : Triple (Task.code body.enableLoops env : Task sem args invariants)
      initial (rootPost sem post errors) errors)
    (state : State) (accepted : initial state) :
    Terminal (rootPost sem post errors) errors (body.eval sem args env state) := by
  obtain ⟨fuel, done⟩ := finite_run sem args body env state
  have checked := code_sound sem args invariants body.enableLoops env initial post errors contract state accepted fuel
  rw [done] at checked
  exact checked

end Compiler.ZigAir.Control.Verification
