/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryCallStability

/-! Calls to looping procedures use finite observations. A budget bounds the
control transitions observed in each invocation, not native execution time.
Suspension stops the observation, preserves reached effects and performs no
cleanup. Increasing a budget re-evaluates from the original input; it is not a
native retry. Safety contracts quantify over every budget.

Finite callees can retain the total interpreter. Looping callees execute their
captured body; a contract is never substituted for executable code. -/
namespace Compiler.ZigAir.MemoryPartialCall
open Memory

inductive Signal where
  | fault (reason : Fault)
  | pending
  deriving DecidableEq, Repr

def liftResult (result : Except Fault α × State) : Except Signal α × State :=
  (result.1.mapError Signal.fault, result.2)

inductive Observation where
  | finished (result : Except Fault Value) (state : State)
  | pending (state : State)

def Observation.result : Observation → Except Signal Value × State
  | .finished result state => liftResult (result, state)
  | .pending state => (.error .pending, state)

structure Target where
  observe : Nat → List Value → State → Except Signal Value × State
  stable : ∀ budget extra args state, (observe budget args state).1 ≠ .error .pending →
    observe (budget + extra) args state = observe budget args state

def Target.finite (target : MemoryCall.Target) : Target :=
  ⟨fun _ args state => liftResult (target.execute args state), fun _ _ _ _ _ => rfl⟩

def Target.loop (program : MemoryCall.Program true) : Target where
  observe fuel args state := match program.runFuel fuel args state with
    | .finished result after => liftResult (result, after)
    | .suspended _ _ _ config => (.error .pending, config.state)
  stable fuel extra args state complete := by
    cases observed : program.runFuel fuel args state with
    | suspended => simp only [observed] at complete; contradiction
    | finished result after =>
      rw [program.finished_stable fuel extra args state after result observed]

inductive Prim where
  | memory (operation : MemoryAir.Prim)
  | call (target : Target) (arguments : List MemoryAir.Ref)

def Prim.eval (budget : Nat) (operation : Prim) (args : List Value)
    (env : MemoryAir.Env) (state : State) : Except Signal Value × State :=
  match operation with
  | .memory operation => liftResult (operation.eval args env state)
  | .call target arguments =>
    match arguments.mapM (fun ref => ref.eval env) with
    | .error fault => (.error (.fault fault), state)
    | .ok values => target.observe budget values state

def semantics (budget : Nat) : Control.Semantics Ty Prim MemoryAir.Ref Value Signal State :=
  { hasType := Value.hasType
    truth := MemoryAir.semantics.truth
    evalRef := fun ref env => (ref.eval env).mapError Signal.fault
    evalPrim := Prim.eval budget
    malformed := .fault .malformed }

structure Program where
  parameters : List Ty
  returnType : Ty
  body : Control.Code Ty Prim MemoryAir.Ref true

def Program.accepts (program : Program) (args : List Value) (state : State) : Bool :=
  state.valid && args.length = program.parameters.length &&
    (args.zip program.parameters).all (fun (value, ty) => value.hasType ty)

def finish (returnType : Ty) (mark : Nat) : Control.Outcome Value Signal State → Observation
  | .fault .pending state => .pending state
  | .fault (.fault fault) state => .finished (.error fault) (cleanup mark state)
  | .jumped _ _ _ state => .finished (.error .malformed) (cleanup mark state)
  | .returned value state =>
    let (result, after) := MemoryAir.Program.finish returnType mark (.returned value state)
    .finished result after

def Program.observe (program : Program) (budget : Nat) (args : List Value) (state : State) : Observation :=
  if program.accepts args state then
    match Control.Machine.run (semantics budget) args budget ⟨program.body, fun _ => none, state, []⟩ with
    | .finished outcome => finish program.returnType state.nextId outcome
    | .suspended config => .pending config.state
  else .finished (.error .malformed) state

end Compiler.ZigAir.MemoryPartialCall
