/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryByteCopyAutomation

namespace Compiler.ZigAir.Memory

/-- Successful byte indexing fixes the result address even before the loop's
bounds have been normalized. Failed indexing still needs a separate safety
proof from the caller's region and index obligations. -/
theorem byte_slice_pointer (state : State) (writable : Bool) (address : Address)
    (length index : Nat) (result : Value)
    (selected : sliceElementPointer state (.slice (.slice writable (.scalar (.int false 8))) address length)
      index = .ok result) :
    result = .pointer (.pointer writable false (.scalar (.int false 8)))
      ⟨address.allocation, address.offset + index⟩ := by
  obtain ⟨_, _, layout, shaped, _, same⟩ :=
    sliceElementPointer_address state writable (.scalar (.int false 8)) address length index result selected
  have geometry : layout = ⟨1, 1⟩ := Option.some.inj shaped.symm
  subst layout
  simpa using same

end Compiler.ZigAir.Memory

namespace Compiler.ZigAir.Memory.ByteArray

theorem Represents.readView (represented : Represents state view contents) :
    ReadView.Represents state view.readView (fun index => number (contents index)) := by
  simpa [Represents, ReadView.Represents, View.readView, ReadView.pointer, ReadView.addressAt, View.pointer, View.at] using represented

theorem Represents.slice_read (represented : Represents state view contents)
    (width : view.length < addressLimit) (inside : index < view.length)
    (selected : sliceElementPointer state (view.slice false) index = .ok pointer) :
    load state pointer = .ok (number (contents index)) := by
  have chosen := represented.readView.slice_element index width inside
  have same : pointer = view.readView.pointer index := Except.ok.inj (selected.symm.trans chosen)
  subst pointer
  exact represented.readView index inside

theorem Represents.select (represented : Represents state view contents)
    (width : view.length < addressLimit) (inside : index < view.length) :
    sliceElementPointer state (.slice (.slice false byte) view.address view.length) index =
      .ok (view.pointer false false index) := by
  simpa [View.readView, ReadView.slice, ReadView.pointer, ReadView.addressAt, View.pointer, View.at]
    using represented.readView.slice_element index width inside

theorem Represents.read (represented : Represents state view contents) (inside : index < view.length) :
    load state (view.pointer false false index) = .ok (number (contents index)) := represented index inside

/-- A normalized length may come from another, equally sized view. Keep the
address tied to the represented view when rewriting that length. -/
theorem Represents.select_length (represented : Represents state view contents)
    (same : view.length = length) (width : length < addressLimit) (inside : index < length) :
    sliceElementPointer state (.slice (.slice false byte) view.address length) index =
      .ok (view.pointer false false index) ∧
    load state (view.pointer false false index) = .ok (number (contents index)) := by
  subst length
  exact ⟨represented.select width inside, represented.read inside⟩

/-- Bind the requested index to a reached operation before solving its bounds.
This avoids generating reads for every unrelated arithmetic fact in the VC. -/
theorem Represents.selected
    (observed : sliceElementPointer state (.slice (.slice false byte) view.address length) index = outcome)
    (represented : Represents state view contents)
    (same : view.length = length) (width : length < addressLimit) (inside : index < length) :
    outcome = .ok (view.pointer false false index) :=
  observed.symm.trans (represented.select_length same width inside).1

theorem Represents.loaded
    (observed : load state (view.pointer false false index) = outcome)
    (represented : Represents state view contents) (inside : index < view.length) :
    outcome = .ok (number (contents index)) := observed.symm.trans (represented index inside)

/-- Use a reached signed AIR index directly. Its conversion to a natural
offset cannot discard the negative-index obligation. -/
theorem Represents.selected_int
    (observed : sliceElementPointer state (.slice (.slice false byte) view.address length) index.toNat = outcome)
    (represented : Represents state view contents) (same : view.length = length)
    (width : length < addressLimit) (nonnegative : 0 ≤ index) (inside : index < (length : Int)) :
    outcome = .ok (view.pointer false false index.toNat) :=
  represented.selected observed same width (by omega)

grind_pattern Represents.select => Represents state view contents,
  sliceElementPointer state (.slice (.slice false (.scalar (.int false 8))) view.address view.length) index
grind_pattern Represents.read => Represents state view contents,
  load state (.pointer (.pointer false false (.scalar (.int false 8))) ⟨view.address.allocation, view.address.offset + index⟩)
grind_pattern Represents.select_length => Represents state view contents,
  sliceElementPointer state (.slice (.slice false (.scalar (.int false 8))) view.address length) index

grind_pattern Represents.slice_read => Represents state view contents,
  sliceElementPointer state (view.slice false) index, (Except.ok pointer : Except Fault Value)

end Compiler.ZigAir.Memory.ByteArray

namespace Compiler.ZigAir.MemoryAir.Verify
open Memory

theorem index_inside (index : Int) (length : Nat) (nonnegative : 0 ≤ index)
    (inside : index < (length : Int)) : index.toNat < length := by omega

/-- Expose integer constructors supplied by typed reads and callee contracts
before reducing comparisons and loop arithmetic. -/
elab "air_byte_reads" : tactic => Lean.Elab.Tactic.liftMetaTactic fun goal =>
  saturateFacts goal #[``byte_slice_pointer, ``load_hasType, ``load_hasType_of_pointer, ``Value.unsigned_value,
    ``ByteArray.Represents.selected, ``ByteArray.Represents.selected_int, ``ByteArray.Represents.loaded] 2

/-- Heap laws use named byte and size types; captured programs spell out these
types. Normalize those aliases before using equal read equations. -/
macro "air_byte_reduce" : tactic => `(tactic| (
  all_goals try simp only [usize, ByteArray.byte] at *
  air_reduce))

end Compiler.ZigAir.MemoryAir.Verify
