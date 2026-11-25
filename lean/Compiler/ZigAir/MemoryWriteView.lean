/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryReadView
import Compiler.ZigAir.MemoryRecordWrites

/-! Writable element capabilities for the same typed slice geometry used by
readonly views. Storage can be uninitialized on entry. Access and declared
leaf type supply a checked store, and stores retain the geometry. -/
namespace Compiler.ZigAir.Memory.ReadView

def writePointer (view : ReadView) (index : Nat) : Value :=
  .pointer (.pointer true false view.child) (view.addressAt index)

def writeSlice (view : ReadView) : Value :=
  .slice (.slice true view.child) view.address view.length

/-- Each element names an admitted writable region and its declared leaf.
An empty view satisfies this contract for any address. -/
def Writable (state : State) (view : ReadView) : Prop :=
  ∀ i < view.length, ∃ cell,
    access state (view.addressAt i) view.layout true = .ok cell ∧
    acceptsView cell.type (view.addressAt i).offset view.child = true ∧
    leafType cell.type (view.addressAt i).offset = some view.child

theorem Writable.slice_element {view : ReadView} (cap : Writable state view) (index : Nat)
    (width : view.length < addressLimit) (inside : index < view.length) :
    sliceElementPointer state view.writeSlice index = .ok (view.writePointer index) := by
  rw [writeSlice, sliceElementPointer_in_bounds _ _ _ _ _ _ width inside]
  obtain ⟨first, writableFirst, _, _⟩ := cap 0 (by omega)
  obtain ⟨last, writableLast, _, _⟩ := cap index inside
  have readFirst := access_write_read _ _ _ _ writableFirst
  have readLast := access_write_read _ _ _ _ writableLast
  have firstFound := (access_success_region _ _ _ _ _ readFirst).1
  have lastFound := (access_success_region _ _ _ _ _ readLast).1
  have same : last = first := Option.some.inj (lastFound.symm.trans firstFound)
  subst last
  have narrow := access_narrow _ _ _ 0 false _ readFirst (by omega)
  simpa only [writePointer, addressAt, Nat.zero_mul, Nat.add_zero] using
    elementPointer_of_access state true view.child view.address index view.layout first
      view.shaped view.positive (by simpa [addressAt] using narrow) readLast

theorem Writable.stack {view : ReadView} (frame : StackFrame before after) (cap : Writable before view) :
    Writable after view := by
  intro i inside
  obtain ⟨cell, accessed, accepted, declared⟩ := cap i inside
  have prior := (access_success_region _ _ _ _ _ accessed).1
  have found := frame.old_lookup _ _ prior
  exact ⟨cell, by simpa only [access, prior, found] using accessed, accepted, declared⟩

theorem Writable.store_total {view : ReadView} (cap : Writable state view) (index : Nat)
    (inBounds : index < view.length) (atomic : leafType view.child 0 = some view.child)
    (typed : value.hasType view.child = true) : ∃ after, store state (view.writePointer index) value = .ok after := by
  obtain ⟨cell, checked, accepted, declared⟩ := cap index inBounds
  obtain ⟨same, valid⟩ := Bool.and_eq_true_iff.mp typed
  have eq : value.type = view.child := of_decide_eq_true same
  have leaves := Value.leaves_atomic value valid (by simpa only [eq] using atomic)
  have field : ∀ entry ∈ value.leaves 0,
      leafType cell.type ((view.addressAt index).offset + entry.1) = some entry.2.type := by
    intro entry inside
    simp only [leaves, List.mem_singleton] at inside
    subst entry
    simpa only [Nat.add_zero, eq] using declared
  simpa only [writePointer, eq] using store_subobject_total state (view.addressAt index) view.layout cell value
    valid (by simpa only [eq] using view.shaped) checked (by simpa only [eq] using accepted) field

theorem Writable.stored {view : ReadView} {pointer : Value} (cap : Writable state view)
    (stored : store state pointer value = .ok after) : Writable after view := by
  obtain ⟨_, _, changed, layout, target, contents, _, _, _, accessed, _, rfl⟩ :=
    store_success state pointer value after stored
  have targetFound := (access_success_region _ _ _ _ _ accessed).1
  intro i inside
  obtain ⟨cell, checked, accepted, declared⟩ := cap i inside
  have cellFound := (access_success_region _ _ _ _ _ checked).1
  by_cases same : (view.addressAt i).allocation = changed.allocation
  · have eq : cell = target := Option.some.inj (cellFound.symm.trans (same ▸ targetFound))
    subst cell
    have updated := access_replace_cells state (view.addressAt i) view.layout true target contents cellFound
    rw [checked, same] at updated
    exact ⟨{ target with cells := contents }, updated, accepted, declared⟩
  · have unchanged := replace_other state.heap changed.allocation (view.addressAt i).allocation
      { target with cells := contents } same
    exact ⟨cell, by simpa only [access, State.heap, unchanged] using checked, accepted, declared⟩

theorem Represents.store_other {view : ReadView} {values : Nat → Value} {child : Ty}
    (represented : Represents state view values)
    (apart : view.address.allocation ≠ updated.allocation)
    (stored : store state (.pointer (.pointer write many child) updated) value = .ok after) :
    Represents after view values := by
  intro i inside
  exact (load_other_after_store state write many child updated value after
    false false view.child (view.addressAt i) stored apart).trans (represented i inside)

/-- An aligned subview of a declared writable array supplies its checked
elements, including elements whose cells have not been initialized. -/
theorem Writable.of_array {view : ReadView} (first extent : Nat) (cell : Allocation)
    (valid : state.valid = true) (found : state.heap.lookup view.address.allocation = some cell)
    (typed : cell.type = .array extent view.child) (writable : cell.writable = true)
    (aligned : view.address.offset = first * view.layout.bytes)
    (stride : view.layout.bytes % view.layout.alignment = 0)
    (atomic : leafType view.child 0 = some view.child)
    (bounded : first + view.length ≤ extent) : Writable state view := by
  intro i inside
  have member : first + i < extent := by omega
  have shifted : view.addressAt i = ⟨view.address.allocation, (first + i) * view.layout.bytes⟩ := by
    simp only [addressAt, aligned, Nat.add_mul]
  have checked := Memory.array_access state view.address.allocation extent (first + i) view.layout.bytes
    view.child view.layout cell valid found typed writable view.shaped view.positive stride member (Nat.le_refl _) true
  have divided := Nat.mul_div_cancel (first + i) view.positive
  have modulo : ((first + i) * view.layout.bytes) % view.layout.bytes = 0 := by simp
  refine ⟨cell, shifted ▸ checked, ?_, ?_⟩
  · simp [shifted, typed, view.shaped, view.positive, divided, modulo, member]
  · simp [shifted, typed, view.shaped, view.positive, divided, modulo, member, atomic]

theorem Represents.cleanup {view : ReadView} {values : Nat → Value}
    (represented : Represents state view values) (older : view.address.allocation < mark) :
    Represents (Memory.cleanup mark state) view values := by
  intro i inside
  exact (load_eq_of_lookup state (Memory.cleanup mark state) false false view.child (view.addressAt i)
    (cleanup_lookup_older state mark view.address.allocation older)).trans (represented i inside)

end Compiler.ZigAir.Memory.ReadView
