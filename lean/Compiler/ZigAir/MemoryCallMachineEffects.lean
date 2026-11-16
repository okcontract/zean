/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryCallMachineProofs
import Compiler.ZigAir.MemoryShapePreservation
import Compiler.ZigAir.MemoryRootShape

/-! Storage metadata preservation for actual call-stack execution, including
faults and suspended prefixes. Contents, initialization and fault exclusion
remain separate contracts. No callee effect is assumed by this theorem. -/
namespace Compiler.ZigAir.MemoryCallMachine
open Memory

private def Storage (heap : Heap) (state : State) : Prop :=
  state.valid = true ∧ heap.RetainsShape state.heap

private def Protects (heap : Heap) (mark : Nat) : Prop :=
  ∀ id cell, heap.lookup id = some cell → id < mark

private def Framed (heap : Heap) : Execution → Prop
  | .finished _ state => Storage heap state
  | .suspended config => Storage heap config.active.control.state ∧
      Protects heap config.active.mark ∧
      ∀ caller ∈ config.callers, Protects heap caller.activation.mark

private theorem Storage.protects (kept : Storage heap state) : Protects heap state.nextId := by
  intro id cell found
  obtain ⟨updated, lookup, _⟩ := kept.2 id cell found
  exact (valid_lookup state id updated kept.1 lookup).1

private theorem Storage.cleanup (resources : ResourcePolicy) (mark : Nat)
    (guarded : Protects heap mark) (kept : Storage heap state) :
    Storage heap (resources.cleanup mark state) := by
  have valid : (resources.cleanup mark state).valid = true := by
    cases resources with
    | history => exact cleanup_preserves_valid mark state kept.1
    | reuse => exact cleanupReusing_valid state mark kept.1
  refine ⟨valid, ?_⟩
  intro id cell found
  obtain ⟨updated, lookup, shape⟩ := kept.2 id cell found
  refine ⟨updated, ?_, shape⟩
  have older := (cleanup_lookup_older state mark id (guarded id cell found)).trans lookup
  cases resources <;> exact older

private theorem unwind_framed (fault : Fault) (resources : ResourcePolicy) (callers : List Caller)
    (state : State) (kept : Storage heap state)
    (guarded : ∀ caller ∈ callers, Protects heap caller.activation.mark) :
    Framed heap (unwind fault state callers resources) := by
  induction callers generalizing state with
  | nil => exact kept
  | cons caller rest ih =>
    exact ih _ (kept.cleanup resources _ (guarded caller (by simp)))
      (fun next member => guarded next (by simp [member]))

private theorem fail_framed (config : Config) (fault : Fault) (state : State)
    (kept : Storage heap state) (active : Protects heap config.active.mark)
    (callers : ∀ caller ∈ config.callers, Protects heap caller.activation.mark) :
    Framed heap (fail config fault state) :=
  unwind_framed fault config.resources config.callers _ (kept.cleanup config.resources _ active) callers

private theorem returned_framed (config : Config) (value : Value) (state : State)
    (kept : Storage heap state) (active : Protects heap config.active.mark)
    (callers : ∀ caller ∈ config.callers, Protects heap caller.activation.mark) :
    Framed heap (returned config value state) := by
  have cleaned := kept.cleanup config.resources _ active
  unfold returned
  split
  · exact unwind_framed _ _ _ _ cleaned callers
  · cases saved : config.callers with
    | nil => exact cleaned
    | cons caller rest =>
      simp only
      have first : Protects heap caller.activation.mark := callers caller (by simp [saved])
      have later : ∀ next ∈ rest, Protects heap next.activation.mark :=
        fun next member => callers next (by simp [saved, member])
      split
      · exact ⟨cleaned, first, later⟩
      · exact unwind_framed _ _ _ _ (cleaned.cleanup config.resources _ first) later

private theorem local_storage (args : List Value) (cursor : Local)
    (kept : Storage heap cursor.state) :
    Storage heap (Control.Machine.step localSemantics args cursor).state := by
  apply Control.Machine.step_preserves localSemantics args (Storage heap) _ cursor kept
  intro operation args env state before
  cases operation with
  | memory operation => exact ⟨operation.preserves_valid args env state before.1,
      before.2.trans (operation.retains_shape args env state before.1)⟩
  | call => exact before

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

private theorem step_framed (program : Program) (config : Config)
    (framed : Framed heap (.suspended config)) : Framed heap (step program config) := by
  obtain ⟨kept, active, callers⟩ := framed
  have ordinary (notCall : ∀ id type target refs next,
      config.active.control.code ≠ .bind id type (.call target refs) next) :
      Framed heap (step program config) := by
    rw [ordinary_step program config notCall]
    have after := local_storage config.active.arguments config.active.control kept
    cases reached : Control.Machine.step localSemantics config.active.arguments config.active.control with
    | suspended cursor =>
      rw [reached] at after
      exact ⟨after, active, callers⟩
    | finished outcome =>
      rw [reached] at after
      cases outcome with
      | returned => exact returned_framed _ _ _ after active callers
      | fault => exact fail_framed _ _ _ after active callers
      | jumped => exact fail_framed _ _ _ after active callers
  obtain ⟨⟨type, mark, args, ⟨code, env, state, frames⟩⟩, saved, resources⟩ := config
  cases code with
  | bind id ty operation next => cases operation with
    | memory => exact ordinary (by intros; simp)
    | call target refs =>
      simp only [step]
      split
      · exact fail_framed _ _ _ kept active callers
      · split
        · exact fail_framed _ _ _ kept active callers
        · split
          · refine ⟨kept, kept.protects, ?_⟩
            intro caller member
            rcases List.mem_cons.mp member with same | later
            · subst caller; exact active
            · exact callers caller later
          · exact fail_framed _ _ _ kept active callers
  | _ => exact ordinary (by intros; simp)

/-- Every reachable prefix retains the original allocations' identities,
types, extents and permissions. It may change their contents or return a fault. -/
theorem effects (program : Program) (root : Nat) (args : List Value) (initial : State)
    (valid : initial.valid = true) (fuel : Nat) (resources : ResourcePolicy := .history) :
    (run program fuel root args initial resources).state.valid = true ∧
      initial.heap.RetainsShape (run program fuel root args initial resources).state.heap := by
  have kept : Storage initial.heap initial := ⟨valid, Heap.RetainsShape.refl _⟩
  have begins : Framed initial.heap (start program root args initial resources) := by
    unfold start
    split
    · exact kept
    · split
      · exact ⟨kept, kept.protects, by simp⟩
      · exact kept
  have framed := (advance_steps program fuel _).preserves program (Framed initial.heap)
    (step_framed program) begins
  change Framed initial.heap (run program fuel root args initial resources) at framed
  cases reached : run program fuel root args initial resources with
  | finished => rw [reached] at framed; exact framed
  | suspended => rw [reached] at framed; exact framed.1

/-- Caller-owned writable root storage remains available at every observation,
including suspension and faults, under either resource policy. -/
theorem rootWritable_retained (program : Program) (root : Nat) (args : List Value)
    (initial : State) (valid : initial.valid = true) (cap : RootWritable initial owner objectId)
    (fuel : Nat) (resources : ResourcePolicy := .history) :
    RootWritable (run program fuel root args initial resources).state owner objectId :=
  cap.retained (effects program root args initial valid fuel resources).2

end Compiler.ZigAir.MemoryCallMachine
