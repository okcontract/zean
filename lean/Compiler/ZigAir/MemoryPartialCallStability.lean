/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryPartialCall

namespace Compiler.ZigAir.MemoryPartialCall
open Memory Control.Machine

theorem Prim.stable (operation : Prim) (budget extra : Nat) (args : List Value)
    (env : MemoryAir.Env) (state : State)
    (complete : (operation.eval budget args env state).1 ≠ .error .pending) :
    operation.eval (budget + extra) args env state = operation.eval budget args env state := by
  cases operation with
  | memory => rfl
  | call target arguments =>
    simp only [Prim.eval] at complete ⊢
    cases read : arguments.mapM (fun ref => ref.eval env) with
    | error => rfl
    | ok values => exact target.stable budget extra values state (by simpa only [read] using complete)

private theorem jump_same (left right : Nat) (target : Nat) (value : Value)
    (env : MemoryAir.Env) (state : State) (frames : List (Frame Ty Prim MemoryAir.Ref)) :
    jump (semantics left) target value env state frames = jump (semantics right) target value env state frames := by
  induction frames with
  | nil => rfl
  | cons frame rest ih => cases frame <;> simp only [jump, ih] <;> rfl

private theorem backedge_same (left right : Nat) (target : Nat)
    (env : MemoryAir.Env) (state : State) (frames : List (Frame Ty Prim MemoryAir.Ref)) :
    backedge (semantics left) target env state frames = backedge (semantics right) target env state frames := by
  induction frames with
  | nil => rfl
  | cons frame rest ih => cases frame <;> simp only [backedge, ih] <;> rfl

def Complete : Execution Ty Prim MemoryAir.Ref Value Signal State → Prop
  | .finished (.fault .pending _) => False
  | _ => True

theorem step_stable (budget extra : Nat) (args : List Value)
    (config : Config Ty Prim MemoryAir.Ref Value State)
    (complete : Complete (step (semantics budget) args config)) :
    step (semantics (budget + extra)) args config = step (semantics budget) args config := by
  obtain ⟨code, env, state, frames⟩ := config
  cases code with
  | bind id type operation next =>
    simp only [step, semantics] at complete ⊢
    have done : (operation.eval budget args env state).1 ≠ .error .pending := by
      intro pending
      cases observed : operation.eval budget args env state with
      | mk result after =>
        simp only [observed] at pending
        subst result
        simp only [observed, Complete] at complete
    rw [operation.stable budget extra args env state done]
    rfl
  | jump target ref =>
    simp only [step, semantics]
    cases ref.eval env <;> simp only [Except.mapError]
    exact jump_same _ _ _ _ _ _ _ |>.symm
  | «repeat» _ target => exact (backedge_same _ _ target env state frames).symm
  | _ => rfl

/-- A completed observation uses no pending primitive. Its complete execution
is unchanged when every callee receives a larger observation budget. -/
theorem advance_stable (budget extra fuel : Nat) (args : List Value)
    (first : Execution Ty Prim MemoryAir.Ref Value Signal State)
    (outcome : Control.Outcome Value Signal State)
    (complete : Complete (.finished outcome))
    (done : advance (semantics budget) args fuel first = .finished outcome) :
    advance (semantics (budget + extra)) args fuel first = .finished outcome := by
  induction fuel generalizing first with
  | zero => exact done
  | succ fuel ih =>
    cases first with
    | finished => exact done
    | suspended config =>
      have nextComplete : Complete (step (semantics budget) args config) := by
        cases stepped : step (semantics budget) args config with
        | suspended => trivial
        | finished reached =>
          have same : reached = outcome := by
            simpa only [advance, stepped, advance_finished, Execution.finished.injEq] using done
          subst reached
          exact complete
      simpa only [advance, step_stable budget extra args config nextComplete] using
        ih (step (semantics budget) args config) done

theorem Program.finished_stable (program : Program) (budget extra : Nat)
    (args : List Value) (state after : State) (result : Except Fault Value)
    (done : program.observe budget args state = .finished result after) :
    program.observe (budget + extra) args state = .finished result after := by
  unfold Program.observe at done ⊢
  split at done
  · rename_i accepted
    rw [ite_eq_left accepted]
    cases observed : run (semantics budget) args budget ⟨program.body, fun _ => none, state, []⟩ with
    | suspended => simp only [observed] at done; contradiction
    | finished outcome =>
      have complete : Complete (.finished outcome) := by
        cases outcome with
        | fault signal state =>
          cases signal with
          | fault => trivial
          | pending => simp only [observed, finish] at done; contradiction
        | _ => trivial
      have same := advance_stable budget extra budget args (.suspended ⟨program.body, fun _ => none, state, []⟩)
        outcome complete observed
      rw [Control.Machine.finished_stable (semantics (budget + extra)) args budget extra _ _ same]
      simpa only [observed] using done
  · rename_i rejected
    simpa only [ite_eq_right rejected] using done

def Program.target (program : Program) : Target where
  observe budget args state := (program.observe budget args state).result
  stable budget extra args state complete := by
    cases observed : program.observe budget args state with
    | pending => simp only [observed, Observation.result] at complete; contradiction
    | finished result after => rw [program.finished_stable budget extra args state after result observed]

end Compiler.ZigAir.MemoryPartialCall
