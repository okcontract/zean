/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryCallMachineProofs
import Compiler.ZigAir.MemoryExecutionProofs

/-! Exact adapter for the existing finite/loop memory interpreter. This is an
execution equivalence for arbitrary program data, including malformed programs
and faults; it does not depend on any tutorial shape or instruction numbers. -/
namespace Compiler.ZigAir.MemoryCallMachine
open Memory

def embedCode : Control.Code Ty MemoryAir.Prim MemoryAir.Ref loops →
    Control.Code Ty Prim MemoryAir.Ref loops
  | .bind id type operation next => .bind id type (.memory operation) (embedCode next)
  | .branch ref yes no => .branch ref (embedCode yes) (embedCode no)
  | .block id type body next => .block id type (embedCode body) (embedCode next)
  | .jump id ref => .jump id ref
  | .ret ref => .ret ref
  | .loop enabled id body => .loop enabled id (embedCode body)
  | .repeat enabled id => .repeat enabled id

def embedFrame : Control.Machine.Frame Ty MemoryAir.Prim MemoryAir.Ref →
    Control.Machine.Frame Ty Prim MemoryAir.Ref
  | .block id type next => .block id type (embedCode next)
  | .loop id body => .loop id (embedCode body)

def embedLocal (config : Control.Machine.Config Ty MemoryAir.Prim MemoryAir.Ref Value State) : Local :=
  ⟨embedCode config.code, config.env, config.state, config.frames.map embedFrame⟩

def embedLocalExecution : Control.Machine.Execution Ty MemoryAir.Prim MemoryAir.Ref Value Fault State →
    Control.Machine.Execution Ty Prim MemoryAir.Ref Value Fault State
  | .finished outcome => .finished outcome
  | .suspended config => .suspended (embedLocal config)

private theorem embed_jump (id : Nat) (value : Value) (env : MemoryAir.Env) (state : State)
    (frames : List (Control.Machine.Frame Ty MemoryAir.Prim MemoryAir.Ref)) :
    Control.Machine.jump localSemantics id value env state (frames.map embedFrame) =
      embedLocalExecution (Control.Machine.jump MemoryAir.semantics id value env state frames) := by
  induction frames with
  | nil => rfl
  | cons frame rest ih =>
    cases frame <;> simp only [List.map_cons, embedFrame, Control.Machine.jump, localSemantics, MemoryAir.semantics]
    all_goals split
    all_goals first | exact ih | rfl | (split <;> simp_all only [↓reduceIte] <;> rfl)

private theorem embed_backedge (id : Nat) (env : MemoryAir.Env) (state : State)
    (frames : List (Control.Machine.Frame Ty MemoryAir.Prim MemoryAir.Ref)) :
    Control.Machine.backedge localSemantics id env state (frames.map embedFrame) =
      embedLocalExecution (Control.Machine.backedge MemoryAir.semantics id env state frames) := by
  induction frames with
  | nil => rfl
  | cons frame rest ih =>
    cases frame <;> simp only [List.map_cons, embedFrame, Control.Machine.backedge]
    all_goals split
    all_goals first | exact ih | rfl

theorem embed_local_step (args : List Value)
    (config : Control.Machine.Config Ty MemoryAir.Prim MemoryAir.Ref Value State) :
    Control.Machine.step localSemantics args (embedLocal config) =
      embedLocalExecution (Control.Machine.step MemoryAir.semantics args config) := by
  obtain ⟨code, env, state, frames⟩ := config
  cases code with
  | bind id type operation next =>
    simp only [embedLocal, embedCode, Control.Machine.step, localSemantics, MemoryAir.semantics]
    cases operation.eval args env state with
    | mk result after =>
      cases result with
      | error => rfl
      | ok value =>
        dsimp only
        by_cases typed : value.hasType type = true <;>
          simp only [typed, ↓reduceIte] <;> rfl
  | branch ref yes no =>
    simp only [embedLocal, embedCode, Control.Machine.step, localSemantics, MemoryAir.semantics]
    cases ref.eval env with
    | error => rfl
    | ok value => cases value with
      | scalar scalar => cases scalar <;> first | rfl | (rename_i flag; cases flag <;> rfl)
      | _ => rfl
  | block => rfl
  | loop => rfl
  | «repeat» _ id => exact embed_backedge id env state frames
  | jump id ref =>
    simp only [embedLocal, embedCode, Control.Machine.step, localSemantics, MemoryAir.semantics]
    cases ref.eval env with
    | error => rfl
    | ok value => exact embed_jump id value env state frames
  | ret ref =>
    simp only [embedLocal, embedCode, Control.Machine.step, localSemantics, MemoryAir.semantics]
    cases ref.eval env <;> rfl

def embedInvocation : MemoryAir.Invocation → Execution
  | .finished result state => .finished result state
  | .suspended type mark args config => .suspended ⟨⟨type, mark, args, embedLocal config⟩, [], .history⟩

def Function.ofMemory (program : MemoryAir.Program true) : Function :=
  ⟨program.parameters, program.returnType, embedCode program.body⟩

theorem embed_step (program : Program) (type : Ty) (mark : Nat) (args : List Value)
    (config : Control.Machine.Config Ty MemoryAir.Prim MemoryAir.Ref Value State) :
    step program ⟨⟨type, mark, args, embedLocal config⟩, [], .history⟩ =
      embedInvocation ((MemoryAir.Invocation.suspended type mark args config).resume 1) := by
  have ordinary : step program ⟨⟨type, mark, args, embedLocal config⟩, [], .history⟩ =
      match Control.Machine.step localSemantics args (embedLocal config) with
      | .suspended next => .suspended ⟨⟨type, mark, args, next⟩, [], .history⟩
      | .finished (.returned value after) => returned ⟨⟨type, mark, args, embedLocal config⟩, [], .history⟩ value after
      | .finished (.fault fault after) => fail ⟨⟨type, mark, args, embedLocal config⟩, [], .history⟩ fault after
      | .finished (.jumped _ _ _ after) => fail ⟨⟨type, mark, args, embedLocal config⟩, [], .history⟩ .malformed after := by
    obtain ⟨code, env, state, frames⟩ := config
    cases code <;> rfl
  rw [ordinary, embed_local_step]
  simp only [MemoryAir.Invocation.resume, Control.Machine.run, Control.Machine.advance]
  cases Control.Machine.step MemoryAir.semantics args config with
  | suspended => rfl
  | finished outcome =>
    cases outcome with
    | fault => rfl
    | jumped => rfl
    | returned value after =>
      by_cases typed : value.hasType type = true <;>
        simp [embedLocalExecution, returned, MemoryAir.Invocation.finish,
          MemoryAir.Program.finish, typed, unwind, embedInvocation, ResourcePolicy.cleanup]

/-- Fuel splitting, cleanup, faults and suspension agree exactly for all
existing intraprocedural memory programs. No validity premise is necessary. -/
theorem embed_resume (program : Program) (fuel : Nat) (invocation : MemoryAir.Invocation) :
    advance program fuel (embedInvocation invocation) = embedInvocation (invocation.resume fuel) := by
  induction fuel generalizing invocation with
  | zero => rw [MemoryAir.Invocation.resume_zero]; rfl
  | succ fuel ih =>
    cases invocation with
    | finished => simp [embedInvocation, advance_finished, MemoryAir.Invocation.resume_finished]
    | suspended type mark args config =>
      change advance program fuel (step program ⟨⟨type, mark, args, embedLocal config⟩, [], .history⟩) = _
      rw [embed_step, ih]
      rw [← MemoryAir.Invocation.resume_add]
      congr 2
      omega

theorem ofMemory_run (program : MemoryAir.Program true) (fuel : Nat)
    (args : List Value) (state : State) :
    run [Function.ofMemory program] fuel 0 args state =
      embedInvocation (program.runFuel fuel args state) := by
  have starts : start [Function.ofMemory program] 0 args state =
      embedInvocation (program.start args state) := by
    have accepts : (Function.ofMemory program).accepts args state = program.accepts args state := rfl
    simp only [start, List.getElem?_cons_zero, accepts, MemoryAir.Program.start]
    by_cases accepted : program.accepts args state = true <;>
      simp only [accepted, ↓reduceIte] <;> rfl
  rw [run, starts, embed_resume]
  rfl

/-- A memory-only function has the same execution in any containing table.
Other entries cannot affect its behavior because its body has no calls. -/
theorem ofMemory_run_at (table : Program) (root : Nat) (program : MemoryAir.Program true)
    (found : table[root]? = some (Function.ofMemory program)) (fuel : Nat)
    (args : List Value) (state : State) :
    run table fuel root args state = embedInvocation (program.runFuel fuel args state) := by
  have starts : start table root args state = embedInvocation (program.start args state) := by
    have accepts : (Function.ofMemory program).accepts args state = program.accepts args state := rfl
    simp only [start, found, accepts, MemoryAir.Program.start]
    by_cases accepted : program.accepts args state = true <;>
      simp only [accepted, ↓reduceIte] <;> rfl
  rw [run, starts, embed_resume]
  rfl

end Compiler.ZigAir.MemoryCallMachine
