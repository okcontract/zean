/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryByteArray

namespace Compiler.ZigAir.Memory.ByteArray
variable {write : Bool}

theorem Region.readable (cap : Region state view write) : Region state view false := by
  obtain ⟨layout, cell, found, shaped, _, start, bound, declared⟩ := cap
  exact ⟨layout, cell, found, shaped, by simp, start, bound, declared⟩

theorem Region.range_access (valid : state.valid = true) (cap : Region state view write)
    (bound : count ≤ view.length) :
    ∃ cell, Memory.access state view.address ⟨count, 1⟩ false = .ok cell := by
  obtain ⟨cell, accessed, _⟩ := cap.readable.range valid
    (by simpa only [Nat.zero_add] using bound) (.inr rfl)
  exact ⟨cell, by simpa only [View.at, Nat.add_zero] using accessed⟩

theorem Region.offset_zero (valid : state.valid = true) (cap : Region state view write) (mutable : Bool) :
    offsetPointer state false (view.pointer mutable true) 0 = .ok (view.pointer mutable true) := by
  obtain ⟨cell, accessed⟩ := cap.range_access valid (Nat.zero_le _)
  obtain ⟨_, _, _, _, _, pointerBound, _, _, _⟩ := access_success_region _ _ _ _ _ accessed
  have rawBound : ¬((cell.base : Int) + view.address.offset < 0 ∨
      (cell.base : Int) + view.address.offset ≥ addressLimit) := by omega
  have lower : ¬((cell.base : Int) + view.address.offset < cell.base) := by omega
  have offset : ((cell.base : Int) + view.address.offset).toNat - cell.base = view.address.offset := by omega
  simp only [View.pointer, View.at, Nat.add_zero, offsetPointer, Ty.layout, Ty.leafLayout,
    Nat.reduceEqDiff, Bool.false_eq_true, ↓reduceIte, accessed, bind, Except.bind, Nat.zero_mul,
    Int.natCast_zero, Int.add_zero, ite_eq_right rawBound, ite_eq_right lower, offset]

theorem Region.make_slice (valid : state.valid = true) (cap : Region state view write) (mutable : Bool)
    (bound : count ≤ view.length) :
    makeSlice state (.slice mutable byte) (view.pointer mutable true) count =
      .ok (.slice (.slice mutable byte) view.address count) := by
  obtain ⟨cell, accessed⟩ := cap.range_access valid bound
  have width := cap.width valid
  have small : ¬count ≥ addressLimit := by omega
  cases mutable <;>
    simp only [View.pointer, View.at, Nat.add_zero, makeSlice, Bool.not_false, Bool.not_true,
      Bool.false_and, Bool.true_and, Bool.false_eq_true, ne_self_iff_false, or_self, ↓reduceIte,
      ite_eq_right small, Ty.layout, Ty.leafLayout, Nat.reduceEqDiff, Nat.mul_one, accessed, bind, Except.bind]

theorem Represents.stack (represented : Represents before view contents) (frame : StackFrame before after) :
    Represents after view contents :=
  fun index inside => frame.old_load false false byte _ _ (represented index inside)

theorem Region.offset_start (valid : state.valid = true) (cap : Region state view write) :
    offsetPointer state false (.pointer (.pointer write true byte) view.address) 0 =
      .ok (.pointer (.pointer write true byte) view.address) := by
  simpa only [View.pointer, View.at, Nat.add_zero] using cap.offset_zero valid write

theorem Region.slice_prefix (valid : state.valid = true) (cap : Region state view write)
    (same : view.address = address) (bound : count ≤ view.length) :
    makeSlice state (.slice write byte) (.pointer (.pointer write true byte) address) count =
      .ok (.slice (.slice write byte) address count) := by
  subst address
  simpa only [View.pointer, View.at, Nat.add_zero] using cap.make_slice valid write bound

grind_pattern Region.slice_prefix => Region state view write,
  makeSlice state (.slice write byte) (.pointer (.pointer write true byte) address) count

theorem copy_no_fault (valid : state.valid = true) (readable : Region state source false)
    (writable : Region state target true) (represented : Represents state source contents)
    (sourceAddress : source.address = input) (targetAddress : target.address = output)
    (separate : Disjoint source target) (readBound : count ≤ source.length) (writeBound : count ≤ target.length)
    (failed : ByteRange.copy state (.slice (.slice true byte) output count)
      (.pointer (.pointer false true byte) input) = (.error fault, after)) : False := by
  subst input output
  obtain ⟨_, copied, _⟩ := copy_safe valid readable writable represented separate readBound writeBound
  simp only [View.pointer, View.at, Nat.add_zero] at copied
  rw [copied] at failed
  cases failed

grind_pattern copy_no_fault => Region state source false, Region state target true,
  Represents state source contents,
  ByteRange.copy state (.slice (.slice true byte) output count)
    (.pointer (.pointer false true byte) input),
  ((.error fault, after) : Except Fault Unit × State)

end Compiler.ZigAir.Memory.ByteArray
