/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryExecution
import Compiler.ZigAir.MemoryReclaim

/-! Interprocedural execution with data-based function identities. A suspended
configuration retains the complete call stack. Fuel counts transitions, never
native time. Contracts do not replace executable callees. -/
namespace Compiler.ZigAir.MemoryCallMachine
open Memory

inductive Prim where
  | memory (operation : MemoryAir.Prim)
  | call (function : Nat) (arguments : List MemoryAir.Ref)

abbrev Code := Control.Code Ty Prim MemoryAir.Ref true

structure Function where
  parameters : List Ty
  returnType : Ty
  body : Code

abbrev Program := List Function

def Function.accepts (function : Function) (args : List Value) (state : State) : Bool :=
  state.valid && args.length = function.parameters.length &&
    (args.zip function.parameters).all (fun (value, type) => value.hasType type)

abbrev Local := Control.Machine.Config Ty Prim MemoryAir.Ref Value State

/-- Historical allocation accounting remains available for exact adapters.
Reuse changes only resource accounting at invocation boundaries. -/
inductive ResourcePolicy where
  | history
  | reuse

def ResourcePolicy.cleanup (policy : ResourcePolicy) (mark : Nat) (state : State) : State :=
  match policy with
  | .history => Memory.cleanup mark state
  | .reuse => cleanupReusing mark state

structure Activation where
  returnType : Ty
  mark : Nat
  arguments : List Value
  control : Local

/-- The caller environment is restored at return, then the result is bound.
The callee's memory effects survive; its locals and control frames do not. -/
structure Caller where
  activation : Activation
  resultId : Nat
  resultType : Ty

structure Config where
  active : Activation
  callers : List Caller := []
  resources : ResourcePolicy := .history

inductive Execution where
  | finished (result : Except Fault Value) (state : State)
  | suspended (config : Config)

def Execution.state : Execution → State
  | .finished _ state => state
  | .suspended config => config.active.control.state

def unwind (fault : Fault) (state : State) (callers : List Caller)
    (resources : ResourcePolicy := .history) : Execution :=
  match callers with
  | [] => .finished (.error fault) state
  | caller :: rest => unwind fault (resources.cleanup caller.activation.mark state) rest resources

def fail (config : Config) (fault : Fault) (state : State) : Execution :=
  unwind fault (config.resources.cleanup config.active.mark state) config.callers config.resources

def returned (config : Config) (value : Value) (state : State) : Execution :=
  let after := config.resources.cleanup config.active.mark state
  if !value.hasType config.active.returnType then unwind .malformed after config.callers config.resources else
  match config.callers with
  | [] => .finished (.ok value) after
  | caller :: rest =>
    if value.hasType caller.resultType then
      .suspended ⟨{ caller.activation with control :=
        { caller.activation.control with state := after, env := caller.activation.control.env.set caller.resultId value } }, rest, config.resources⟩
    else unwind .malformed (config.resources.cleanup caller.activation.mark after) rest config.resources

/-- Calls are intercepted by `step`. The local machine cannot execute one as
an opaque summary, even if it is accidentally invoked directly. -/
def localSemantics : Control.Semantics Ty Prim MemoryAir.Ref Value Fault State :=
  { MemoryAir.semantics with evalPrim := fun operation args env state =>
      match operation with
      | .memory operation => operation.eval args env state
      | .call .. => (.error .unsupported, state) }

def step (program : Program) (config : Config) : Execution :=
  let active := config.active
  let cursor := active.control
  match cursor.code with
  | .bind id type (.call target references) next =>
    match references.mapM (fun ref => ref.eval cursor.env) with
    | .error fault => fail config fault cursor.state
    | .ok args => match program[target]? with
      | none => fail config .unsupported cursor.state
      | some function =>
        if function.accepts args cursor.state then
          .suspended ⟨⟨function.returnType, cursor.state.nextId, args,
            ⟨function.body, fun _ => none, cursor.state, []⟩⟩,
            ⟨{ active with control := { cursor with code := next } }, id, type⟩ :: config.callers, config.resources⟩
        else fail config .malformed cursor.state
  | _ =>
    match Control.Machine.step localSemantics active.arguments cursor with
    | .suspended next => .suspended { config with active := { active with control := next } }
    | .finished (.returned value after) => returned config value after
    | .finished (.fault fault after) => fail config fault after
    | .finished (.jumped _ _ _ after) => fail config .malformed after

def start (program : Program) (root : Nat) (args : List Value) (state : State)
    (resources : ResourcePolicy := .history) : Execution :=
  match program[root]? with
  | none => .finished (.error .unsupported) state
  | some function =>
    if function.accepts args state then
      .suspended ⟨⟨function.returnType, state.nextId, args,
        ⟨function.body, fun _ => none, state, []⟩⟩, [], resources⟩
    else .finished (.error .malformed) state

def advance (program : Program) : Nat → Execution → Execution
  | 0, execution => execution
  | _ + 1, .finished result state => .finished result state
  | fuel + 1, .suspended config => advance program fuel (step program config)

def run (program : Program) (fuel root : Nat) (args : List Value) (state : State)
    (resources : ResourcePolicy := .history) : Execution :=
  advance program fuel (start program root args state resources)

/-- Finite reachability is independent of the evaluator's fuel parameter. -/
inductive Steps (program : Program) : Execution → Execution → Prop
  | refl (execution) : Steps program execution execution
  | step (config) {last} : Steps program (step program config) last →
      Steps program (.suspended config) last

def Safe (program : Program) (first : Execution) : Prop :=
  ∀ fault after, Steps program first (.finished (.error fault) after) → fault = .outOfMemory

end Compiler.ZigAir.MemoryCallMachine
