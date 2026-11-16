/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryRecordWrites
import Compiler.ZigAir.MemoryRootCapability

namespace Compiler.ZigAir.Memory

/-- Static, checked geometry for a scalar field. The record instance and its
permission are supplied separately by `RootWritable`. -/
def ScalarField (owner : Ty) (offset : Nat) (child : Scalar.Ty) : Prop :=
  ∃ parent region : Layout, owner.layout = some parent ∧ 0 < parent.bytes ∧
    (Ty.scalar child).layout = some region ∧ 0 < region.bytes ∧
    offset + region.bytes ≤ parent.bytes ∧ offset % region.alignment = 0 ∧
    parent.alignment % region.alignment = 0 ∧
    acceptsView owner offset (.scalar child) = true ∧ leafType owner offset = some (.scalar child)

/-- A field-write contract is derived from a live writable parent, the captured
field geometry and a typed value. It does not require initialized destination
bytes or assume that the store succeeds. -/
theorem RootWritable.scalar_field_store (state : State) (owner : Ty) (id offset : Nat)
    (child : Scalar.Ty) (value : Scalar.Value) (parent region : Layout)
    (valid : state.valid = true) (cap : RootWritable state owner id)
    (typed : (.scalar value : Value).hasType (.scalar child) = true)
    (parentShape : owner.layout = some parent) (parentPositive : 0 < parent.bytes)
    (childShape : (Ty.scalar child).layout = some region) (childPositive : 0 < region.bytes)
    (inside : offset + region.bytes ≤ parent.bytes) (aligned : offset % region.alignment = 0)
    (divided : parent.alignment % region.alignment = 0)
    (view : acceptsView owner offset (.scalar child) = true)
    (declared : leafType owner offset = some (.scalar child)) :
    ∃ after, store state (.pointer (.pointer true false (.scalar child)) ⟨id, offset⟩)
      (.scalar value) = .ok after := by
  have same : (Value.scalar value).type = .scalar child :=
    of_decide_eq_true (Bool.and_eq_true_iff.mp typed).1
  obtain ⟨cell, found, ownerType, writable⟩ := cap
  have accessed := root_access state id cell parent true valid found (ownerType ▸ parentShape)
    parentPositive (fun _ => writable)
  have field := access_subregion state ⟨id, 0⟩ parent region offset true cell accessed
    childPositive inside aligned divided
  simpa only [same, Nat.zero_add] using
    store_subobject_total state ⟨id, offset⟩ region cell (.scalar value)
      (MemoryAir.value_valid_of_hasType _ _ typed) (same ▸ childShape)
      (by simpa only [Nat.zero_add] using field)
      (by simpa only [ownerType, same] using view)
      (by
        intro entry present
        simp only [Value.leaves, List.mem_singleton] at present
        subst entry
        simpa only [Nat.add_zero, ownerType, same] using declared)

theorem ScalarField.store_total (geometry : ScalarField owner offset child)
    (valid : state.valid = true) (cap : RootWritable state owner objectId)
    (typed : value.hasType (.scalar child) = true) :
    ∃ after, store state (.pointer (.pointer true false (.scalar child)) ⟨objectId, offset⟩) value = .ok after := by
  have same : value.type = .scalar child := of_decide_eq_true (Bool.and_eq_true_iff.mp typed).1
  cases value with
  | scalar value =>
    obtain ⟨parent, region, parentShape, parentPositive, childShape, childPositive,
      inside, aligned, divided, view, declared⟩ := geometry
    exact cap.scalar_field_store state owner objectId offset child value parent region valid typed
      parentShape parentPositive childShape childPositive inside aligned divided view declared
  | optionalScalar | optionalObject => simp [Value.type] at same
  | pointer type address =>
    change type = .scalar child at same
    subst type
    simp [Value.hasType, Value.valid] at typed
  | slice type address length =>
    change type = .scalar child at same
    subst type
    simp [Value.hasType, Value.valid] at typed

theorem ScalarField.store_no_fault (geometry : ScalarField owner offset child)
    (valid : state.valid = true) (cap : RootWritable state owner objectId)
    (typed : value.hasType (.scalar child) = true)
    (failed : store state (.pointer (.pointer true false (.scalar child)) ⟨objectId, offset⟩) value = .error fault) : False := by
  obtain ⟨after, stored⟩ := geometry.store_total valid cap typed
  rw [stored] at failed
  contradiction

grind_pattern ScalarField.store_no_fault => ScalarField owner offset child, RootWritable state owner objectId,
  store state (.pointer (.pointer true false (.scalar child)) ⟨objectId, offset⟩) value,
  (Except.error fault : Except Fault State)

end Compiler.ZigAir.Memory
