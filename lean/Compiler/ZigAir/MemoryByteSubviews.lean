/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryByteArrayGeometry

namespace Compiler.ZigAir.Memory.ByteArray
variable {write : Bool}

/-- Bridge the signed arithmetic of AIR bounds to a natural slice extent. -/
theorem remaining_bound (count length start : Nat)
    (bound : (count : Int) ≤ (length : Int) - start) : count ≤ length - start := by omega

def View.suffix (view : View) (start : Nat) : View :=
  ⟨view.at start, view.length - start⟩

theorem Region.suffix (cap : Region state view write) (inside : start < view.length) :
    Region state (view.suffix start) write := by
  obtain ⟨layout, cell, found, shaped, permission, lower, upper, declared⟩ := cap
  refine ⟨layout, cell, found, shaped, permission, ?_, ?_, ?_⟩
  · simp only [View.suffix, View.at]; omega
  · simp only [View.suffix, View.at]; omega
  · intro index bound
    have selected := declared (start + index) (by simp only [View.suffix] at bound; omega)
    simpa only [View.suffix, View.at, Nat.add_assoc] using selected

theorem Disjoint.suffix_right (apart : Disjoint source target) (inside : start ≤ target.length) :
    Disjoint source (target.suffix start) := by
  simp only [Disjoint, View.suffix, View.at] at *
  omega

theorem Region.offset_index (valid : state.valid = true) (cap : Region state view write)
    (mutable : Bool) (inside : index < view.length) :
    offsetPointer state false (view.pointer mutable true) index = .ok (view.pointer mutable true index) := by
  have live := cap
  obtain ⟨region, cell, found, shape, _, start, size, _⟩ := cap
  obtain ⟨baseCell, accessed⟩ := live.range_access valid (Nat.zero_le _)
  have atBase := (access_success_region state view.address ⟨0, 1⟩ false baseCell accessed).1
  have same : baseCell = cell := Option.some.inj (atBase.symm.trans found)
  subst baseCell
  obtain ⟨_, positive, layout, shaped, _, bounded, limit⟩ := valid_lookup state _ cell valid found
  cases Option.some.inj (shaped.symm.trans shape)
  have rawBound : ¬((cell.base : Int) + view.address.offset + index < 0 ∨
      (cell.base : Int) + view.address.offset + index ≥ addressLimit) := by omega
  have lower : ¬((cell.base : Int) + view.address.offset + index < cell.base) := by omega
  have offset : ((cell.base : Int) + view.address.offset + index).toNat - cell.base = view.address.offset + index := by omega
  obtain ⟨targetCell, targetAccess⟩ := (live.suffix inside).range_access valid (Nat.zero_le _)
  simp only [View.suffix, View.at] at targetAccess
  simp only [View.pointer, View.at, Nat.add_zero, offsetPointer, Ty.layout, Ty.leafLayout,
    Nat.reduceEqDiff, Bool.false_eq_true, ↓reduceIte, accessed, bind, Except.bind, Nat.mul_one,
    ite_eq_right rawBound, ite_eq_right lower, offset]
  rw [targetAccess]

grind_pattern Region.offset_index => Region state view write,
  offsetPointer state false (view.pointer mutable true) index

theorem Region.offset_selected
    (selected : offsetPointer state false (.pointer (.pointer mutable true byte) view.address) index = .ok value)
    (valid : state.valid = true) (cap : Region state view write)
    (inside : index < view.length) :
    value = .pointer (.pointer mutable true byte) (view.at index) := by
  have exactOffset := cap.offset_index valid mutable inside
  simp only [View.pointer, View.at, Nat.add_zero] at exactOffset
  exact Except.ok.inj (selected.symm.trans exactOffset)

theorem Region.offset_outcome
    (observed : offsetPointer state false (.pointer (.pointer mutable true byte) view.address) index = outcome)
    (valid : state.valid = true) (cap : Region state view write)
    (inside : index < view.length) :
    outcome = .ok (.pointer (.pointer mutable true byte) (view.at index)) := by
  have selected := cap.offset_index valid mutable inside
  simp only [View.pointer, View.at, Nat.add_zero] at selected
  exact observed.symm.trans selected

theorem Region.slice_selected
    (selected : makeSlice state (.slice write byte) (.pointer (.pointer write true byte) view.address) count = .ok value)
    (valid : state.valid = true) (cap : Region state view write) (bound : count ≤ view.length) :
    value = .slice (.slice write byte) view.address count :=
  Except.ok.inj (selected.symm.trans (cap.slice_prefix valid rfl bound))

end Compiler.ZigAir.Memory.ByteArray
