/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryCallMachineVerification

/-! Structural termination certificates for loop-free call closures. Costs
bound machine transitions, not native time or stack capacity. The proposed
cost table is checked against every included body; unsupported cycles and
loops cannot acquire a certificate by receiving an arbitrary fuel budget. -/
namespace Compiler.ZigAir.MemoryCallMachine.Finite
open Memory

abbrev Bounds := Nat → Option Nat

def primitiveCost (bounds : Bounds) : Prim → Option Nat
  | .memory _ => some 0
  | .call target _ => bounds target

def cost (bounds : Bounds) : Code → Option Nat
  | .bind _ _ operation next => do
      let callee ← primitiveCost bounds operation
      let rest ← cost bounds next
      pure (1 + callee + rest)
  | .branch _ yes no => do
      let yes ← cost bounds yes
      let no ← cost bounds no
      pure (1 + max yes no)
  | .block _ _ body next => do
      let body ← cost bounds body
      let next ← cost bounds next
      pure (1 + body + next)
  | .jump .. | .ret .. => some 1
  | .loop .. | .repeat .. => none

def framesCost (bounds : Bounds) : List (Control.Machine.Frame Ty Prim MemoryAir.Ref) → Option Nat
  | [] => some 0
  | .block _ _ next :: rest => do
      let next ← cost bounds next
      let rest ← framesCost bounds rest
      pure (next + rest)
  | .loop .. :: _ => none

def localCost (bounds : Bounds) (cursor : Local) : Option Nat := do
  let code ← cost bounds cursor.code
  let frames ← framesCost bounds cursor.frames
  pure (code + frames)

def callersCost (bounds : Bounds) : List Caller → Option Nat
  | [] => some 0
  | caller :: rest => do
      let caller ← localCost bounds caller.activation.control
      let rest ← callersCost bounds rest
      pure (caller + rest)

def remaining (bounds : Bounds) : Execution → Option Nat
  | .finished .. => some 0
  | .suspended config => do
      let active ← localCost bounds config.active.control
      let saved ← callersCost bounds config.callers
      pure (active + saved)

def localRemaining (bounds : Bounds) : Control.Machine.Execution Ty Prim MemoryAir.Ref Value Fault State → Option Nat
  | .finished .. => some 0
  | .suspended cursor => localCost bounds cursor

/-- Only entries with a supplied bound need to be loop-free. This permits a
finite helper to live beside looping functions in the same generated table. -/
def Valid (program : Program) (bounds : Bounds) : Prop :=
  ∀ index : Fin program.length, match bounds index with
    | none => True
    | some steps => cost bounds program[index].body = some steps

instance (program : Program) (bounds : Bounds) : Decidable (Valid program bounds) := by
  unfold Valid
  letI (index : Fin program.length) : Decidable (match bounds index with
      | none => True
      | some steps => cost bounds program[index].body = some steps) := by
    cases bounds index <;> infer_instance
  infer_instance

/-- Infer candidates along the emitted acyclic declaration order. The public
termination theorem separately requires the kernel-checked `Valid` predicate. -/
def infer (program : Program) : List (Option Nat) :=
  program.foldl (fun previous function => previous ++ [cost (fun index => previous[index]?.join) function.body]) []

theorem cost_positive (code : Code) (checked : cost bounds code = some steps) : 0 < steps := by
  cases code with
  | bind id type operation next =>
    cases operation <;> simp only [cost, primitiveCost, bind, Option.bind] at checked
    all_goals repeat' (split at checked <;> simp_all)
    all_goals omega
  | branch condition yes no | block id type yes no =>
    simp only [cost, bind, Option.bind] at checked
    split at checked <;> simp_all
    split at checked <;> simp_all
    omega
  | jump | ret => simp [cost] at checked; omega
  | loop | «repeat» => simp [cost] at checked

private theorem local_positive (cursor : Local) (checked : localCost bounds cursor = some steps) : 0 < steps := by
  simp only [localCost, bind, Option.bind] at checked
  split at checked <;> simp_all
  rename_i code found
  have positive := cost_positive cursor.code found
  split at checked <;> simp_all
  omega

private theorem jump_bound (target : Nat) (value : Value) (env : MemoryAir.Env) (state : State)
    (frames : List (Control.Machine.Frame Ty Prim MemoryAir.Ref))
    (checked : framesCost bounds frames = some steps) :
    ∃ after, localRemaining bounds (Control.Machine.jump localSemantics target value env state frames) = some after ∧
      after ≤ steps := by
  induction frames generalizing steps with
  | nil => exact ⟨0, rfl, by simp [framesCost] at checked; omega⟩
  | cons frame rest ih => cases frame with
    | loop => simp [framesCost] at checked
    | block id type next =>
      simp only [framesCost, bind, Option.bind] at checked
      split at checked <;> simp_all
      rename_i nextCost nextFound
      split at checked <;> simp_all
      rename_i restCost restFound
      try simp only [pure, Pure.pure, Option.some.injEq] at checked
      simp only [Control.Machine.jump]
      split
      · split
        · exact ⟨nextCost + restCost, by simp [localRemaining, localCost, nextFound, restFound], by omega⟩
        · exact ⟨0, rfl, by omega⟩
      · obtain ⟨after, found, bound⟩ := ih
        exact ⟨after, found, by omega⟩

private theorem local_step_bound (args : List Value) (cursor : Local)
    (checked : localCost bounds cursor = some steps) :
    ∃ after, localRemaining bounds (Control.Machine.step localSemantics args cursor) = some after ∧ after < steps := by
  have positive := local_positive cursor checked
  obtain ⟨code, env, state, frames⟩ := cursor
  simp only [localCost, bind, Option.bind] at checked
  split at checked <;> simp_all
  rename_i codeCost codeFound
  split at checked <;> simp_all
  rename_i frameCost frameFound
  try simp only [pure, Pure.pure, Option.some.injEq] at checked
  cases code with
  | bind id type operation next =>
    simp only [cost, bind, Option.bind] at codeFound
    split at codeFound <;> simp_all
    rename_i callCost callFound
    split at codeFound <;> simp_all
    rename_i nextCost nextFound
    try simp only [pure, Pure.pure, Option.some.injEq] at codeFound
    cases evaluated : localSemantics.evalPrim operation args env state with
    | mk result after => cases result with
      | error => simp only [Control.Machine.step, evaluated]; exact ⟨0, rfl, positive⟩
      | ok value =>
        simp only [Control.Machine.step, evaluated]
        split
        · exact ⟨nextCost + frameCost, by simp [localRemaining, localCost, nextFound, frameFound], by omega⟩
        · exact ⟨0, rfl, positive⟩
  | branch ref yes no =>
    simp only [cost, bind, Option.bind] at codeFound
    split at codeFound <;> simp_all
    rename_i yesCost yesFound
    split at codeFound <;> simp_all
    rename_i noCost noFound
    try simp only [pure, Pure.pure, Option.some.injEq] at codeFound
    simp only [Control.Machine.step]
    split
    · exact ⟨0, rfl, positive⟩
    · split
      · exact ⟨0, rfl, positive⟩
      · split
        · exact ⟨yesCost + frameCost, by simp [localRemaining, localCost, yesFound, frameFound], by omega⟩
        · exact ⟨noCost + frameCost, by simp [localRemaining, localCost, noFound, frameFound], by omega⟩
  | block id type body next =>
    simp only [cost, bind, Option.bind] at codeFound
    split at codeFound <;> simp_all
    rename_i bodyCost bodyFound
    split at codeFound <;> simp_all
    rename_i nextCost nextFound
    try simp only [pure, Pure.pure, Option.some.injEq] at codeFound
    exact ⟨bodyCost + (nextCost + frameCost), by
      simp [Control.Machine.step, localRemaining, localCost, framesCost, bodyFound, nextFound, frameFound], by omega⟩
  | jump target ref =>
    simp only [Control.Machine.step]
    split
    · exact ⟨0, rfl, positive⟩
    · obtain ⟨after, found, bound⟩ := jump_bound target _ env state frames frameFound
      exact ⟨after, found, by simp [cost] at codeFound; omega⟩
  | ret ref =>
    simp only [Control.Machine.step]
    split <;> exact ⟨0, rfl, positive⟩
  | loop | «repeat» => simp [cost] at codeFound

theorem Valid.lookup (valid : Valid program bounds) (found : program[index]? = some function)
    (bounded : bounds index = some steps) : cost bounds function.body = some steps := by
  obtain ⟨inside, same⟩ := List.getElem?_eq_some_iff.mp found
  have checked := valid ⟨index, inside⟩
  simp only [bounded] at checked
  change cost bounds (program[index]'inside).body = some steps at checked
  simpa only [same] using checked

private theorem unwind_remaining (fault : Fault) (state : State) (callers : List Caller)
    (resources : ResourcePolicy) : remaining bounds (unwind fault state callers resources) = some 0 := by
  induction callers generalizing state with
  | nil => rfl
  | cons caller rest ih => exact ih _

private theorem fail_remaining (config : Config) (fault : Fault) (state : State) :
    remaining bounds (fail config fault state) = some 0 := unwind_remaining _ _ _ _

private theorem returned_bound (config : Config) (value : Value) (state : State)
    (checked : callersCost bounds config.callers = some steps) :
    ∃ after, remaining bounds (returned config value state) = some after ∧ after ≤ steps := by
  unfold returned
  split
  · exact ⟨0, unwind_remaining _ _ _ _, Nat.zero_le _⟩
  · cases saved : config.callers with
    | nil => exact ⟨0, rfl, Nat.zero_le _⟩
    | cons caller rest =>
      simp only
      rw [saved] at checked
      change (do
        let localSteps ← localCost bounds caller.activation.control
        let restSteps ← callersCost bounds rest
        pure (localSteps + restSteps)) = some steps at checked
      obtain ⟨localSteps, localFound, checked⟩ := Option.bind_eq_some_iff.mp checked
      obtain ⟨restSteps, restFound, checked⟩ := Option.bind_eq_some_iff.mp checked
      have total : localSteps + restSteps = steps := Option.some.inj checked
      split
      · refine ⟨localSteps + restSteps, ?_, by omega⟩
        change (do
          let localSteps ← localCost bounds caller.activation.control
          let restSteps ← callersCost bounds rest
          pure (localSteps + restSteps)) = _
        simp [localFound, restFound]
      · exact ⟨0, unwind_remaining _ _ _ _, Nat.zero_le _⟩

private def localResult (config : Config) :
    Control.Machine.Execution Ty Prim MemoryAir.Ref Value Fault State → Execution
  | .suspended cursor => .suspended { config with active := { config.active with control := cursor } }
  | .finished (.returned value after) => returned config value after
  | .finished (.fault fault after) => fail config fault after
  | .finished (.jumped _ _ _ after) => fail config .malformed after

private theorem ordinary_step (program : Program) (config : Config)
    (ordinary : ∀ id type target refs next, config.active.control.code ≠ .bind id type (.call target refs) next) :
    step program config = localResult config (Control.Machine.step localSemantics config.active.arguments config.active.control) := by
  obtain ⟨⟨type, mark, args, ⟨code, env, state, frames⟩⟩, callers, resources⟩ := config
  cases code with
  | bind id type operation next => cases operation with
    | memory => rfl
    | call target refs => exact False.elim (ordinary id type target refs next rfl)
  | _ => rfl

private theorem step_bound (valid : Valid program bounds) (config : Config)
    (checked : remaining bounds (.suspended config) = some steps) :
    ∃ after, remaining bounds (step program config) = some after ∧ after < steps := by
  simp only [remaining, bind, Option.bind] at checked
  split at checked <;> simp_all
  rename_i localSteps localFound
  split at checked <;> simp_all
  rename_i savedSteps savedFound
  have positive := local_positive config.active.control localFound
  have ordinary (notCall : ∀ id type target refs next,
      config.active.control.code ≠ .bind id type (.call target refs) next) :
      ∃ after, remaining bounds (step program config) = some after ∧ after < steps := by
    rw [ordinary_step program config notCall]
    obtain ⟨after, found, bound⟩ := local_step_bound config.active.arguments config.active.control localFound
    cases reached : Control.Machine.step localSemantics config.active.arguments config.active.control with
    | suspended cursor =>
      rw [reached] at found
      change localCost bounds cursor = some after at found
      exact ⟨after + savedSteps, by simp [localResult, remaining, found, savedFound], by omega⟩
    | finished outcome => cases outcome with
      | returned value state =>
        obtain ⟨after, found, bound⟩ := returned_bound config value state savedFound
        exact ⟨after, found, by omega⟩
      | fault => exact ⟨0, fail_remaining _ _ _, by omega⟩
      | jumped => exact ⟨0, fail_remaining _ _ _, by omega⟩
  obtain ⟨⟨type, mark, args, ⟨code, env, state, frames⟩⟩, saved, resources⟩ := config
  cases code with
  | bind id ty operation next => cases operation with
    | memory => exact ordinary (by intros; simp)
    | call target refs =>
      obtain ⟨bodySteps, bodyFound, localFound⟩ := Option.bind_eq_some_iff.mp localFound
      obtain ⟨frameSteps, frameFound, localFound⟩ := Option.bind_eq_some_iff.mp localFound
      have localTotal : bodySteps + frameSteps = localSteps := Option.some.inj localFound
      change (do
        let callee ← bounds target
        let rest ← cost bounds next
        pure (1 + callee + rest)) = some bodySteps at bodyFound
      obtain ⟨calleeSteps, calleeFound, bodyFound⟩ := Option.bind_eq_some_iff.mp bodyFound
      obtain ⟨nextSteps, nextFound, bodyFound⟩ := Option.bind_eq_some_iff.mp bodyFound
      have bodyTotal : 1 + calleeSteps + nextSteps = bodySteps := Option.some.inj bodyFound
      cases read : refs.mapM (fun ref => ref.eval env) with
      | error fault =>
        simp only [step, read]
        exact ⟨0, fail_remaining _ _ _, by omega⟩
      | ok values =>
        simp only [step, read]
        cases found : program[target]? with
        | none =>
          simp only
          exact ⟨0, fail_remaining _ _ _, by omega⟩
        | some function =>
          simp only
          have callee := valid.lookup found calleeFound
          split
          · refine ⟨calleeSteps + (nextSteps + frameSteps + savedSteps), ?_, by omega⟩
            simp [remaining, localCost, callersCost, framesCost, callee, nextFound, frameFound, savedFound]
          · exact ⟨0, fail_remaining _ _ _, by omega⟩
  | _ => exact ordinary (by intros; simp)

theorem terminates_of_remaining (valid : Valid program bounds) (execution : Execution)
    (checked : remaining bounds execution = some steps) : Terminates program execution := by
  induction steps using Nat.strongRecOn generalizing execution with
  | ind steps ih =>
    cases execution with
    | finished result state => exact ⟨result, state, .refl _⟩
    | suspended config =>
      obtain ⟨after, found, bound⟩ := step_bound valid config checked
      obtain ⟨result, state, reached⟩ := ih after bound (step program config) found
      exact ⟨result, state, .step config reached⟩

/-- A valid structural certificate gives termination for every input and
state, with ordinary failure distinguished from successful completion. -/
theorem terminates (valid : Valid program bounds) (root : Nat) (bounded : bounds root = some steps)
    (args : List Value) (state : State) (resources : ResourcePolicy := .history) :
    Terminates program (start program root args state resources) := by
  unfold start
  cases found : program[root]? with
  | none =>
    simp only
    exact ⟨_, _, .refl _⟩
  | some function =>
    simp only
    have body := valid.lookup found bounded
    split
    · apply terminates_of_remaining valid (steps := steps)
      simp [remaining, localCost, framesCost, callersCost, body]
    · exact ⟨_, _, .refl _⟩

end Compiler.ZigAir.MemoryCallMachine.Finite
