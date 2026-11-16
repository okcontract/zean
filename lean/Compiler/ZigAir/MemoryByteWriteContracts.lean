/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryByteCopyContracts
import Compiler.ZigAir.MemoryVerificationFacts
import Compiler.ZigAir.MemoryRootCapability

namespace Compiler.ZigAir.Memory.ByteArray
variable {write : Bool}
variable {source : View}

/-- Replacing one initialized byte keeps the whole view initialized, with the
new value at exactly that position. Other bytes retain their old contents. -/
theorem Represents.written (represented : Represents before view contents)
    (stored : store before (view.pointer true false index) (number value) = .ok after) :
    Represents after view (fun other => if other = index then value else contents other) := by
  intro other inside
  by_cases same : other = index
  · subst other
    simpa only [View.pointer, ↓reduceIte] using
      load_alias_after_store before true false byte (view.at index) (number value) after false false stored
  · have kept := load_disjoint_after_store before true false byte (view.at index) (number value)
      after false false byte (view.at other).offset stored (by
        simp only [Ty.readOffsets, number, Value.leaves, List.mem_singleton]
        intro position hp entry he
        subst position entry
        simp only [View.at]
        omega)
    simpa only [View.pointer, View.at, ite_eq_right same] using kept.trans (represented other inside)

theorem Represents.stored_other (represented : Represents before view contents)
    (stored : store before (.pointer (.pointer write many child) address) value = .ok after)
    (apart : view.address.allocation ≠ address.allocation) : Represents after view contents := by
  intro index inside
  exact (load_other_after_store before write many child address value after false false byte
    (view.at index) stored apart).trans (represented index inside)

/-- Safe in-place replacement derives the write from geometry and permission;
the source read contract is retained for the following loop iteration. -/
theorem Region.replace (valid : before.valid = true) (cap : Region before view true)
    (represented : Represents before view contents) (inside : index < view.length) (value : BitVec 8) :
    ∃ after, store before (view.pointer true false index) (number value) = .ok after ∧
      after.valid = true ∧ Region after view true ∧
      Represents after view (fun other => if other = index then value else contents other) := by
  obtain ⟨after, stored⟩ := cap.write valid inside value
  exact ⟨after, stored, store_preserves_valid _ _ _ _ valid stored, cap.stored stored,
    represented.written stored⟩

theorem Region.prefix (cap : Region state view write) (bound : count ≤ view.length) :
    Region state ⟨view.address, count⟩ write := by
  obtain ⟨layout, cell, found, shaped, permission, start, size, declared⟩ := cap
  exact ⟨layout, cell, found, shaped, permission, start, by dsimp; omega,
    fun index inside => declared index (by dsimp only at inside; omega)⟩

/-- The write flag affects the resulting pointer, not the validity of selecting
or reading an element. A later store still requires a writable region. -/
theorem Region.select_mutable (valid : state.valid = true) (cap : Region state view write)
    (mutable : Bool) (inside : index < view.length) :
    sliceElementPointer state (view.slice mutable) index = .ok (view.pointer mutable false index) := by
  rw [View.slice, sliceElementPointer_in_bounds _ _ _ _ _ _ (cap.width valid) inside]
  obtain ⟨first, start⟩ := cap.readable.range_access valid (Nat.zero_le _)
  obtain ⟨last, _, _, _, finish⟩ := cap.readable.access valid inside
  have same : last = first := Option.some.inj
    ((access_success_region _ _ _ _ _ finish).1.symm.trans (access_success_region _ _ _ _ _ start).1)
  subst last
  simpa only [View.pointer, View.at, Nat.mul_one] using
    elementPointer_of_access state mutable byte view.address index ⟨1, 1⟩ first rfl (by decide) start
      (by simpa only [View.at, Nat.mul_one] using finish)

theorem Represents.read_mutable (represented : Represents state view contents)
    (mutable : Bool) (inside : index < view.length) :
    load state (view.pointer mutable false index) = .ok (number (contents index)) :=
  represented index inside

theorem Region.selected_mutable
    (observed : sliceElementPointer state (.slice (.slice mutable byte) view.address length) index = outcome)
    (valid : state.valid = true) (cap : Region state view write)
    (same : view.length = length) (inside : index < length) :
    outcome = .ok (view.pointer mutable false index) := by
  subst length
  exact observed.symm.trans (cap.select_mutable valid mutable inside)

theorem Represents.loaded_mutable
    (observed : load state (view.pointer mutable false index) = outcome)
    (represented : Represents state view contents) (inside : index < view.length) :
    outcome = .ok (number (contents index)) :=
  observed.symm.trans (represented.read_mutable mutable inside)

theorem Region.write_no_fault (valid : state.valid = true) (cap : Region state view true)
    (inside : index < view.length)
    (failed : store state (view.pointer true false index) (number value) = .error fault) : False := by
  obtain ⟨after, stored⟩ := cap.write valid inside value
  rw [stored] at failed
  contradiction

theorem number_of_integer (value : Int) (lower : 0 ≤ value) (upper : value < 256) :
    number (BitVec.ofNat 8 value.toNat) = .scalar (.int false 8 value) := by
  have bound : value.toNat < 2 ^ 8 := by omega
  simp only [number, BitVec.toNat_ofNat, Nat.mod_eq_of_lt bound, Int.toNat_of_nonneg lower]

theorem Represents.written_int
    (stored : store before (view.pointer true false index) (.scalar (.int false 8 value)) = .ok after)
    (represented : Represents before view contents)
    (lower : 0 ≤ value) (upper : value < 256) :
    Represents after view (fun other => if other = index then BitVec.ofNat 8 value.toNat else contents other) := by
  apply represented.written
  simpa only [number_of_integer value lower upper] using stored

theorem Region.write_int_no_fault
    (failed : store state (view.pointer true false index) (.scalar (.int false 8 value)) = .error fault)
    (valid : state.valid = true) (cap : Region state view true)
    (inside : index < view.length) (lower : 0 ≤ value) (upper : value < 256)
    : False := by
  apply cap.write_no_fault (value := BitVec.ofNat 8 value.toNat) valid inside
  simpa only [number_of_integer value lower upper] using failed

theorem CopyPost.prefix_region (copied : CopyPost before after target source contents count)
    (inside : count ≤ target.length) : Region after ⟨target.address, count⟩ true :=
  copied.writable.prefix inside

theorem CopyPost.prefix_read (copied : CopyPost before after target source contents count) :
    Represents after ⟨target.address, count⟩ contents := copied.copied

theorem LoadStep.copy_post_other (loaded : LoadStep before (.pointer (.pointer write many child) address) value)
    (copied : CopyPost before after target source contents count)
    (apart : address.allocation ≠ target.address.allocation) :
    LoadStep after (.pointer (.pointer write many child) address) value :=
  ⟨(load_eq_of_lookup before after write many child address (copied.frame.allocations _ apart)).trans loaded.equation⟩

theorem copy_post_root (id : Nat) (cap : RootWritable before type id)
    (copied : CopyPost before after target source contents count)
    (apart : id ≠ target.address.allocation) : RootWritable after type id := by
  obtain ⟨cell, found, typed, writable⟩ := cap
  exact ⟨cell, (copied.frame.allocations id apart).trans found, typed, writable⟩

end Compiler.ZigAir.Memory.ByteArray
