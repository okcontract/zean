/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryBorrowedFrame
import Compiler.ZigAir.MemoryWordReadable
import Compiler.ZigAir.MemoryRootCapability

namespace Compiler.ZigAir.Memory
open WordArray

theorem WordCopy.Prefix.zero (state : State) (target : View) (items : List (BitVec 32)) :
    Prefix state target items 0 := by intro index _ earlier; omega

theorem WordArray.Represents.read (state : State) (view : View) (items : List (BitVec 32)) (index : Nat)
    (represented : Represents state view items) (inside : index < items.length) :
    load state (WordCopy.readPointer view index) = .ok (number items[index]) := represented.2 index inside

/-- Connect an initialized array view to the pointer returned by element
selection. The pointer may still be a symbolic SSA result when this rule fires. -/
theorem WordArray.Represents.read_element (state : State) (view : View) (items : List (BitVec 32))
    (index : Nat) (pointer : Value) (represented : Represents state view items)
    (cap : Readable state view) (valid : state.valid = true) (inside : index < items.length)
    (selected : elementPointer state view.readBuffer index = .ok pointer) :
    load state pointer = .ok (number items[index]) := by
  have element := Readable.element state view index valid cap (by simpa only [represented.1] using inside)
  have same := Except.ok.inj (selected.symm.trans element)
  subst pointer
  exact Represents.read state view items index represented inside

grind_pattern WordArray.Represents.read_element => WordArray.Represents state view items,
  elementPointer state view.readBuffer index, (Except.ok pointer : Except Fault Value)

theorem WordArray.BorrowedFrame.source {source : View} (frame : BorrowedFrame target before current)
    (represented : Represents before source items) (apart : WordCopy.disjoint source target = true) :
    Represents current source items := by
  obtain ⟨caller, _, stack, heap⟩ := frame
  exact (WordCopy.source_frame before caller source target items represented apart heap).stack stack

theorem WordArray.Readable.allocated (state after : State) (view : View) (type : Ty) (pointer : Value)
    (valid : state.valid = true) (cap : Readable state view)
    (allocated : allocate state type = .ok (pointer, after)) : Readable after view :=
  cap.stack ((StackFrame.refl state valid).allocate type pointer after allocated)

theorem WordCopy.Prefix.store_other (copied : Prefix state target items count)
    (write many : Bool) (child : Ty) (address : Address) (value : Value)
    (apart : target.allocation ≠ address.allocation)
    (stored : store state (.pointer (.pointer write many child) address) value = .ok after) :
    Prefix after target items count := by
  intro index inside earlier
  exact (load_other_after_store state write many child address value after true false word
    (target.address index) stored apart).trans (copied index inside earlier)

theorem WordCopy.Prefix.cleanup (copied : Prefix state target items count) (mark : Nat)
    (older : target.allocation < mark) : Prefix (Memory.cleanup mark state) target items count := by
  intro index inside earlier
  exact (load_eq_of_lookup state (Memory.cleanup mark state) true false word (target.address index)
    (cleanup_lookup_older state mark target.allocation older)).trans (copied index inside earlier)

theorem WordCopy.Prefix.complete (copied : Prefix state target items count)
    (length : items.length = target.length) (finished : items.length ≤ count) : Represents state target items :=
  ⟨length, fun index inside => copied index inside (by omega)⟩

grind_pattern WordCopy.Prefix.store_other => WordCopy.Prefix state target items count,
  StoreStep state (.pointer (.pointer write many child) address) value after
grind_pattern WordArray.BorrowedFrame.store_local => BorrowedFrame view before current,
  StoreStep current (.pointer (.pointer write many child) address) value after
grind_pattern WordArray.BorrowedFrame.store_word => BorrowedFrame view before current,
  StoreStep current (view.pointer index) (number value) after

end Compiler.ZigAir.Memory
