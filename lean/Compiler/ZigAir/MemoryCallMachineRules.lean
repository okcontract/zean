/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryCallMachineWP
import Compiler.ZigAir.MemoryCallArguments

/-! Instruction rules for the actual call-stack machine. The state-free scope
holds the invocation boundary; code and local control frames remain generated
data. Memory obligations reuse the established atomic Std.WP rules. -/
namespace Compiler.ZigAir.MemoryCallMachine
open Memory Std.WP Control.Verification Lean.Order

structure Scope where
  returnType : Ty
  mark : Nat
  arguments : List Value
  callers : List Caller := []
  resources : ResourcePolicy := .history

def Scope.config (scope : Scope) (code : Code) (env : MemoryAir.Env)
    (frames : List (Control.Machine.Frame Ty Prim MemoryAir.Ref)) (state : State) : Config :=
  ⟨⟨scope.returnType, scope.mark, scope.arguments, ⟨code, env, state, frames⟩⟩, scope.callers, scope.resources⟩

def execute (program : Program) (scope : Scope) (code : Code) (env : MemoryAir.Env)
    (frames : List (Control.Machine.Frame Ty Prim MemoryAir.Ref) := []) : Task :=
  ⟨program, fun state => .suspended (scope.config code env frames state)⟩

/-- Finishing an invocation still checks its declared result type and cleans
its locals. The dummy local cursor is never executed by `returned` or `fail`. -/
def leave (program : Program) (scope : Scope) (result : Except Fault Value) : Task :=
  ⟨program, fun state =>
    let config := scope.config (.ret (.constant (.scalar .unit))) (fun _ => none) [] state
    match result with
    | .ok value => returned config value state
    | .error fault => fail config fault state⟩

theorem leave_returned (scope : Scope) (code : Code) (env : MemoryAir.Env)
    (frames : List (Control.Machine.Frame Ty Prim MemoryAir.Ref)) (value : Value) (state : State) :
    returned (scope.config code env frames state) value state = (leave program scope (.ok value)).start state := rfl

theorem leave_failed (scope : Scope) (code : Code) (env : MemoryAir.Env)
    (frames : List (Control.Machine.Frame Ty Prim MemoryAir.Ref)) (fault : Fault) (state : State) :
    fail (scope.config code env frames state) fault state = (leave program scope (.error fault)).start state := rfl

theorem execute_of_step (scope : Scope) (code : Code) (env : MemoryAir.Env)
    (frames : List (Control.Machine.Frame Ty Prim MemoryAir.Ref))
    (post : Postcondition) (errors : Exceptions) (pre : State → Prop)
    (checked : ∀ state, pre state → Ensures program (step program (scope.config code env frames state)) post errors) :
    Triple (execute program scope code env frames) pre post errors := by
  constructor
  intro state initial fuel
  cases fuel with
  | zero => trivial
  | succ fuel => exact checked state initial fuel

@[spec] theorem within_error_spec (program : Program) (resources : ResourcePolicy) (callers : List Caller)
    (fault : Fault) (post : Postcondition) (errors : Exceptions) :
    Triple (within resources callers (finish program (.error fault)))
      (fun state => Observes post errors (unwind fault state callers resources)) post errors := by
  constructor
  intro state checked fuel
  simpa only [within, finish, attach, unwind_finished] using checked

theorem within_ok_spec (program : Program) (resources : ResourcePolicy) (callers : List Caller)
    (value : Value) (post : Postcondition) (errors : Exceptions) :
    Triple (within resources callers (finish program (.ok value)))
      (fun state => match callers with
        | [] => post value state
        | caller :: rest => if value.hasType caller.resultType then
            wp (execute program ⟨caller.activation.returnType, caller.activation.mark,
              caller.activation.arguments, rest, resources⟩ caller.activation.control.code
              (caller.activation.control.env.set caller.resultId value) caller.activation.control.frames) post errors state
          else Observes post errors (unwind .malformed (resources.cleanup caller.activation.mark state) rest resources))
      post errors := by
  constructor
  intro state checked fuel
  cases callers with
  | nil => simpa only [within, finish, attach, advance_finished, Observes] using checked
  | cons caller rest =>
    simp only [within, finish, attach]
    by_cases typed : value.hasType caller.resultType = true
    · simp only [typed, ↓reduceIte] at checked ⊢
      exact checked fuel
    · simp only [typed, Bool.false_eq_true, ↓reduceIte, unwind_finished] at checked ⊢
      exact checked

@[spec] theorem within_nil_spec (program : Program) (resources : ResourcePolicy)
    (value : Value) (post : Postcondition) (errors : Exceptions) :
    Triple (within resources [] (finish program (.ok value))) (post value) post errors :=
  within_ok_spec program resources [] value post errors

@[spec] theorem within_cons_spec (program : Program) (resources : ResourcePolicy)
    (caller : Caller) (rest : List Caller) (value : Value) (post : Postcondition) (errors : Exceptions) :
    Triple (within resources (caller :: rest) (finish program (.ok value)))
      (fun state =>
        (⌜value.hasType caller.resultType = true⌝ ⇨
          wp (execute program ⟨caller.activation.returnType, caller.activation.mark,
            caller.activation.arguments, rest, resources⟩ caller.activation.control.code
            (caller.activation.control.env.set caller.resultId value) caller.activation.control.frames) post errors state) ⊓
        (⌜value.hasType caller.resultType ≠ true⌝ ⇨
          Observes post errors (unwind .malformed (resources.cleanup caller.activation.mark state) rest resources)))
      post errors := by
  constructor
  intro state checked
  apply (within_ok_spec program resources (caller :: rest) value post errors).le_wp state
  simp only [meet_prop_eq_and, himp_prop_eq_imp, ofProp_prop_eq] at checked
  by_cases typed : value.hasType caller.resultType = true <;> simp only [typed, ↓reduceIte]
  · exact checked.1 typed
  · exact checked.2 typed

theorem leave_spec (program : Program) (scope : Scope) (result : Except Fault Value)
    (post : Postcondition) (errors : Exceptions) :
    Triple (leave program scope result)
      (fun state => match result with
        | .error fault => wp (within scope.resources scope.callers (finish program (.error fault)))
            post errors (scope.resources.cleanup scope.mark state)
        | .ok value => wp (within scope.resources scope.callers
            (finish program (if value.hasType scope.returnType then .ok value else .error .malformed)))
            post errors (scope.resources.cleanup scope.mark state)) post errors := by
  constructor
  intro state checked fuel
  cases result with
  | error => exact checked fuel
  | ok value =>
    by_cases typed : value.hasType scope.returnType = true <;>
      simp only [typed, ↓reduceIte, Bool.false_eq_true] at checked
    · cases callers : scope.callers <;>
        simpa only [leave, returned, Scope.config, within, finish, attach, callers, typed, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
          using checked fuel
    · simpa only [leave, returned, Scope.config, within, finish, attach, typed, Bool.not_false, ↓reduceIte]
        using checked fuel

@[spec] theorem leave_ok_spec (program : Program) (scope : Scope) (value : Value)
    (post : Postcondition) (errors : Exceptions) :
    Triple (leave program scope (.ok value))
      (fun state =>
        (⌜value.hasType scope.returnType = true⌝ ⇨
          wp (within scope.resources scope.callers (finish program (.ok value)))
            post errors (scope.resources.cleanup scope.mark state)) ⊓
        (⌜value.hasType scope.returnType ≠ true⌝ ⇨
          wp (within scope.resources scope.callers (finish program (.error .malformed)))
            post errors (scope.resources.cleanup scope.mark state))) post errors := by
  constructor
  intro state checked
  apply (leave_spec program scope (.ok value) post errors).le_wp state
  simp only [meet_prop_eq_and, himp_prop_eq_imp, ofProp_prop_eq] at checked
  by_cases typed : value.hasType scope.returnType = true <;> simp only [typed, ↓reduceIte]
  · exact checked.1 typed
  · exact checked.2 typed

@[spec] theorem leave_error_spec (program : Program) (scope : Scope) (fault : Fault)
    (post : Postcondition) (errors : Exceptions) :
    Triple (leave program scope (.error fault))
      (fun state => wp (within scope.resources scope.callers (finish program (.error fault)))
        post errors (scope.resources.cleanup scope.mark state)) post errors :=
  leave_spec program scope (.error fault) post errors

@[spec] theorem memory_spec (program : Program) (scope : Scope) (id : Nat) (type : Ty)
    (operation : MemoryAir.Prim) (next : Code) (env : MemoryAir.Env)
    (frames : List (Control.Machine.Frame Ty Prim MemoryAir.Ref)) (post : Postcondition) (errors : Exceptions) :
    Triple (execute program scope (.bind id type (.memory operation) next) env frames)
      (wp (Atomic.mk (sem := MemoryAir.semantics) (args := scope.arguments) operation env)
        (fun value state =>
          (⌜value.hasType type = true⌝ ⇨ wp (execute program scope next (env.set id value) frames) post errors state) ⊓
          (⌜value.hasType type ≠ true⌝ ⇨ wp (leave program scope (.error .malformed)) post errors state))
        (fun fault => wp (leave program scope (.error fault)) post errors)) post errors := by
  apply execute_of_step
  intro state checked
  rw [wp_atomic] at checked
  simp only [MemoryAir.semantics] at checked
  simp only [step, Scope.config, Control.Machine.step, localSemantics, MemoryAir.semantics]
  cases evaluated : operation.eval scope.arguments env state with
  | mk result after =>
    simp only [evaluated] at checked ⊢
    cases result with
    | error => simpa only [wp_task, leave, fail, Scope.config] using checked
    | ok value =>
      simp only [meet_prop_eq_and, himp_prop_eq_imp, ofProp_prop_eq] at checked
      by_cases typed : value.hasType type = true <;>
        simp only [typed, ↓reduceIte, Bool.false_eq_true]
      · simpa only [wp_task, execute, Scope.config] using checked.1 typed
      · simpa only [wp_task, leave, fail, Scope.config] using checked.2 typed

@[spec] theorem ret_spec (program : Program) (scope : Scope) (ref : MemoryAir.Ref) (env : MemoryAir.Env)
    (frames : List (Control.Machine.Frame Ty Prim MemoryAir.Ref)) (post : Postcondition) (errors : Exceptions) :
    Triple (execute program scope (.ret ref) env frames)
      (wp (MemoryAir.Verify.ReadReference.mk ref env)
        (fun value => wp (leave program scope (.ok value)) post errors)
        (fun fault => wp (leave program scope (.error fault)) post errors)) post errors := by
  apply execute_of_step
  intro state checked
  change (match ref.eval env with
    | .ok value => wp (leave program scope (.ok value)) post errors state
    | .error fault => wp (leave program scope (.error fault)) post errors state) at checked
  simp only [step, Scope.config, Control.Machine.step, localSemantics, MemoryAir.semantics]
  cases read : ref.eval env with
  | error fault =>
    simp only [read] at checked
    change Ensures program (fail (scope.config (.ret ref) env frames state) fault state) post errors
    rw [leave_failed]
    exact checked
  | ok value =>
    simp only [read] at checked
    change Ensures program (returned (scope.config (.ret ref) env frames state) value state) post errors
    rw [leave_returned]
    exact checked

@[spec] theorem block_spec (program : Program) (scope : Scope) (id : Nat) (type : Ty)
    (body next : Code) (env : MemoryAir.Env) (frames : List (Control.Machine.Frame Ty Prim MemoryAir.Ref))
    (post : Postcondition) (errors : Exceptions) :
    Triple (execute program scope (.block id type body next) env frames)
      (wp (execute program scope body env (.block id type next :: frames)) post errors) post errors := by
  apply execute_of_step
  intro state checked
  exact checked

@[spec] theorem call_spec (program : Program) (returnType : Ty) (mark : Nat)
    (arguments : List Value) (callers : List Caller) (resources : ResourcePolicy) (id : Nat) (type : Ty)
    (target : Nat) (references : List MemoryAir.Ref) (next : Code) (env : MemoryAir.Env)
    (frames : List (Control.Machine.Frame Ty Prim MemoryAir.Ref)) (post : Postcondition) (errors : Exceptions) :
    Triple (execute program ⟨returnType, mark, arguments, callers, resources⟩
      (.bind id type (.call target references) next) env frames)
      (wp (MemoryCall.readArguments references env)
        (fun args state => wp (within resources
            (⟨⟨returnType, mark, arguments, ⟨next, env, state, frames⟩⟩, id, type⟩ :: callers)
            (invoke program target args resources)) post errors state)
        (fun fault => wp (leave program ⟨returnType, mark, arguments, callers, resources⟩ (.error fault)) post errors)) post errors := by
  apply execute_of_step
  intro state checked
  simp only [wp, WP.wpTrans, MemoryCall.readArguments] at checked
  rw [step_call program _ id type target references next rfl]
  cases read : references.mapM (fun ref => ref.eval env) <;>
    simpa only [Scope.config, read, wp_task, leave, fail, within, invoke] using checked

def enter (program : Program) (function : Function) (args : List Value) (resources : ResourcePolicy) : Task :=
  ⟨program, fun state => if function.accepts args state then
      (execute program ⟨function.returnType, state.nextId, args, [], resources⟩ function.body (fun _ => none)).start state
    else .finished (.error .malformed) state⟩

/-- Resolve an immutable table entry without changing memory. Separate lookup
rules let `vcgen` select a known body without splitting on an opaque lookup. -/
def readFunction (program : Program) (root : Nat) : EStateM Fault State Function :=
  fun state => match program[root]? with
    | none => .error .unsupported state
    | some function => .ok function state

@[spec] theorem readFunction_nil (root : Nat) (post : Function → State → Prop) (errors : Exceptions) :
    Triple (readFunction [] root) (errors .unsupported) post errors := ⟨fun _ h => h⟩

@[spec] theorem readFunction_zero (function : Function) (rest : Program)
    (post : Function → State → Prop) (errors : Exceptions) :
    Triple (readFunction (function :: rest) 0) (post function) post errors := ⟨fun _ h => h⟩

@[spec] theorem readFunction_succ (function : Function) (rest : Program) (root : Nat)
    (post : Function → State → Prop) (errors : Exceptions) :
    Triple (readFunction (function :: rest) (root + 1))
      (wp (readFunction rest root) post errors) post errors := ⟨fun _ h => h⟩

@[spec low] theorem invoke_spec (program : Program) (root : Nat) (args : List Value)
    (resources : ResourcePolicy) (post : Postcondition) (errors : Exceptions) :
    Triple (invoke program root args resources)
      (wp (readFunction program root)
        (fun function => wp (enter program function args resources) post errors) errors) post errors := by
  constructor
  intro state checked fuel
  simp only [wp, WP.wpTrans, readFunction] at checked
  simp only [invoke, start]
  cases found : program[root]? with
  | none => simpa only [found, advance_finished, Observes] using checked
  | some function =>
    simp only [found] at checked
    change Ensures program (if function.accepts args state then _ else _) post errors at checked
    exact checked fuel

@[spec] theorem enter_spec (program : Program) (function : Function) (args : List Value)
    (resources : ResourcePolicy) (post : Postcondition) (errors : Exceptions) :
    Triple (enter program function args resources)
      (fun state =>
        (⌜function.accepts args state = true⌝ ⇨
          wp (execute program ⟨function.returnType, state.nextId, args, [], resources⟩
            function.body (fun _ => none)) post errors state) ⊓
        (⌜function.accepts args state ≠ true⌝ ⇨ errors .malformed state)) post errors := by
  constructor
  intro state checked fuel
  simp only [meet_prop_eq_and, himp_prop_eq_imp, ofProp_prop_eq] at checked
  change Observes post errors (advance program fuel ((enter program function args resources).start state))
  simp only [enter]
  by_cases accepted : function.accepts args state = true
  · simpa only [accepted, ↓reduceIte, execute] using checked.1 accepted fuel
  · simpa only [accepted, Bool.false_eq_true, ↓reduceIte, advance_finished, Observes] using checked.2 accepted

@[spec] theorem within_invoke_spec (program : Program) (resources : ResourcePolicy) (callers : List Caller)
    (root : Nat) (args : List Value) (post : Postcondition) (errors : Exceptions) :
    Triple (within resources callers (invoke program root args resources))
      (wp (invoke program root args resources)
        (fun value => wp (within resources callers (finish program (.ok value))) post errors)
        (fun fault => wp (within resources callers (finish program (.error fault))) post errors)) post errors :=
  within_spec resources callers _ (fun state => uses_start program root args state resources) post errors

end Compiler.ZigAir.MemoryCallMachine
