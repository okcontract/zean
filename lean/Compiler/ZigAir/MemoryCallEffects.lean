/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryCall
import Compiler.ZigAir.MachineCoveredState
import Compiler.ZigAir.MachineRefinement
import Compiler.ZigAir.MemoryShapePreservation

namespace Compiler.ZigAir.MemoryCall
open Memory Control.Machine

/-- Reached effects may change contents, but keep all caller allocation
identities, types, extents and permissions. This law does not license reads. -/
def Target.PreservesStorage (target : Target) : Prop :=
  ∀ args state, state.valid = true →
    (target.execute args state).2.valid = true ∧
      state.heap.RetainsShape (target.execute args state).2.heap

def Prim.requirements : Prim → Prop
  | .memory _ => True
  | .call target _ => target.PreservesStorage

theorem Prim.effects (operation : Prim) (required : operation.requirements)
    (args : List Value) (env : MemoryAir.Env) (state : State) (valid : state.valid = true) :
    (operation.eval args env state).2.valid = true ∧
      state.heap.RetainsShape (operation.eval args env state).2.heap := by
  cases operation with
  | memory operation => exact ⟨operation.preserves_valid args env state valid, operation.retains_shape args env state valid⟩
  | call target arguments =>
    simp only [Prim.eval]
    cases arguments.mapM (fun ref => ref.eval env) with
    | error => exact ⟨valid, Heap.RetainsShape.refl _⟩
    | ok values => exact required values state valid

def Execution.state : Execution → State
  | .finished _ state => state
  | .suspended _ _ _ config => config.state

theorem finish_effects (type : Ty) (initial : State) (outcome : Control.Outcome Value Fault State)
    (valid : initial.valid = true) (after : outcome.state.valid = true)
    (shape : initial.heap.RetainsShape outcome.state.heap) :
    (MemoryAir.Program.finish type initial.nextId outcome).2.valid = true ∧
      initial.heap.RetainsShape (MemoryAir.Program.finish type initial.nextId outcome).2.heap := by
  have checked := cleanup_preserves_valid initial.nextId outcome.state after
  have retained := cleanup_retains_shape initial outcome.state valid shape
  cases outcome <;> simp only [MemoryAir.Program.finish, Control.Outcome.state] at *
  all_goals exact ⟨checked, retained⟩

theorem Program.effects (program : Program true)
    (required : program.body.Covered (fun site => site.2.2.requirements))
    (args : List Value) (state : State) (valid : state.valid = true) (fuel : Nat) :
    (program.runFuel fuel args state).state.valid = true ∧
      state.heap.RetainsShape (program.runFuel fuel args state).state.heap := by
  have checked := advance_preserves_covered semantics args (fun site => site.2.2.requirements)
    (fun after => after.valid = true ∧ state.heap.RetainsShape after.heap)
    (fun site required env before initial =>
      let kept := site.2.2.effects required args env before initial.1
      ⟨kept.1, initial.2.trans kept.2⟩) fuel
    (.suspended ⟨program.body, fun _ => none, state, []⟩) ⟨required, by simp⟩ ⟨valid, Heap.RetainsShape.refl _⟩
  change (Control.Machine.run semantics args fuel ⟨program.body, fun _ => none, state, []⟩).state.valid = true ∧
    state.heap.RetainsShape (Control.Machine.run semantics args fuel ⟨program.body, fun _ => none, state, []⟩).state.heap at checked
  unfold Program.runFuel
  split
  · simp only [Execution.resume]
    cases observed : Control.Machine.run semantics args fuel ⟨program.body, fun _ => none, state, []⟩ with
    | suspended =>
      simpa only [observed, Control.Machine.Execution.state, Execution.state] using checked
    | finished outcome =>
      have effects : outcome.state.valid = true ∧ state.heap.RetainsShape outcome.state.heap := by
        simpa only [observed, Control.Machine.Execution.state] using checked
      simpa only [observed, Execution.state] using finish_effects program.returnType state outcome valid effects.1 effects.2
  · exact ⟨valid, Heap.RetainsShape.refl _⟩

private theorem enabled_bindings (code : Control.Code Ty Prim MemoryAir.Ref) :
    code.enableLoops.bindings = code.bindings := by
  induction code <;> simp_all [Control.Code.enableLoops, Control.Code.bindings]
  all_goals contradiction

theorem Program.target_effects (program : Program)
    (required : program.body.Covered (fun site => site.2.2.requirements)) : program.target.PreservesStorage := by
  intro args state valid
  obtain ⟨fuel, ran⟩ := finite_run semantics args program.body (fun _ => none) state
  have covered : program.enableLoops.body.Covered (fun site => site.2.2.requirements) := by
    simpa only [Control.Code.Covered, Program.enableLoops, enabled_bindings] using required
  have checked := program.enableLoops.effects covered args state valid fuel
  simp only [Program.target, Program.run]
  unfold Program.runFuel at checked
  split at checked
  · rename_i accepted
    change program.accepts args state = true at accepted
    rw [ite_eq_left accepted]
    simpa only [Program.enableLoops, Execution.resume, ran, Execution.state] using checked
  · rename_i rejected
    change ¬program.accepts args state = true at rejected
    rw [ite_eq_right rejected]
    exact ⟨valid, Heap.RetainsShape.refl _⟩

end Compiler.ZigAir.MemoryCall
