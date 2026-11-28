/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.Verify.Core
import Compiler.ZigAir.MemoryByteCopyAutomation
import Compiler.ZigAir.MemoryByteReadAutomation
import Compiler.ZigAir.MemoryByteFields
import Compiler.ZigAir.MemoryByteMoveContracts

/-! Optional initialized byte-region, copy, and move contracts, including declared
byte fields inside a complete record. -/

namespace Compiler.ZigAir.Memory.ByteArray

def View.window (v : View) (start count : Nat) : View := ⟨v.at start, count⟩

/-- Premises for a nonempty initialized copy between two slice windows.
The initialization and separation obligations apply only to the selected bytes. -/
structure CopyRanges (s : State) (dst src : View) (atDst atSrc count : Nat)
    (contents : Nat → BitVec 8) : Prop where
  writable : Region s dst true
  readable : Region s src false
  dstBound : atDst + count ≤ dst.length
  srcBound : atSrc + count ≤ src.length
  initialized : Represents s (src.window atSrc count) contents
  disjoint : Disjoint (src.window atSrc count) (dst.window atDst count)

theorem Region.window {write : Bool} (h : Region s v write) (inside : start < v.length) (bound : start + count ≤ v.length) :
    Region s (v.window start count) write := by
  obtain ⟨layout, cell, found, shape, permission, low, high, declared⟩ := h
  refine ⟨layout, cell, found, shape, permission, ?_, ?_, ?_⟩
  · simp only [View.window, View.at]; omega
  · simp only [View.window, View.at]; omega
  · intro i hi
    have byte := declared (start+i) (by change i < count at hi; omega)
    simpa only [View.window, View.at, Nat.add_assoc] using byte

/-- The byte transfer for a bounded, initialized source window. All addresses
and offsets are expressed as views. The frame covers every read outside the
selected destination, including the remainder of the same allocation. -/
theorem CopyRanges.copy (ranges : CopyRanges s dst src atDst atSrc count contents)
    (valid : s.valid = true) (nonempty : 0 < count) :
    let d := dst.window atDst count
    let r := src.window atSrc count
    ∃ after_, ByteRange.copy s (d.slice true) (r.pointer false true) = (.ok (), after_) ∧
      after_.valid = true ∧ Represents after_ d contents ∧ HeapFrame d s after_ := by
  have db := ranges.dstBound
  have sb := ranges.srcBound
  obtain ⟨after_, ran, safe, _, _, _, filled, frame⟩ := copy_refines valid
    (ranges.readable.window (by omega) sb) (ranges.writable.window (by omega) db)
    ranges.initialized ranges.disjoint (count := count) (Nat.le_refl _) (Nat.le_refl _)
  exact ⟨after_,ran,safe,filled,frame⟩

/-- Split a source-level copy contract into named premises and discharge facts
already in scope. Missing premises retain their field names in the goal view. -/
macro "air_copy_ranges" : tactic => `(tactic|
  (apply CopyRanges.mk <;> first | assumption | omega | skip))

end Compiler.ZigAir.Memory.ByteArray
