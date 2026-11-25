/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryArrayGeometry
import Compiler.ZigAir.MemoryScalarBytes
import Compiler.ZigAir.MemoryShapePreservation
import Compiler.ZigAir.MemoryReadView

/-! Byte-array capabilities for bulk operations. Extent and permission are
separate from initialization; disjoint ranges may share one allocation. -/
namespace Compiler.ZigAir.Memory.ByteArray

abbrev byte : Ty := .scalar (.int false 8)
def number (value : BitVec 8) : Value := .scalar (.int false 8 value.toNat)

structure View where
  address : Address
  length : Nat
  deriving DecidableEq, Repr

def View.at (view : View) (index : Nat) : Address :=
  ⟨view.address.allocation, view.address.offset + index⟩
def View.pointer (view : View) (writable many : Bool) (index : Nat := 0) : Value :=
  .pointer (.pointer writable many byte) (view.at index)
def View.slice (view : View) (writable : Bool) : Value :=
  .slice (.slice writable byte) view.address view.length
def View.readView (view : View) : ReadView :=
  ⟨byte, ⟨1, 1⟩, rfl, by decide, view.address, view.length⟩

/-- Every byte in the view is a declared byte leaf. Allocation bounds alone
cannot justify viewing padding or a differently typed field as a byte array. -/
def DeclaredBytes (type : Ty) (offset length : Nat) : Prop :=
  ∀ index < length,
    acceptsView type (offset + index) byte = true ∧
    leafType type (offset + index) = some byte ∧
    ScalarBytes.locate type (offset + index) = some (offset + index, false, 8)

/-- A live declared byte region with a valid starting address, also for an
empty view. The owner may be an array or a complete record containing one.
Contents and permission remain independent obligations. -/
def Region (state : State) (view : View) (write : Bool) : Prop :=
  ∃ layout cell, state.heap.lookup view.address.allocation = some cell ∧
    cell.type.layout = some layout ∧ (write = true → cell.writable = true) ∧
    view.address.offset < layout.bytes ∧ view.address.offset + view.length ≤ layout.bytes ∧
    DeclaredBytes cell.type view.address.offset view.length

theorem DeclaredBytes.array (inside : offset + length ≤ extent) :
    DeclaredBytes (.array extent byte) offset length := by
  intro index bound
  have within : offset + index < extent := by omega
  simp [acceptsView, leafType, byte, ScalarBytes.locate, ScalarBytes.atom, Ty.layout, within, Nat.mod_one]

/-- Existing root-array clients are instances of the general region contract. -/
theorem Region.array (found : state.heap.lookup view.address.allocation = some cell)
    (typed : cell.type = .array extent byte) (permission : write = true → cell.writable = true)
    (start : view.address.offset < extent) (bound : view.address.offset + view.length ≤ extent) :
    Region state view write :=
  ⟨⟨extent, 1⟩, cell, found, by simp [typed, Ty.layout, byte], permission, start, bound,
    typed ▸ DeclaredBytes.array bound⟩

def Represents (state : State) (view : View) (contents : Nat → BitVec 8) : Prop :=
  ∀ index < view.length, load state (view.pointer false false index) = .ok (number (contents index))

def Disjoint (source target : View) : Prop :=
  source.address.allocation ≠ target.address.allocation ∨
    source.address.offset + source.length ≤ target.address.offset ∨
    target.address.offset + target.length ≤ source.address.offset

theorem number_valid (value : BitVec 8) : (number value).valid = true := by
  have bound := value.isLt
  simp [number, Value.valid, Scalar.Value.valid, Scalar.Ty.contains, Scalar.Ty.lower, Scalar.Ty.upper]
  omega

theorem number_typed (value : BitVec 8) : (number value).hasType byte = true := by
  simpa [Value.hasType, number, Value.type, Scalar.Value.type] using number_valid value

theorem Region.retained (cap : Region before view write) (shape : before.heap.RetainsShape after.heap) :
    Region after view write := by
  obtain ⟨layout, cell, found, shaped, permission, start, bound, declared⟩ := cap
  obtain ⟨updated, lookup, same⟩ := shape _ _ found
  exact ⟨layout, updated, lookup, same.2.1 ▸ shaped,
    fun h => same.2.2.1.trans (permission h), start, bound, same.2.1 ▸ declared⟩

theorem Region.stack (cap : Region before view write) (frame : StackFrame before after) :
    Region after view write := by
  obtain ⟨extent, cell, found, rest⟩ := cap
  exact ⟨extent, cell, frame.old_lookup _ _ found, rest⟩

theorem Region.stored (cap : Region before view write) (stored : store before pointer value = .ok after) :
    Region after view write := cap.retained (store_retains_shape _ _ _ _ stored)

theorem Region.width (valid : state.valid = true) (cap : Region state view write) :
    view.length < addressLimit := by
  obtain ⟨region, cell, found, shape, _, _, bound, _⟩ := cap
  obtain ⟨_, base, layout, shaped, _, bounded, limit⟩ := valid_lookup state _ cell valid found
  cases Option.some.inj (shaped.symm.trans shape)
  omega

theorem Region.range (valid : state.valid = true) (cap : Region state view write)
    (countBound : offset + count ≤ view.length)
    (start : view.address.offset + offset < (view.address.offset + view.length) ∨ offset = 0) :
    ∃ cell, access state (view.at offset) ⟨count, 1⟩ write = .ok cell ∧
      DeclaredBytes cell.type view.address.offset view.length := by
  obtain ⟨region, cell, found, shape, permission, lower, bound, declared⟩ := cap
  obtain ⟨_, base, layout, shaped, _, bounded, limit⟩ := valid_lookup state _ cell valid found
  cases Option.some.inj (shaped.symm.trans shape)
  have permitted : (write && !cell.writable) = false := by
    cases write <;> simp_all
  have checks : ¬(cell.base = 0 ∨ cell.base + region.bytes > addressLimit ∨
      cell.base + (view.address.offset + offset) ≥ addressLimit ∨
      view.address.offset + offset + count > region.bytes ∨
      (cell.base + (view.address.offset + offset)) % 1 ≠ 0) := by
    simp only [Nat.mod_one]; omega
  refine ⟨cell, ?_, declared⟩
  simp only [access, View.at, found, shape, permitted, Bool.false_eq_true, ↓reduceIte]
  exact ite_eq_right checks

theorem Region.access (valid : state.valid = true) (cap : Region state view write)
    (inside : index < view.length) :
    ∃ cell, acceptsView cell.type (view.at index).offset byte = true ∧
      leafType cell.type (view.at index).offset = some byte ∧
      ScalarBytes.locate cell.type (view.at index).offset = some ((view.at index).offset, false, 8) ∧
      access state (view.at index) ⟨1, 1⟩ write = .ok cell := by
  obtain ⟨cell, accessed, declared⟩ := cap.range valid
    (by omega : index + 1 ≤ view.length) (.inl (by omega))
  have leaves := declared index inside
  exact ⟨cell, leaves.1, leaves.2.1, leaves.2.2, accessed⟩

theorem Region.write (valid : state.valid = true) (cap : Region state view true)
    (inside : index < view.length) (value : BitVec 8) :
    ∃ after, store state (view.pointer true false index) (number value) = .ok after := by
  obtain ⟨cell, viewed, declared, _, accessed⟩ := cap.access valid inside
  apply store_subobject_total state (view.at index) ⟨1, 1⟩ cell (number value) (number_valid value) rfl accessed
  · exact viewed
  · intro entry present
    simp only [number, Value.leaves, List.mem_singleton] at present
    subst entry
    simpa only [Nat.add_zero, Value.type, Scalar.Value.type, byte] using declared

theorem Region.readByte_of_load (valid : state.valid = true) (cap : Region state view false)
    (inside : index < view.length)
    (loaded : load state (view.pointer false false index) = .ok (number value)) :
    ScalarBytes.readAt state (view.at index) = .ok value := by
  obtain ⟨cell, _, _, located, accessed⟩ := cap.access valid inside
  simp only [View.pointer] at loaded
  simp only [ScalarBytes.readAt, accessed, located, loaded, bind, Except.bind, Nat.sub_self,
    Nat.pow_zero, Nat.div_one]
  simp [number]

theorem Represents.readByte (valid : state.valid = true) (cap : Region state view false)
    (represented : Represents state view contents) (inside : index < view.length) :
    ScalarBytes.readAt state (view.at index) = .ok (contents index) :=
  cap.readByte_of_load valid inside (represented index inside)

theorem load_byte_after_store_distinct {view target : View}
    (stored : store before (target.pointer true false index) (number byteValue) = .ok after)
    (apart : view.address.allocation ≠ target.address.allocation ∨
      view.address.offset + other ≠ target.address.offset + index) :
    load after (view.pointer false false other) = load before (view.pointer false false other) := by
  by_cases same : view.address.allocation = target.address.allocation
  · have different := apart.resolve_left (not_not_intro same)
    have result := load_disjoint_after_store before true false byte (target.at index) (number byteValue)
      after false false byte (view.at other).offset stored (by
        intro position read entry written
        simp only [Ty.readOffsets, List.mem_singleton] at read
        simp only [number, Value.leaves, List.mem_singleton] at written
        subst position entry
        exact different)
    simpa only [View.pointer, View.at, same] using result
  · exact load_other_after_store before true false byte (target.at index) (number byteValue) after
      false false byte (view.at other) stored same

theorem Represents.stored (represented : Represents before source contents)
    (separate : Disjoint source target) (inside : index < target.length)
    (stored : store before (target.pointer true false index) (number value) = .ok after) :
    Represents after source contents := by
  intro other within
  refine (load_byte_after_store_distinct stored ?_).trans (represented other within)
  rcases separate with allocations | left | right
  · exact .inl allocations
  · exact .inr (by omega)
  · exact .inr (by omega)

set_option maxRecDepth 4096 in
theorem copyLoop_safe (valid : state.valid = true) (readable : Region state source false)
    (writable : Region state target true) (represented : Represents state source contents)
    (separate : Disjoint source target) (readBound : index + count ≤ source.length)
    (writeBound : index + count ≤ target.length) :
    ∃ after, ByteRange.copyLoop state source.address target.address index count = (.ok (), after) ∧
      after.valid = true := by
  induction count generalizing state index with
  | zero => exact ⟨state, rfl, valid⟩
  | succ count ih =>
    have read := represented.readByte valid readable (by omega : index < source.length)
    obtain ⟨after, stored⟩ := writable.write valid (by omega : index < target.length) (contents index)
    have copied : ByteRange.copyByte state source.address target.address index = .ok after := by
      rw [ByteRange.copyByte_initialized read]
      exact stored
    obtain ⟨last, complete, safe⟩ := ih (index := index + 1) (store_preserves_valid _ _ _ _ valid stored)
      (readable.stored stored) (writable.stored stored) (represented.stored separate (by omega) stored)
      (by omega) (by omega)
    exact ⟨last, by simp only [ByteRange.copyLoop, copied, complete], safe⟩

theorem copy_safe (valid : state.valid = true) (readable : Region state source false)
    (writable : Region state target true) (represented : Represents state source contents)
    (separate : Disjoint source target) (readBound : count ≤ source.length) (writeBound : count ≤ target.length) :
    ∃ after, ByteRange.copy state (.slice (.slice true byte) target.address count)
      (source.pointer false true) = (.ok (), after) ∧ after.valid = true := by
  have apart : ¬(count > 0 ∧ source.address.allocation = target.address.allocation ∧
      source.address.offset < target.address.offset + count ∧ target.address.offset < source.address.offset + count) := by
    simp only [Disjoint] at separate
    omega
  simpa only [ByteRange.copy, ByteRange.destination, ByteRange.source, View.pointer, View.at,
    Nat.add_zero, ite_eq_right apart] using
    copyLoop_safe valid readable writable represented separate (by omega : 0 + count ≤ source.length)
      (by omega : 0 + count ≤ target.length)

end Compiler.ZigAir.Memory.ByteArray
