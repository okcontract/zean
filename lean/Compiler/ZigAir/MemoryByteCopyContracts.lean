/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryByteArrayGeometry
import Compiler.ZigAir.MemoryFrameVerification
import Compiler.ZigAir.MemoryInvalidationFrame

/-! Byte-copy contents and framing. Read observations outside the written range
retain both values and faults. Invocation-local allocation is handled separately
from the byte writes; allocator history is never rewound. -/
namespace Compiler.ZigAir.Memory.ByteArray
variable {write : Bool}

def Prefix (state : State) (target : View) (contents : Nat → BitVec 8) (count : Nat) : Prop :=
  ∀ index < count, load state (target.pointer false false index) = .ok (number (contents index))

def Outside (target : View) (position : Nat) : Prop :=
  position < target.address.offset ∨ target.address.offset + target.length ≤ position

structure HeapFrame (target : View) (before after : State) : Prop where
  allocations : ∀ id, id ≠ target.address.allocation → after.heap.lookup id = before.heap.lookup id
  outside : ∀ (child : Ty) (offset : Nat) (write many : Bool),
    (∀ position ∈ child.readOffsets offset, Outside target position) →
    load after (.pointer (.pointer write many child) ⟨target.address.allocation, offset⟩) =
      load before (.pointer (.pointer write many child) ⟨target.address.allocation, offset⟩)

theorem HeapFrame.refl (target : View) (state : State) : HeapFrame target state state :=
  ⟨fun _ _ => rfl, fun _ _ _ _ _ => rfl⟩

theorem HeapFrame.trans (first : HeapFrame target before middle) (second : HeapFrame target middle after) :
    HeapFrame target before after :=
  ⟨fun id apart => (second.allocations id apart).trans (first.allocations id apart),
    fun child offset write many outside =>
      (second.outside child offset write many outside).trans (first.outside child offset write many outside)⟩

theorem HeapFrame.heap_eq (frame : HeapFrame target before middle) (same : after.heap = middle.heap) :
    HeapFrame target before after := by
  refine ⟨fun id apart => by rw [same]; exact frame.allocations id apart, ?_⟩
  intro child offset write many outside
  exact (load_eq_of_lookup middle after write many child _ (by rw [same])).trans
    (frame.outside child offset write many outside)

theorem frame_store (inside : index < target.length)
    (stored : store before (target.pointer true false index) (number value) = .ok after) :
    HeapFrame target before after := by
  refine ⟨heap_after_store_other before true false byte (target.at index) (number value) after stored, ?_⟩
  intro child offset write many outside
  apply load_disjoint_after_store before true false byte (target.at index) (number value) after write many child offset stored
  intro position member entry present
  have away := outside position member
  simp only [number, Value.leaves, List.mem_singleton] at present
  subst entry
  simp only [Outside, View.at] at *
  omega

theorem frame_invalidate (inside : index < target.length)
    (forgotten : invalidate before true byte (target.at index) = .ok after) :
    HeapFrame target before after := by
  refine ⟨(invalidate_frame before true byte (target.at index) after forgotten).2.2, ?_⟩
  intro child offset write many outside
  apply load_disjoint_after_invalidate before after true byte (target.at index) ⟨1, 1⟩
    write many child offset rfl forgotten
  intro position member
  have away := outside position member
  simp only [Outside, View.at] at *
  omega

theorem Prefix.stored (filled : Prefix before target contents index)
    (stored : store before (target.pointer true false index) (number (contents index)) = .ok after) :
    Prefix after target contents (index + 1) := by
  intro other inside
  by_cases same : other = index
  · subst other
    exact load_alias_after_store before true false byte (target.at index) (number (contents index)) after false false stored
  · have old := filled other (by omega)
    have kept := load_disjoint_after_store before true false byte (target.at index) (number (contents index))
      after false false byte (target.at other).offset stored (by
        simp only [Ty.readOffsets, number, Value.leaves, List.mem_singleton]
        intro position hp entry he
        subst position entry
        simp only [View.at]
        omega)
    exact kept.trans old

theorem Prefix.cleanup (filled : Prefix state target contents count) (older : target.address.allocation < mark) :
    Prefix (Memory.cleanup mark state) target contents count := by
  intro index inside
  exact (load_eq_of_lookup state (Memory.cleanup mark state) false false byte (target.at index)
    (cleanup_lookup_older state mark target.address.allocation older)).trans (filled index inside)

theorem Prefix.represents (filled : Prefix state target contents count) :
    Represents state ⟨target.address, count⟩ contents := filled

set_option maxRecDepth 4096 in
theorem copyLoop_refines (valid : state.valid = true) (readable : Region state source false)
    (writable : Region state target true) (represented : Represents state source contents)
    (separate : Disjoint source target) (readBound : index + count ≤ source.length)
    (writeBound : index + count ≤ target.length) (prior : Prefix state target contents index) :
    ∃ after, ByteRange.copyLoop state source.address target.address index count = (.ok (), after) ∧
      after.valid = true ∧ Region after source false ∧ Region after target true ∧
      Represents after source contents ∧ Prefix after target contents (index + count) ∧
      HeapFrame ⟨target.address, index + count⟩ state after := by
  induction count generalizing state index with
  | zero => exact ⟨state, rfl, valid, readable, writable, represented, prior, HeapFrame.refl _ _⟩
  | succ count ih =>
    have read := represented.readByte valid readable (by omega : index < source.length)
    obtain ⟨middle, stored⟩ := writable.write valid (by omega : index < target.length) (contents index)
    have copied : ByteRange.copyByte state source.address target.address index = .ok middle := by
      rw [ByteRange.copyByte_initialized read]
      exact stored
    obtain ⟨after, complete, safe, sourceLive, targetLive, kept, filled, frame⟩ := ih (index := index + 1)
      (store_preserves_valid _ _ _ _ valid stored) (readable.stored stored) (writable.stored stored)
      (represented.stored separate (by omega) stored) (by omega) (by omega) (prior.stored stored)
    have first : HeapFrame ⟨target.address, index + (count + 1)⟩ state middle :=
      frame_store (by dsimp; omega) stored
    exact ⟨after, by simp only [ByteRange.copyLoop, copied, complete], safe, sourceLive, targetLive,
      kept, by simpa only [Nat.add_assoc, Nat.add_comm 1 count] using filled,
      first.trans (by simpa only [Nat.add_assoc, Nat.add_comm 1 count] using frame)⟩

theorem copy_refines (valid : state.valid = true) (readable : Region state source false)
    (writable : Region state target true) (represented : Represents state source contents)
    (separate : Disjoint source target) (readBound : count ≤ source.length) (writeBound : count ≤ target.length) :
    ∃ after, ByteRange.copy state (.slice (.slice true byte) target.address count)
      (source.pointer false true) = (.ok (), after) ∧
      after.valid = true ∧ Region after source false ∧ Region after target true ∧
      Represents after source contents ∧ Prefix after target contents count ∧
      HeapFrame ⟨target.address, count⟩ state after := by
  have apart : ¬(count > 0 ∧ source.address.allocation = target.address.allocation ∧
      source.address.offset < target.address.offset + count ∧ target.address.offset < source.address.offset + count) := by
    simp only [Disjoint] at separate
    omega
  simpa only [ByteRange.copy, ByteRange.destination, ByteRange.source, View.pointer, View.at,
    Nat.add_zero, Nat.zero_add, ite_eq_right apart] using
    copyLoop_refines valid readable writable represented separate (by omega : 0 + count ≤ source.length)
      (by omega : 0 + count ≤ target.length) (fun _ h => by omega)

def BorrowedFrame (target : View) (before current : State) : Prop :=
  ∃ caller, caller.nextId = before.nextId ∧ StackFrame caller current ∧ HeapFrame target before caller

theorem BorrowedFrame.stack (frame : StackFrame before after) (target : View) :
    BorrowedFrame target before after := ⟨before, rfl, frame, HeapFrame.refl target before⟩

theorem BorrowedFrame.store_byte (frame : BorrowedFrame target before current) (index : Nat) (value : BitVec 8)
    (older : target.address.allocation < before.nextId) (inside : index < target.length)
    (stored : store current (target.pointer true false index) (number value) = .ok after) :
    BorrowedFrame target before after := by
  obtain ⟨caller, mark, stack, heap⟩ := frame
  obtain ⟨direct, written, next⟩ := stack.store_caller true false byte (target.at index) (number value) after
    (by simpa [View.at, mark] using older) stored
  exact ⟨direct, (store_keeps_counters caller _ _ direct written).1.trans mark, next,
    heap.trans (frame_store inside written)⟩

theorem BorrowedFrame.invalidate_byte (frame : BorrowedFrame target before current)
    (index : Nat) (older : target.address.allocation < before.nextId) (inside : index < target.length)
    (forgotten : invalidate current true byte (target.at index) = .ok after) :
    BorrowedFrame target before after := by
  obtain ⟨caller, mark, stack, heap⟩ := frame
  obtain ⟨direct, erased, next⟩ := stack.invalidate_caller byte (target.at index) after
    (by simpa [View.at, mark] using older) forgotten
  exact ⟨direct, (invalidate_frame caller true byte (target.at index) direct erased).1.trans mark, next,
    heap.trans (frame_invalidate inside erased)⟩

theorem BorrowedFrame.cleanup (frame : BorrowedFrame target before current) :
    HeapFrame target before (Memory.cleanup before.nextId current) := by
  obtain ⟨caller, mark, stack, heap⟩ := frame
  exact heap.heap_eq (by rw [← mark]; exact stack.cleanup_heap)

theorem BorrowedFrame.copyLoop (frame : BorrowedFrame target before current)
    (older : target.address.allocation < before.nextId) (inside : index + count ≤ target.length)
    (ran : ByteRange.copyLoop current source target.address index count = (.ok (), after)) :
    BorrowedFrame target before after := by
  induction count generalizing current index with
  | zero => cases Prod.mk.inj ran |>.2; exact frame
  | succ count ih =>
    cases copied : ByteRange.copyByte current source target.address index with
    | error fault => simp only [ByteRange.copyLoop, copied] at ran; cases Prod.mk.inj ran |>.1
    | ok middle =>
      simp only [ByteRange.copyLoop, copied] at ran
      rcases ByteRange.copyByte_success copied with ⟨value, _, stored⟩ | ⟨_, forgotten⟩
      · exact ih (frame.store_byte index value older (by omega) stored) (by omega) ran
      · exact ih (frame.invalidate_byte index older (by omega) forgotten) (by omega) ran

theorem BorrowedFrame.copy (frame : StackFrame before current)
    (older : target.allocation < before.nextId)
    (ran : ByteRange.copy current (.slice (.slice true byte) target count)
      (.pointer (.pointer false true byte) source) = (.ok (), after)) :
    HeapFrame ⟨target, count⟩ before (Memory.cleanup before.nextId after) := by
  simp only [ByteRange.copy, ByteRange.destination, ByteRange.source] at ran
  split at ran
  · cases Prod.mk.inj ran |>.1
  · exact ((BorrowedFrame.stack frame ⟨target, count⟩).copyLoop older (by dsimp; omega) ran).cleanup

theorem Region.older (region : Region state view write) (valid : state.valid = true) :
    view.address.allocation < state.nextId := by
  obtain ⟨_, cell, found, _⟩ := region
  exact (valid_lookup state _ cell valid found).1

theorem Region.cleanup (region : Region state view write) (older : view.address.allocation < mark) :
    Region (Memory.cleanup mark state) view write := by
  obtain ⟨extent, cell, found, rest⟩ := region
  exact ⟨extent, cell, (cleanup_lookup_older state mark _ older).trans found, rest⟩

theorem Represents.cleanup (represented : Represents state view contents) (older : view.address.allocation < mark) :
    Represents (Memory.cleanup mark state) view contents := by
  intro index inside
  exact (load_eq_of_lookup state (Memory.cleanup mark state) false false byte (view.at index)
    (cleanup_lookup_older state mark _ older)).trans (represented index inside)

/-- Successful copy initializes the exact destination prefix, retains source
contents and permissions, and preserves all observations outside that prefix. -/
structure CopyPost (before after : State) (target source : View) (contents : Nat → BitVec 8) (count : Nat) : Prop where
  valid : after.valid = true
  writable : Region after target true
  readable : Region after source false
  copied : Prefix after target contents count
  source : Represents after source contents
  frame : HeapFrame ⟨target.address, count⟩ before after

theorem copy_post (frame : StackFrame before current) (writable : Region before target true)
    (readable : Region before source false) (represented : Represents before source contents)
    (separate : Disjoint source target) (readBound : count ≤ source.length) (writeBound : count ≤ target.length)
    (targetAddress : target.address = output) (sourceAddress : source.address = input)
    (ran : ByteRange.copy current (.slice (.slice true byte) output count)
      (.pointer (.pointer false true byte) input) = (.ok (), after)) :
    CopyPost before (Memory.cleanup before.nextId after) target source contents count := by
  subst output input
  obtain ⟨last, copied, valid, sourceLive, targetLive, kept, filled, _⟩ :=
    copy_refines frame.valid (readable.stack frame) (writable.stack frame) (represented.stack frame)
      separate readBound writeBound
  have same := Prod.mk.inj (copied.symm.trans ran) |>.2
  subst last
  have targetOld := writable.older frame.initial
  have sourceOld := readable.older frame.initial
  exact ⟨cleanup_preserves_valid _ _ valid, targetLive.cleanup targetOld, sourceLive.cleanup sourceOld,
    filled.cleanup targetOld, kept.cleanup sourceOld, BorrowedFrame.copy frame targetOld ran⟩

grind_pattern copy_post => StackFrame before current, Region before target true,
  Region before source false, Represents before source contents,
  ByteRange.copy current (.slice (.slice true byte) output count)
    (.pointer (.pointer false true byte) input), ((.ok (), after) : Except Fault Unit × State)

end Compiler.ZigAir.Memory.ByteArray
