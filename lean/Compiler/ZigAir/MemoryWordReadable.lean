/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryWordFrameVerification

/-! Geometry for readonly word views, separate from initialized contents. -/
namespace Compiler.ZigAir.Memory.WordArray

def Readable (state : State) (view : View) : Prop :=
  ∃ extent cell, state.heap.lookup view.allocation = some cell ∧
    cell.type = .array extent word ∧ view.first + view.length ≤ extent

def View.readBuffer (view : View) : Value :=
  .pointer (.pointer false true word) (view.address 0)

theorem Writable.readable (cap : Writable state view) : Readable state view := by
  obtain ⟨extent, cell, found, typed, _, bound⟩ := cap
  exact ⟨extent, cell, found, typed, bound⟩

theorem Readable.stack (frame : StackFrame before after) (cap : Readable before view) :
    Readable after view := by
  obtain ⟨extent, cell, found, typed, bound⟩ := cap
  exact ⟨extent, cell, frame.old_lookup _ _ found, typed, bound⟩

theorem Readable.older (valid : state.valid = true) (cap : Readable state view) :
    view.allocation < state.nextId := by
  obtain ⟨_, cell, found, _⟩ := cap
  exact (valid_lookup state view.allocation cell valid found).1

theorem Readable.stored (cap : Readable state view) (stored : store state pointer value = .ok after) :
    Readable after view := by
  obtain ⟨extent, cell, found, typed, bound⟩ := cap
  obtain ⟨_, _, address, layout, target, contents, _, _, _, accessed, _, rfl⟩ :=
    store_success state pointer value after stored
  have targetFound := (access_success_region state address layout true target accessed).1
  by_cases alias : view.allocation = address.allocation
  · have same : cell = target := Option.some.inj (found.symm.trans (alias ▸ targetFound))
    subst target
    exact ⟨extent, { cell with cells := contents }, by
      simpa only [alias] using Heap.lookup_replace state.heap address.allocation cell _ targetFound,
      typed, bound⟩
  · exact ⟨extent, cell, (replace_other state.heap address.allocation view.allocation _ alias).trans found,
      typed, bound⟩

theorem Readable.element (state : State) (view : View) (index : Nat)
    (valid : state.valid = true) (cap : Readable state view) (inside : index < view.length) :
    elementPointer state view.readBuffer index = .ok (WordCopy.readPointer view index) := by
  obtain ⟨extent, cell, found, typed, bound⟩ := cap
  have accessAt (i bytes : Nat) (hi : i < extent) (width : bytes ≤ 4) :=
    array_access_permitted state view.allocation extent i bytes word ⟨4, 4⟩ cell valid found typed
      rfl (by decide) (by decide) hi width false (by simp)
  have first := accessAt view.first 0 (by omega) (by omega)
  have last := accessAt (view.first + index) 4 (by omega) (by omega)
  simpa [View.readBuffer, WordCopy.readPointer, View.address, Nat.add_mul] using
    elementPointer_of_access state false word (view.address 0) index ⟨4, 4⟩ cell rfl (by decide)
      (by simpa [View.address] using first) (by simpa [View.address, Nat.add_mul] using last)

grind_pattern Readable.element => Readable state view,
  elementPointer state (.pointer (.pointer false true word) (view.address 0)) index
grind_pattern element_pointer => Writable state view,
  elementPointer state (.pointer (.pointer true true word) (view.address 0)) index

theorem Represents.stack (frame : StackFrame before after)
    (represented : Represents before view items) : Represents after view items := by
  refine ⟨represented.1, ?_⟩
  intro index inside
  exact frame.old_load true false word (view.address index) _ (represented.2 index inside)

theorem Represents.store_other (represented : Represents state view items)
    (write many : Bool) (child : Ty) (address : Address) (value : Value)
    (apart : view.allocation ≠ address.allocation)
    (stored : store state (.pointer (.pointer write many child) address) value = .ok after) :
    Represents after view items := by
  refine ⟨represented.1, ?_⟩
  intro index inside
  exact (load_other_after_store state write many child address value after true false word
    (view.address index) stored apart).trans (represented.2 index inside)

end Compiler.ZigAir.Memory.WordArray
