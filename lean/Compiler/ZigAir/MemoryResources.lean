/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryAllocationLaws

/-! Explicit resource contracts for the modeled stack allocator. The cursor is
an allocation-history bound, not native stack usage. These facts prevent an
allowed exhaustion result from substituting for a successful-execution claim. -/
namespace Compiler.ZigAir.Memory

def allocationBase (cursor : Nat) (layout : Layout) : Nat :=
  cursor + (layout.alignment - cursor % layout.alignment) % layout.alignment

/-- Exact arithmetic resource obligation, independent of heap contents. -/
def AllocationRoom (cursor : Nat) (type : Ty) : Prop :=
  ∃ layout, type.layout = some layout ∧ 0 < allocationBase cursor layout ∧
    allocationBase cursor layout + layout.bytes < addressLimit

theorem allocate_total (state : State) (type : Ty)
    (valid : state.valid = true) (room : AllocationRoom state.nextAddress type) :
    ∃ value after, allocate state type = .ok (value, after) := by
  obtain ⟨layout, shaped, positive, bounded⟩ := room
  have fits : ¬(allocationBase state.nextAddress layout = 0 ∨
      allocationBase state.nextAddress layout + layout.bytes ≥ addressLimit) := by omega
  simp only [allocate, valid, Bool.not_true, Bool.false_eq_true, ↓reduceIte, shaped]
  change ∃ value after, (if allocationBase state.nextAddress layout = 0 ∨
    allocationBase state.nextAddress layout + layout.bytes ≥ addressLimit then
    Except.error Fault.outOfMemory else _) = .ok (value, after)
  rw [ite_eq_right fits]
  exact ⟨_, _, rfl⟩

theorem allocate_no_fault (state : State) (type : Ty) (fault : Fault)
    (valid : state.valid = true) (room : AllocationRoom state.nextAddress type)
    (failed : allocate state type = .error fault) : False := by
  obtain ⟨value, after, success⟩ := allocate_total state type valid room
  rw [success] at failed
  contradiction

/-- A conservative byte budget includes at most alignment minus one bytes of
padding. The strict end bound matches the allocator, including zero-sized types. -/
theorem AllocationRoom.of_budget (cursor : Nat) (type : Ty) (layout : Layout)
    (shaped : type.layout = some layout) (positive : 0 < cursor)
    (aligned : 0 < layout.alignment)
    (budget : cursor + (layout.alignment - 1) + layout.bytes < addressLimit) :
    AllocationRoom cursor type := by
  have padding := Nat.mod_lt (layout.alignment - cursor % layout.alignment) aligned
  exact ⟨layout, shaped, by unfold allocationBase; omega, by unfold allocationBase; omega⟩

/-- Resource accounting survives cleanup: this semantics deliberately retains
allocation history. Clients cannot assume that returning restores the budget. -/
theorem allocationRoom_cleanup (mark : Nat) (state : State) (type : Ty) :
    AllocationRoom (cleanup mark state).nextAddress type ↔ AllocationRoom state.nextAddress type :=
  Iff.rfl

/-- Resource budgets are unaffected by a successful store. -/
theorem allocationRoom_store (state after : State) (pointer value : Value) (type : Ty)
    (stored : store state pointer value = .ok after) :
    AllocationRoom after.nextAddress type ↔ AllocationRoom state.nextAddress type := by
  rw [(store_keeps_counters state pointer value after stored).2]

/-- The modeled allocator consumes at most the object size plus its worst-case
alignment padding. This bounds allocation history, not native stack usage. -/
theorem allocate_cursor_cost (state after : State) (type : Ty) (layout : Layout) (pointer : Value)
    (shaped : type.layout = some layout)
    (allocated : allocate state type = .ok (pointer, after)) :
    state.nextAddress ≤ after.nextAddress ∧
      after.nextAddress ≤ state.nextAddress + (layout.alignment - 1) + layout.bytes := by
  have aligned := layout_alignment_positive type layout shaped
  have padding := Nat.mod_lt (layout.alignment - state.nextAddress % layout.alignment) aligned
  unfold allocate at allocated
  split at allocated
  · contradiction
  · simp only [shaped] at allocated
    split at allocated
    · contradiction
    · cases Except.ok.inj allocated
      dsimp
      omega

theorem allocate_slice_cost (allocated : allocate state (.slice writable child) = .ok (pointer, after)) :
    state.nextAddress ≤ after.nextAddress ∧ after.nextAddress ≤ state.nextAddress + 23 :=
  allocate_cursor_cost state after (.slice writable child) ⟨16, 8⟩ pointer rfl allocated

theorem allocate_slice_no_fault (valid : state.valid = true) (positive : 0 < state.nextAddress)
    (budget : state.nextAddress + 23 < addressLimit)
    (failed : allocate state (.slice writable child) = .error fault) : False :=
  allocate_no_fault state (.slice writable child) fault valid
    (AllocationRoom.of_budget state.nextAddress (.slice writable child) ⟨16, 8⟩ rfl positive (by decide) budget) failed

end Compiler.ZigAir.Memory
