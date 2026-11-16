/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryWordFrameVerification

/-! Sequential framing for writes to a borrowed word view under arbitrary
invocation-owned stack storage. This permits aliases; it is not an exclusive
ownership or concurrency discipline. -/
namespace Compiler.ZigAir.Memory.WordArray

def BorrowedFrame (view : View) (before current : State) : Prop :=
  ∃ caller, caller.nextId = before.nextId ∧ StackFrame caller current ∧ HeapFrame view before caller

theorem BorrowedFrame.refl (view : View) (state : State) (valid : state.valid = true) :
    BorrowedFrame view state state := ⟨state, rfl, StackFrame.refl state valid, HeapFrame.refl view state⟩

theorem BorrowedFrame.stack (frame : StackFrame before after) (view : View) :
    BorrowedFrame view before after := ⟨before, rfl, frame, HeapFrame.refl view before⟩

theorem BorrowedFrame.valid (frame : BorrowedFrame view before current) : current.valid = true := by
  obtain ⟨_, _, stack, _⟩ := frame
  exact stack.valid

theorem BorrowedFrame.allocate (frame : BorrowedFrame view before current) (type : Ty) (pointer : Value)
    (allocated : allocate current type = .ok (pointer, after)) : BorrowedFrame view before after := by
  obtain ⟨caller, mark, stack, heap⟩ := frame
  exact ⟨caller, mark, stack.allocate type pointer after allocated, heap⟩

theorem BorrowedFrame.store_local (frame : BorrowedFrame view before current)
    (write many : Bool) (child : Ty) (address : Address) (value : Value)
    (fresh : before.nextId ≤ address.allocation)
    (stored : store current (.pointer (.pointer write many child) address) value = .ok after) :
    BorrowedFrame view before after := by
  obtain ⟨caller, mark, stack, heap⟩ := frame
  exact ⟨caller, mark, stack.store_local write many child address value after (by omega) stored, heap⟩

theorem BorrowedFrame.store_word (frame : BorrowedFrame view before current) (index : Nat) (value : BitVec 32)
    (older : view.allocation < before.nextId) (inside : index < view.length)
    (stored : store current (view.pointer index) (number value) = .ok after) :
    BorrowedFrame view before after := by
  obtain ⟨caller, mark, stack, heap⟩ := frame
  obtain ⟨direct, written, next⟩ := stack.store_caller true false word (view.address index)
    (number value) after (by simpa [View.address, mark] using older) stored
  exact ⟨direct, (store_keeps_counters caller _ _ direct written).1.trans mark, next,
    heap.trans (frame_store caller direct view index value inside written).heapFrame⟩

theorem BorrowedFrame.cleanup (frame : BorrowedFrame view before current) :
    HeapFrame view before (Memory.cleanup before.nextId current) := by
  obtain ⟨caller, mark, stack, heap⟩ := frame
  exact heap.heap_eq (by rw [← mark]; exact stack.cleanup_heap)

end Compiler.ZigAir.Memory.WordArray
