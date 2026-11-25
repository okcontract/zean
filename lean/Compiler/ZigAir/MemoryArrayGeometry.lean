/-
// Copyright (C) 2026 OKcontract Pte. Ltd.
// SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryAllocationLaws

namespace Compiler.ZigAir.Memory

private theorem array_access_at (state : State) (id extent index bytes : Nat) (child : Ty)
    (layout : Layout) (cell : Allocation) (initial : state.valid = true)
    (found : state.heap.lookup id = some cell) (typed : cell.type = .array extent child)
    (shaped : child.layout = some layout)
    (positive : 0 < layout.bytes) (stride : layout.bytes % layout.alignment = 0)
    (inside : index * layout.bytes + bytes ≤ extent * layout.bytes)
    (addressRoom : index < extent ∨ state.nextAddress < addressLimit) (write : Bool)
    (permitted : write = true → cell.writable = true) :
    access state ⟨id, index * layout.bytes⟩ ⟨bytes, layout.alignment⟩ write = .ok cell := by
  obtain ⟨_, basePositive, actual, actualShape, aligned, bounded, limit⟩ :=
    valid_lookup state id cell initial found
  have arrayShape : cell.type.layout = some ⟨extent * layout.bytes, layout.alignment⟩ := by
    simp only [typed, Ty.layout, shaped, bind, Option.bind]
  have same : actual = ⟨extent * layout.bytes, layout.alignment⟩ :=
    Option.some.inj (actualShape.symm.trans arrayShape)
  subst actual
  dsimp only at aligned bounded
  have pointerBound : cell.base + index * layout.bytes < addressLimit := by
    rcases addressRoom with element | room
    · have offsetInside := Nat.mul_lt_mul_of_pos_right element positive
      omega
    · omega
  have offsetAligned : (cell.base + index * layout.bytes) % layout.alignment = 0 := by
    simp only [Nat.add_mod, Nat.mul_mod, aligned, stride, Nat.mul_zero, Nat.zero_mod, Nat.add_zero]
  have checks : ¬(cell.base = 0 ∨ cell.base + extent * layout.bytes > addressLimit ∨
      cell.base + index * layout.bytes ≥ addressLimit ∨ index * layout.bytes + bytes > extent * layout.bytes ∨
      (cell.base + index * layout.bytes) % layout.alignment ≠ 0) := by omega
  cases write <;>
    simp only [access, found, arrayShape, Bool.false_and, Bool.false_eq_true, ↓reduceIte, ite_eq_right checks]
  simp only [permitted rfl, Bool.not_true, Bool.true_and, Bool.false_eq_true, ↓reduceIte]

/-- Check a range of complete elements in a declared array. An empty range
can start at the end, including in a zero-length static array, provided the
derived one-past address remains representable. -/
theorem array_range_access (state : State) (id extent first count : Nat) (child : Ty)
    (layout : Layout) (cell : Allocation) (initial : state.valid = true)
    (found : state.heap.lookup id = some cell) (typed : cell.type = .array extent child)
    (shaped : child.layout = some layout)
    (positive : 0 < layout.bytes) (stride : layout.bytes % layout.alignment = 0)
    (fits : first + count ≤ extent)
    (addressRoom : first < extent ∨ state.nextAddress < addressLimit) (write : Bool)
    (permitted : write = true → cell.writable = true) :
    access state ⟨id, first * layout.bytes⟩ ⟨count * layout.bytes, layout.alignment⟩ write = .ok cell := by
  refine array_access_at state id extent first _ child layout cell initial found typed shaped positive stride
    ?_ addressRoom write permitted
  rw [← Nat.add_mul]
  exact Nat.mul_le_mul_right layout.bytes fits

/-- Derive each element's checked access from a valid declared array. Positive
stride and its alignment multiple are separate captured-layout obligations. -/
theorem array_access_permitted (state : State) (id extent index bytes : Nat) (child : Ty)
    (layout : Layout) (cell : Allocation) (initial : state.valid = true)
    (found : state.heap.lookup id = some cell) (typed : cell.type = .array extent child)
    (shaped : child.layout = some layout)
    (positive : 0 < layout.bytes) (stride : layout.bytes % layout.alignment = 0)
    (inside : index < extent) (width : bytes ≤ layout.bytes) (write : Bool)
    (permitted : write = true → cell.writable = true) :
    access state ⟨id, index * layout.bytes⟩ ⟨bytes, layout.alignment⟩ write = .ok cell := by
  refine array_access_at state id extent index bytes child layout cell initial found typed shaped positive stride
    ?_ (.inl inside) write permitted
  calc
    index * layout.bytes + bytes ≤ index * layout.bytes + layout.bytes := by omega
    _ = (index + 1) * layout.bytes := by rw [Nat.add_mul, Nat.one_mul]
    _ ≤ extent * layout.bytes := Nat.mul_le_mul_right layout.bytes (by omega)

/-- The writable-array facade retains its existing interface. Readonly callers
use the permission law above without assuming that their storage is writable. -/
theorem array_access (state : State) (id extent index bytes : Nat) (child : Ty)
    (layout : Layout) (cell : Allocation) (initial : state.valid = true)
    (found : state.heap.lookup id = some cell) (typed : cell.type = .array extent child)
    (writable : cell.writable = true) (shaped : child.layout = some layout)
    (positive : 0 < layout.bytes) (stride : layout.bytes % layout.alignment = 0)
    (inside : index < extent) (width : bytes ≤ layout.bytes) (write : Bool) :
    access state ⟨id, index * layout.bytes⟩ ⟨bytes, layout.alignment⟩ write = .ok cell :=
  array_access_permitted state id extent index bytes child layout cell initial found typed shaped positive stride inside width write
    (by intro _; exact writable)

end Compiler.ZigAir.Memory
