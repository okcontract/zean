/-
// Copyright (C) 2026 OKcontract Pte. Ltd.
// SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryAllocationShape
import Compiler.ZigAir.MemoryInvalidationModel

namespace Compiler.ZigAir.Memory

theorem invalidate_frame (state : State) (writable : Bool) (child : Ty) (address : Address) (after : State)
    (executed : invalidate state writable child address = .ok after) :
    after.nextId = state.nextId ∧ after.nextAddress = state.nextAddress ∧
      ∀ id, id ≠ address.allocation → after.heap.lookup id = state.heap.lookup id := by
  obtain ⟨_, _, _, _, _, _, rfl⟩ := invalidate_success state writable child address after executed
  exact ⟨rfl, rfl, fun id apart => replace_other _ _ id _ apart⟩

/-- Every erased leaf is absent, and every other leaf is exactly retained.
The complete allocation metadata survives; this operation is not deallocation. -/
theorem invalidate_contents (state : State) (writable : Bool) (child : Ty) (address : Address) (after : State)
    (executed : invalidate state writable child address = .ok after) :
    ∃ layout before reached, child.layout = some layout ∧ state.heap.lookup address.allocation = some before ∧
      after.heap.lookup address.allocation = some reached ∧ before.SameShape reached ∧
      ∀ query, reached.cells.lookup query =
        if address.offset ≤ query ∧ query < address.offset + layout.bytes then none else before.cells.lookup query := by
  obtain ⟨_, layout, cell, shaped, accessed, _, rfl⟩ := invalidate_success state writable child address after executed
  have found := (access_success_region state address layout true cell accessed).1
  exact ⟨layout, cell, _, shaped, found, Heap.lookup_replace _ _ _ _ found, ⟨rfl, rfl, rfl, rfl⟩,
    Cells.lookup_forget cell.cells address.offset layout.bytes⟩

theorem invalidate_retains_shape (state : State) (writable : Bool) (child : Ty) (address : Address) (after : State)
    (executed : invalidate state writable child address = .ok after) : state.heap.RetainsShape after.heap := by
  obtain ⟨_, before, reached, _, found, updated, shape, _⟩ := invalidate_contents state writable child address after executed
  intro id old present
  by_cases same : id = address.allocation
  · subst id
    cases Option.some.inj (present.symm.trans found)
    exact ⟨reached, updated, shape⟩
  · exact ⟨old, ((invalidate_frame state writable child address after executed).2.2 id same).trans present,
      Allocation.SameShape.refl old⟩

end Compiler.ZigAir.Memory
