/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryCallMachineVCProofs
import Compiler.ZigAir.MemoryReadTyping

/-! Std.WP rules for structured call-machine obligations. The public `verify`
action denotes the same invocation as `invoke`; its invariant argument selects
a proof rule, never executable behavior. -/
namespace Compiler.ZigAir.MemoryCallMachine.VC
open Memory Std.WP Control.Verification Lean.Order

structure Context where
  program : Program
  resources : ResourcePolicy
  arguments : List Value
  invariants : Invariants

inductive Action where
  | code (context : Context) (body : Code) (env : MemoryAir.Env)
  | pure (flow : Flow Value)
  | fail (fault : Fault)
  | checkpoint (assertion : State → Prop)

instance actionWP : WP Action (Flow Value) (State → Prop) Exceptions where
  wpTrans action := ⟨fun post errors state => match action with
    | .code context body env => pre context.program context.resources context.arguments context.invariants body post errors env state
    | .pure flow => post flow state
    | .fail fault => errors fault state
    | .checkpoint assertion => assertion state⟩
  wp_trans_monotone action post post' errors errors' he hp state checked := by
    cases action with
    | code context body env => exact pre_mono _ _ _ _ body post post' errors errors' hp he env state checked
    | pure flow => exact hp _ _ checked
    | fail fault => exact he _ _ checked
    | checkpoint => exact checked

theorem wp_code (context : Context) (body : Code) (env : MemoryAir.Env) (post : Post) (errors : Exceptions) :
    wp (Action.code context body env) post errors =
      pre context.program context.resources context.arguments context.invariants body post errors env := rfl

@[spec] theorem pure_spec (flow : Flow Value) (post : Post) (errors : Exceptions) :
    Triple (Action.pure flow) (post flow) post errors := ⟨fun _ h => h⟩

@[spec] theorem fail_spec (fault : Fault) (post : Post) (errors : Exceptions) :
    Triple (Action.fail fault) (errors fault) post errors := ⟨fun _ h => h⟩

@[spec] theorem checkpoint_spec (assertion : State → Prop) (post : Post) (errors : Exceptions) :
    Triple (Action.checkpoint assertion) assertion post errors := ⟨fun _ h => h⟩

structure Effect where
  context : Context
  operation : Prim
  env : MemoryAir.Env

instance effectWP : WP Effect Value (State → Prop) Exceptions where
  wpTrans task := ⟨effect task.context.program task.context.resources task.context.arguments task.operation task.env⟩
  wp_trans_monotone task post post' errors errors' he hp :=
    effect_mono task.context.program task.context.resources task.context.arguments task.operation task.env post post' errors errors' hp he

theorem wp_effect (context : Context) (operation : Prim) (env : MemoryAir.Env)
    (post : Postcondition) (errors : Exceptions) :
    wp (Effect.mk context operation env) post errors =
      effect context.program context.resources context.arguments operation env post errors := rfl

@[spec] theorem memory_spec (context : Context) (operation : MemoryAir.Prim) (env : MemoryAir.Env)
    (post : Postcondition) (errors : Exceptions) :
    Triple (Effect.mk context (.memory operation) env)
      (wp (Atomic.mk (sem := MemoryAir.semantics) (args := context.arguments) operation env) post errors)
      post errors := by
  constructor
  intro state h
  rw [wp_atomic] at h
  rw [wp_effect]
  cases evaluated : operation.eval context.arguments env state with
  | mk result after => cases result <;> simpa only [effect, MemoryAir.semantics, evaluated] using h

@[spec] theorem call_spec (program : Program) (resources : ResourcePolicy) (args : List Value)
    (invariants : Invariants) (target : Nat) (references : List MemoryAir.Ref) (env : MemoryAir.Env)
    (post : Postcondition) (errors : Exceptions) :
    Triple (Effect.mk ⟨program, resources, args, invariants⟩ (.call target references) env)
      (wp (MemoryCall.readArguments references env)
        (fun values => wp (invoke program target values resources) post errors) errors) post errors := by
  constructor
  intro state checked
  rw [wp_effect]
  simp only [wp, WP.wpTrans, MemoryCall.readArguments] at checked
  cases read : references.mapM (fun ref => ref.eval env) <;> simpa only [effect, read, wp_task] using checked

@[spec] theorem bind_spec (context : Context) (id : Nat) (type : Ty) (operation : Prim) (next : Code)
    (env : MemoryAir.Env) (post : Post) (errors : Exceptions) :
    Triple (Action.code context (.bind id type operation next) env)
      (wp (Effect.mk context operation env)
        (fun value state =>
          (⌜value.hasType type = true⌝ ⇨ wp (Action.code context next (env.set id value)) post errors state) ⊓
          (⌜value.hasType type ≠ true⌝ ⇨ errors .malformed state)) errors) post errors := by
  constructor
  intro state checked
  rw [wp_code]
  rw [wp_effect] at checked
  apply effect_mono context.program context.resources context.arguments operation env _ _ errors errors _ (fun _ _ h => h) state checked
  intro value after h
  simp only [meet_prop_eq_and, himp_prop_eq_imp, ofProp_prop_eq] at h
  by_cases typed : value.hasType type = true <;> simp only [typed, ↓reduceIte]
  · exact h.1 typed
  · exact h.2 typed

@[spec] theorem ret_spec (context : Context) (ref : MemoryAir.Ref) (env : MemoryAir.Env)
    (post : Post) (errors : Exceptions) :
    Triple (Action.code context (.ret ref) env)
      (wp (MemoryAir.Verify.ReadReference.mk ref env) (fun value => post (.returned value)) errors) post errors := by
  constructor
  intro state h
  rw [wp_code]
  rw [MemoryAir.Verify.wp_reference] at h
  cases read : ref.eval env <;> simpa only [pre, read] using h

@[spec] theorem jump_spec (context : Context) (target : Nat) (ref : MemoryAir.Ref) (env : MemoryAir.Env)
    (post : Post) (errors : Exceptions) :
    Triple (Action.code context (.jump target ref) env)
      (wp (MemoryAir.Verify.ReadReference.mk ref env) (fun value => post (.jumped target value env)) errors) post errors := by
  constructor
  intro state h
  rw [wp_code]
  rw [MemoryAir.Verify.wp_reference] at h
  cases read : ref.eval env <;> simpa only [pre, read] using h

@[spec] theorem repeat_spec (context : Context) (target : Nat) (env : MemoryAir.Env)
    (post : Post) (errors : Exceptions) :
    Triple (Action.code context (.repeat rfl target) env) (post (.repeated target env)) post errors := ⟨fun _ h => h⟩

def choose (context : Context) (value : Value) (yes no : Code) (env : MemoryAir.Env) : Action :=
  match value with
  | .scalar (.bool flag) => if flag then .code context yes env else .code context no env
  | _ => .fail .malformed

/-- Typed Boolean selection exposes two paths. The invalid path is a typing
obligation, so an opaque helper's Boolean result contract is sufficient. -/
@[spec] theorem choose_spec (context : Context) (value : Value) (yes no : Code) (env : MemoryAir.Env)
    (post : Post) (errors : Exceptions) :
    Triple (choose context value yes no env)
      (fun state =>
        (⨅ flag, ⌜value = .scalar (.bool flag)⌝ ⇨
          wp (if flag then Action.code context yes env else Action.code context no env) post errors state) ⊓
        (⌜value.hasType (.scalar .bool) ≠ true⌝ ⇨ errors .malformed state)) post errors := by
  constructor
  intro state h
  simp only [meet_prop_eq_and, iInf_prop_eq_forall, himp_prop_eq_imp, ofProp_prop_eq] at h
  by_cases typed : value.hasType (.scalar .bool) = true
  · obtain ⟨flag, rfl⟩ := value.boolean_value typed
    exact h.1 flag rfl
  · have choice : choose context value yes no env = .fail .malformed := by
      cases value with
      | scalar scalar => cases scalar with
        | bool flag => exact False.elim (typed rfl)
        | int | enumTag | unit => rfl
      | _ => rfl
    rw [choice]
    exact h.2 typed

@[spec] theorem branch_spec (context : Context) (ref : MemoryAir.Ref) (yes no : Code) (env : MemoryAir.Env)
    (post : Post) (errors : Exceptions) :
    Triple (Action.code context (.branch ref yes no) env)
      (wp (MemoryAir.Verify.ReadReference.mk ref env)
        (fun value => wp (choose context value yes no env) post errors) errors) post errors := by
  constructor
  intro state h
  change (match ref.eval env with
    | .ok value => wp (choose context value yes no env) post errors state
    | .error fault => errors fault state) at h
  change pre _ _ _ _ _ _ _ _ _
  cases read : ref.eval env with
  | error fault => simpa only [pre, read] using h
  | ok value =>
    simp only [read] at h
    simp only [pre, read]
    cases value with
    | scalar scalar => cases scalar <;> first
        | exact h
        | (rename_i flag; cases flag <;> exact h)
    | _ => exact h

def onBlock (context : Context) (id : Nat) (type : Ty) (next : Code) : Flow Value → Action
  | .jumped target value env => if target = id then
      if value.hasType type then .code context next (env.set id value) else .fail .malformed
    else .pure (.jumped target value env)
  | .repeated target env => if target = id then .fail .malformed else .pure (.repeated target env)
  | flow => .pure flow

def onLoop (context : Context) (id : Nat) : Flow Value → Action
  | .repeated target env => if target = id then .checkpoint (context.invariants id env) else .pure (.repeated target env)
  | .jumped target value env => if target = id then .fail .malformed else .pure (.jumped target value env)
  | flow => .pure flow
attribute [spec] onBlock onLoop finishFlow

theorem wp_onBlock (context : Context) (id : Nat) (type : Ty) (next : Code)
    (post : Post) (errors : Exceptions) (flow : Flow Value) :
    wp (onBlock context id type next flow) post errors =
      blockPost localSemantics id type (pre context.program context.resources context.arguments context.invariants next post errors) post errors flow := by
  funext state
  cases flow with
  | returned => rfl
  | jumped target value env =>
    by_cases catches : target = id
    · by_cases typed : value.hasType type = true <;>
        simp only [onBlock, blockPost, localSemantics, MemoryAir.semantics, catches, typed, ↓reduceIte] <;> rfl
    · simp only [onBlock, blockPost, catches, ↓reduceIte]; rfl
  | repeated target env => simp only [onBlock, blockPost]; split <;> rfl

theorem wp_onLoop (context : Context) (id : Nat) (post : Post) (errors : Exceptions) (flow : Flow Value) :
    wp (onLoop context id flow) post errors = loopPost localSemantics id (context.invariants id) post errors flow := by
  funext state
  cases flow with
  | returned => rfl
  | jumped target value env => simp only [onLoop, loopPost]; split <;> rfl
  | repeated target env => simp only [onLoop, loopPost]; split <;> rfl

@[spec] theorem block_spec (context : Context) (id : Nat) (type : Ty) (body next : Code) (env : MemoryAir.Env)
    (post : Post) (errors : Exceptions) :
    Triple (Action.code context (.block id type body next) env)
      (wp (Action.code context body env) (fun flow => wp (onBlock context id type next flow) post errors) errors) post errors := by
  constructor
  intro state h
  simpa only [wp_code, wp_onBlock, pre] using h

@[spec] theorem loop_spec (context : Context) (id : Nat) (body : Code) (env : MemoryAir.Env)
    (post : Post) (errors : Exceptions) :
    Triple (Action.code context (.loop rfl id body) env)
      (fun state => ⌜context.invariants id env state⌝ ⊓
        (⨅ other, ⨅ heap, ⌜context.invariants id other heap⌝ ⇨
          wp (Action.code context body other) (fun flow => wp (onLoop context id flow) post errors) errors heap)) post errors := by
  constructor
  intro state h
  simpa only [wp_code, wp_onLoop, pre, meet_prop_eq_and, iInf_prop_eq_forall, himp_prop_eq_imp, ofProp_prop_eq] using h

end Compiler.ZigAir.MemoryCallMachine.VC

namespace Compiler.ZigAir.MemoryCallMachine
open Memory Std.WP Lean.Order

/-- Verify this actual invocation using client-supplied loop invariants. -/
def verify (program : Program) (root : Nat) (args : List Value) (_invariants : VC.Invariants)
    (resources : ResourcePolicy := .history) : Task := invoke program root args resources

def enterWith (program : Program) (function : Function) (args : List Value)
    (_invariants : VC.Invariants) (resources : ResourcePolicy) : Task := enter program function args resources

/-- Reuse a body proof in any table that contains this exact function. The
table remains the execution context of every call made by the body. -/
theorem verify_at (program : Program) (root : Nat) (function : Function)
    (found : program[root]? = some function) (args : List Value) (invariants : VC.Invariants)
    (resources : ResourcePolicy := .history) :
    verify program root args invariants resources = enterWith program function args invariants resources := by
  simp only [verify, invoke, start, found, enterWith, enter, execute, Scope.config]

@[spec] theorem verify_spec (program : Program) (root : Nat) (args : List Value) (invariants : VC.Invariants)
    (resources : ResourcePolicy) (post : Postcondition) (errors : Exceptions) :
    Triple (verify program root args invariants resources)
      (wp (readFunction program root)
        (fun function => wp (enterWith program function args invariants resources) post errors) errors) post errors :=
  invoke_spec program root args resources post errors

@[spec] theorem enterWith_spec (program : Program) (function : Function) (args : List Value)
    (invariants : VC.Invariants) (resources : ResourcePolicy) (post : Postcondition) (errors : Exceptions) :
    Triple (enterWith program function args invariants resources)
      (fun state =>
        (⌜function.accepts args state = true⌝ ⇨
          wp (VC.Action.code ⟨program, resources, args, invariants⟩ function.body (fun _ => none))
            (fun flow => wp (VC.finishFlow program ⟨function.returnType, state.nextId, args, [], resources⟩ flow) post errors)
            (fun fault => wp (leave program ⟨function.returnType, state.nextId, args, [], resources⟩ (.error fault)) post errors) state) ⊓
        (⌜function.accepts args state ≠ true⌝ ⇨ errors .malformed state)) post errors := by
  constructor
  intro state h
  apply (enter_spec program function args resources post errors).le_wp state
  simp only [meet_prop_eq_and, himp_prop_eq_imp, ofProp_prop_eq] at h ⊢
  exact ⟨fun accepted => VC.body_sound program _ invariants function.body _ post errors state (h.1 accepted), h.2⟩

end Compiler.ZigAir.MemoryCallMachine
