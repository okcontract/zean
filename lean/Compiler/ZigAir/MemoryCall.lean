/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryExecution

/-! Direct calls execute a separately supplied, total callee interpreter.
Generated targets are constructed from captured finite programs, in dependency
order. There is no assumed summary in execution: contracts are used only in
proofs. Recursion and calls to looping callees require a different interpreter
and are not admitted by this interface. -/
namespace Compiler.ZigAir.MemoryCall
open Memory

structure Target where
  execute : List Value → State → Except Fault Value × State

def Target.ofMemory (program : MemoryAir.Program) : Target := ⟨program.run⟩

inductive Prim where
  | memory (operation : MemoryAir.Prim)
  | call (target : Target) (arguments : List MemoryAir.Ref)

def Prim.eval (operation : Prim) (args : List Value) (env : MemoryAir.Env) (state : State) :
    Except Fault Value × State :=
  match operation with
  | .memory operation => operation.eval args env state
  | .call target arguments =>
    match arguments.mapM (fun ref => ref.eval env) with
    | .error fault => (.error fault, state)
    | .ok values => target.execute values state

def semantics : Control.Semantics Ty Prim MemoryAir.Ref Value Fault State :=
  { MemoryAir.semantics with evalPrim := Prim.eval }

structure Program (loops : Bool := false) where
  parameters : List Ty
  returnType : Ty
  body : Control.Code Ty Prim MemoryAir.Ref loops

def Program.accepts (program : Program loops) (args : List Value) (state : State) : Bool :=
  state.valid && args.length = program.parameters.length &&
    (args.zip program.parameters).all (fun (value, ty) => value.hasType ty)

def Program.run (program : Program) (args : List Value) (state : State) : Except Fault Value × State :=
  if program.accepts args state then
    MemoryAir.Program.finish program.returnType state.nextId
      (program.body.eval semantics args (fun _ => none) state)
  else (.error .malformed, state)

def Program.target (program : Program) : Target := ⟨program.run⟩

/-- The finite callees may themselves contain direct calls. Lean definitions
are acyclic, and every invocation keeps its own argument and cleanup boundary. -/
def Program.enableLoops (program : Program) : Program true :=
  { program with body := program.body.enableLoops }

inductive Execution where
  | finished (result : Except Fault Value) (state : State)
  | suspended (returnType : Ty) (mark : Nat) (args : List Value)
      (config : Control.Machine.Config Ty Prim MemoryAir.Ref Value State)

def Execution.resume (fuel : Nat) : Execution → Execution
  | .finished result state => .finished result state
  | .suspended returnType mark args config =>
    match Control.Machine.run semantics args fuel config with
    | .suspended next => .suspended returnType mark args next
    | .finished outcome =>
      let (result, after) := MemoryAir.Program.finish returnType mark outcome
      .finished result after

def Program.runFuel (program : Program true) (fuel : Nat) (args : List Value) (state : State) : Execution :=
  if program.accepts args state then
    Execution.resume fuel (.suspended program.returnType state.nextId args ⟨program.body, fun _ => none, state, []⟩)
  else .finished (.error .malformed) state

end Compiler.ZigAir.MemoryCall
