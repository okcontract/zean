/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryReadTyping
import Compiler.ZigAir.MemorySliceElements
import Compiler.ZigAir.MemoryStackFrame

/-! Initialized readonly views of arbitrary supported element types. Contents
are ordinary load assertions; bounds for constructing and selecting slices are
derived from them. No program identity or successful invocation is assumed. -/
namespace Compiler.ZigAir.Memory

structure ReadView where
  child : Ty
  layout : Layout
  shaped : child.layout = some layout
  positive : 0 < layout.bytes
  address : Address
  length : Nat

namespace ReadView

def addressAt (view : ReadView) (index : Nat) : Address :=
  ⟨view.address.allocation, view.address.offset + index * view.layout.bytes⟩
def pointer (view : ReadView) (index : Nat) : Value :=
  .pointer (.pointer false false view.child) (view.addressAt index)
def buffer (view : ReadView) : Value := .pointer (.pointer false true view.child) view.address
def slice (view : ReadView) : Value := .slice (.slice false view.child) view.address view.length
def Represents (state : State) (view : ReadView) (values : Nat → Value) : Prop :=
  ∀ index < view.length, load state (view.pointer index) = .ok (values index)

theorem Represents.read (cap : Represents state view values) (index : Nat) (inside : index < view.length) :
    load state (view.pointer index) = .ok (values index) := cap index inside

theorem Represents.stack (frame : StackFrame before after) (cap : Represents before view values) :
    Represents after view values :=
  fun index inside => frame.old_load false false view.child _ _ (cap index inside)

theorem Represents.checked_access (cap : Represents state view values) (index : Nat) (inside : index < view.length) :
    ∃ cell, access state (view.addressAt index) view.layout false = .ok cell := by
  have loaded := cap index inside
  cases checked : access state (view.addressAt index) view.layout false with
  | error fault => simp [pointer, load, view.shaped, checked, bind, Except.bind] at loaded
  | ok cell => exact ⟨cell, rfl⟩

theorem Represents.element (cap : Represents state view values) (index : Nat) (inside : index < view.length) :
    elementPointer state view.buffer index = .ok (view.pointer index) := by
  obtain ⟨first, start⟩ := cap.checked_access 0 (by omega)
  obtain ⟨last, finish⟩ := cap.checked_access index inside
  have firstFound := (access_success_region _ _ _ _ _ start).1
  have lastFound := (access_success_region _ _ _ _ _ finish).1
  have same : last = first := Option.some.inj (lastFound.symm.trans firstFound)
  subst last
  have narrow := access_narrow _ _ _ 0 false _ start (by omega)
  simpa only [buffer, pointer, addressAt, Nat.zero_mul, Nat.add_zero] using
    elementPointer_of_access state false view.child view.address index view.layout first
      view.shaped view.positive (by simpa [addressAt] using narrow) finish

theorem Represents.offset_zero (cap : Represents state view values) (positive : 0 < view.length) :
    offsetPointer state false view.buffer 0 = .ok view.buffer := by
  have element := cap.element 0 positive
  cases moved : offsetPointer state false view.buffer 0 with
  | error fault =>
    simp only [elementPointer, buffer] at element
    rw [show offsetPointer state false (.pointer (.pointer false true view.child) view.address) 0 =
      .error fault from moved] at element
    cases element
  | ok shifted =>
    obtain ⟨layout, _, _, position⟩ :=
      offsetPointer_add_address state false view.child view.address 0 shifted moved
    simpa only [Nat.zero_mul, Nat.add_zero, buffer] using congrArg Except.ok position

theorem Represents.region (cap : Represents state view values) (positive : 0 < view.length) :
    ∃ cell, access state view.address ⟨view.length * view.layout.bytes, view.layout.alignment⟩ false = .ok cell := by
  obtain ⟨first, start⟩ := cap.checked_access 0 positive
  obtain ⟨last, finish⟩ := cap.checked_access (view.length - 1) (by omega)
  obtain ⟨found, region, shape, base, limit, addressBound, _, aligned, _⟩ :=
    access_success_region _ _ _ _ _ start
  obtain ⟨foundLast, lastRegion, lastShape, _, _, _, extent, _, _⟩ :=
    access_success_region _ _ _ _ _ finish
  have same : last = first := Option.some.inj (foundLast.symm.trans found)
  subst last
  have sameRegion : lastRegion = region := Option.some.inj (lastShape.symm.trans shape)
  subst lastRegion
  simp only [addressAt, Nat.zero_mul, Nat.add_zero] at found addressBound aligned extent
  have endEq : (view.length - 1) * view.layout.bytes + view.layout.bytes = view.length * view.layout.bytes := by
    calc
      _ = ((view.length - 1) + 1) * view.layout.bytes := by simp [Nat.add_mul]
      _ = _ := by rw [Nat.sub_add_cancel (by omega)]
  have checks : ¬(first.base = 0 ∨ first.base + region.bytes > addressLimit ∨
      first.base + view.address.offset ≥ addressLimit ∨
      view.address.offset + view.length * view.layout.bytes > region.bytes ∨
      (first.base + view.address.offset) % view.layout.alignment ≠ 0) := by omega
  exact ⟨first, by simp only [access, found, shape, Bool.false_and, Bool.false_eq_true,
    ↓reduceIte, ite_eq_right checks]⟩

theorem Represents.make_slice (cap : Represents state view values) (positive : 0 < view.length)
    (width : view.length < addressLimit) :
    makeSlice state (.slice false view.child) view.buffer view.length = .ok view.slice := by
  obtain ⟨cell, region⟩ := cap.region positive
  have nonzero : view.layout.bytes ≠ 0 := by have := view.positive; omega
  simp only [makeSlice, buffer, slice, ne_self_iff_false, Bool.false_and, Bool.false_eq_true,
    or_self, ↓reduceIte, Nat.not_le.mpr width, view.shaped, nonzero, region, bind, Except.bind]

theorem Represents.slice_element (cap : Represents state view values) (index : Nat)
    (width : view.length < addressLimit) (inside : index < view.length) :
    sliceElementPointer state view.slice index = .ok (view.pointer index) := by
  rw [slice, sliceElementPointer_in_bounds _ _ _ _ _ _ width inside]
  exact cap.element index inside

theorem Represents.typed (cap : Represents state view values) (index : Nat) (inside : index < view.length) :
    (values index).hasType view.child = true :=
  load_hasType state false false view.child (view.addressAt index) _ (cap index inside)

grind_pattern Represents.offset_zero => Represents state view values
grind_pattern Represents.make_slice => Represents state view values
grind_pattern Represents.slice_element => Represents state view values,
  sliceElementPointer state (.slice (.slice false view.child) view.address view.length) index
grind_pattern Represents.read => Represents state view values, load state (view.pointer index)
grind_pattern Represents.typed => Represents state view values, load state (view.pointer index)

end ReadView
end Compiler.ZigAir.Memory
