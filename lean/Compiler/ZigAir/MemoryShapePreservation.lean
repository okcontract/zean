/-
// Copyright (C) 2026 OKcontract Pte. Ltd.
// SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryAllocationShape
import Compiler.ZigAir.MemoryInvalidation
import Compiler.ZigAir.MemoryMachine
import Compiler.ZigAir.MachineObservations

namespace Compiler.ZigAir.MemoryAir
open Memory Control.Machine

private theorem bind_success {α β : Type} (first : Except Fault α) (next : α → Except Fault β)
    (result : β) (success : first >>= next = .ok result) :
    ∃ value, first = .ok value ∧ next value = .ok result := by
  cases first <;> simp_all [bind, Except.bind]

private theorem byte_retains_shape (copied : ByteRange.copyByte state source target index = .ok after) :
    state.heap.RetainsShape after.heap := by
  rcases ByteRange.copyByte_success copied with ⟨bits, _, written⟩ | ⟨_, forgotten⟩
  · exact store_retains_shape _ _ _ _ written
  · exact invalidate_retains_shape _ _ _ _ _ forgotten

theorem ByteRange.copyLoop_retains_shape (state : State) (source target : Address) (index count : Nat) :
    state.heap.RetainsShape (ByteRange.copyLoop state source target index count).2.heap :=
  Memory.ByteRange.copyLoop_preserves (fun after => state.heap.RetainsShape after.heap)
    (fun prior copied => prior.trans (byte_retains_shape copied)) state source target index count (.refl _)

theorem ByteRange.copy_retains_shape (state : State) (target source : Value) :
    state.heap.RetainsShape (ByteRange.copy state target source).2.heap :=
  Memory.ByteRange.copy_preserves (fun after => state.heap.RetainsShape after.heap)
    (fun prior copied => prior.trans (byte_retains_shape copied)) state target source (.refl _)

theorem ByteRange.copyBackward_retains_shape (state : State) (source target : Address) (count : Nat) :
    state.heap.RetainsShape (ByteRange.copyBackward state source target count).2.heap :=
  Memory.ByteRange.copyBackward_preserves (fun after => state.heap.RetainsShape after.heap)
    (fun prior copied => prior.trans (byte_retains_shape copied)) state source target count (.refl _)

theorem ByteRange.move_retains_shape (state : State) (target source : Value) :
    state.heap.RetainsShape (ByteRange.move state target source).2.heap :=
  Memory.ByteRange.move_preserves (fun after => state.heap.RetainsShape after.heap)
    (fun prior copied => prior.trans (byte_retains_shape copied)) state target source (.refl _)

private theorem byte_preserves_counters {initial : State} (copied : ByteRange.copyByte state source target index = .ok after)
    (prior : state.nextId = initial.nextId ∧ state.nextAddress = initial.nextAddress) :
    after.nextId = initial.nextId ∧ after.nextAddress = initial.nextAddress := by
  have same : after.nextId = state.nextId ∧ after.nextAddress = state.nextAddress := by
    rcases ByteRange.copyByte_success copied with ⟨bits, _, stored⟩ | ⟨_, forgotten⟩
    · exact store_keeps_counters _ _ _ _ stored
    · exact ⟨(invalidate_frame _ _ _ _ _ forgotten).1, (invalidate_frame _ _ _ _ _ forgotten).2.1⟩
  exact ⟨same.1.trans prior.1, same.2.trans prior.2⟩

/-- Both counters are unchanged, including when an undefined source erases
destination bytes or the copy stops at a fault after writing a prefix. -/
theorem ByteRange.copy_keeps_counters (state : State) (target source : Value) :
    let after := (ByteRange.copy state target source).2
    after.nextId = state.nextId ∧ after.nextAddress = state.nextAddress :=
  Memory.ByteRange.copy_preserves (fun after => after.nextId = state.nextId ∧ after.nextAddress = state.nextAddress)
    (fun prior copied => byte_preserves_counters copied prior) state target source ⟨rfl, rfl⟩

/-- Moving overlapping storage needs neither a fresh allocation nor a new
modeled address. The invariant applies to both copy directions. -/
theorem ByteRange.move_keeps_counters (state : State) (target source : Value) :
    let after := (ByteRange.move state target source).2
    after.nextId = state.nextId ∧ after.nextAddress = state.nextAddress :=
  Memory.ByteRange.move_preserves (fun after => after.nextId = state.nextId ∧ after.nextAddress = state.nextAddress)
    (fun prior copied => byte_preserves_counters copied prior) state target source ⟨rfl, rfl⟩

theorem Prim.transition_retains_shape (prim : Prim) (args : List Value) (env : Env)
    (state : State) (value : Value) (after : State) (initial : state.valid = true)
    (success : prim.transition args env state = .ok (value, after)) :
    state.heap.RetainsShape after.heap := by
  cases prim with
  | alloc child => exact allocate_retains_shape state child value after initial success
  | store pointer operand =>
    rcases bind_success (pointer.eval env) _ _ success with ⟨p, _, rest⟩
    rcases bind_success (operand.eval env) _ _ rest with ⟨v, _, rest⟩
    rcases bind_success (Memory.store state p v) _ _ rest with ⟨stored, written, same⟩
    cases (Prod.mk.inj (Except.ok.inj same)).2
    exact store_retains_shape state p v after written
  | wordByteStore order pointer operand =>
    rcases bind_success (pointer.eval env) _ _ success with ⟨p, _, rest⟩
    rcases bind_success (operand.eval env) _ _ rest with ⟨v, _, rest⟩
    rcases bind_success (ByteAccess.write order state p v) _ _ rest with ⟨stored, written, same⟩
    cases (Prod.mk.inj (Except.ok.inj same)).2
    obtain ⟨wordPointer, wordValue, effect⟩ := ByteAccess.write_store order state after p v written
    exact store_retains_shape state wordPointer wordValue after effect
  | _ =>
    simp only [Prim.transition, bind, Except.bind] at success
    repeat' split at success
    all_goals first
      | contradiction
      | (cases (Prod.mk.inj (Except.ok.inj success)).2; exact Heap.RetainsShape.refl _)

/-- Includes bulk transfer faults after a completed prefix of writes. -/
theorem Prim.retains_shape (prim : Prim) (args : List Value) (env : Env)
    (state : State) (initial : state.valid = true) : state.heap.RetainsShape (prim.eval args env state).2.heap := by
  by_cases bulk : ∃ target source, prim = .copyBytes target source
  · obtain ⟨target, source, rfl⟩ := bulk
    simp only [Prim.eval, evalByteTransfer]
    cases target.eval env <;> cases source.eval env <;> simp only
    all_goals first | exact Heap.RetainsShape.refl _ | exact ByteRange.copy_retains_shape _ _ _
  by_cases moving : ∃ target source, prim = .moveBytes target source
  · obtain ⟨target, source, rfl⟩ := moving
    simp only [Prim.eval, evalByteTransfer]
    cases target.eval env <;> cases source.eval env <;> simp only
    all_goals first | exact Heap.RetainsShape.refl _ | exact ByteRange.move_retains_shape _ _ _
  have atomic : ∀ target source, prim ≠ .copyBytes target source := by simpa using bulk
  have atomicMove : ∀ target source, prim ≠ .moveBytes target source := by simpa using moving
  have equation : prim.eval args env state =
      match prim.transition args env state with
      | .ok (value, after) => (.ok value, after)
      | .error fault => (.error fault, state) := by
    cases prim <;> first | rfl | exact False.elim (atomic _ _ rfl) | exact False.elim (atomicMove _ _ rfl)
  rw [equation]
  cases step : prim.transition args env state with
  | error fault => exact Heap.RetainsShape.refl state.heap
  | ok result =>
    rcases result with ⟨value, after⟩
    exact prim.transition_retains_shape args env state value after initial step

theorem machine_steps_retain_shape (args : List Value)
    (first last : Execution Ty Prim Ref Value Fault State)
    (path : Steps semantics args first last) (initial : first.state.valid = true) :
    first.state.heap.RetainsShape last.state.heap := by
  have result := path.preserves semantics args
    (fun state => state.valid = true ∧ first.state.heap.RetainsShape state.heap)
    (fun prim args env state h => ⟨prim.preserves_valid args env state h.1,
      h.2.trans (prim.retains_shape args env state h.1)⟩)
    ⟨initial, Heap.RetainsShape.refl _⟩
  exact result.2

theorem observed_retains_shape (args : List Value) (fuel : Nat) (config : Config Ty Prim Ref Value State)
    (initial : config.state.valid = true) (event : Observation Ty Prim Value State)
    (present : event ∈ (trace semantics args fuel (.suspended config)).1) :
    config.state.heap.RetainsShape event.state.heap := by
  obtain ⟨next, reached, recorded⟩ := trace_reachable semantics args fuel (.suspended config) event present
  have retained := machine_steps_retain_shape args _ _ reached initial
  cases code : next.code <;> simp_all [observe]
  cases recorded
  exact retained

/-- The invocation's original allocation mark also protects the caller's stack
cells on every completed or suspended path; fresh stack cells may be removed. -/
theorem machine_steps_cleanup_retain_shape (args : List Value)
    (first last : Execution Ty Prim Ref Value Fault State)
    (path : Steps semantics args first last) (initial : first.state.valid = true) :
    first.state.heap.RetainsShape (cleanup first.state.nextId last.state).heap :=
  cleanup_retains_shape first.state last.state initial (machine_steps_retain_shape args first last path initial)

end Compiler.ZigAir.MemoryAir
