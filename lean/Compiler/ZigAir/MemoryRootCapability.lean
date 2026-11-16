/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryVerificationFacts
import Compiler.ZigAir.MemoryFrameVerification

/-! A writable root-object capability survives writes to any allocation.
Initialization is a separate load assertion; possession of this capability
alone never licenses a read. -/
namespace Compiler.ZigAir.Memory

def RootWritable (state : State) (type : Ty) (id : Nat) : Prop :=
  ∃ cell, state.heap.lookup id = some cell ∧ cell.type = type ∧ cell.writable = true

/-- A live object predates the next fresh lifetime identity. -/
theorem RootWritable.older {id : Nat} (cap : RootWritable state type id) (valid : state.valid = true) :
    id < state.nextId := by
  obtain ⟨cell, found, _, _⟩ := cap
  exact (valid_lookup state id cell valid found).1

theorem RootWritable.allocated (state after : State) (type : Ty) (pointer : Value)
    (allocated : allocate state type = .ok (pointer, after)) : RootWritable after type state.nextId := by
  obtain ⟨_, base, _, _, rfl⟩ := allocate_shape state type pointer after allocated
  exact ⟨⟨base, type, [], true, true⟩, by simp [Heap.lookup_cons], rfl, rfl⟩

theorem RootWritable.stored (state after : State) (type : Ty) (id : Nat) (pointer value : Value)
    (cap : RootWritable state type id) (stored : store state pointer value = .ok after) :
    RootWritable after type id := by
  obtain ⟨cell, found, typed, writable⟩ := cap
  obtain ⟨_, _, address, layout, target, contents, _, _, _, accessed, _, rfl⟩ :=
    store_success state pointer value after stored
  have targetFound := (access_success_region state address layout true target accessed).1
  by_cases alias : id = address.allocation
  · have same : cell = target := Option.some.inj (found.symm.trans (alias ▸ targetFound))
    subst target
    exact ⟨{ cell with cells := contents }, by
      simpa only [alias] using Heap.lookup_replace state.heap address.allocation cell _ targetFound,
      typed, writable⟩
  · exact ⟨cell, (replace_other state.heap address.allocation id _ alias).trans found, typed, writable⟩

theorem RootWritable.stack (frame : StackFrame before after) (type : Ty) (id : Nat)
    (cap : RootWritable before type id) : RootWritable after type id := by
  obtain ⟨cell, found, typed, writable⟩ := cap
  exact ⟨cell, frame.old_lookup id cell found, typed, writable⟩

theorem RootWritable.after_allocate (state after : State) (type owner : Ty) (id : Nat) (pointer : Value)
    (valid : state.valid = true) (cap : RootWritable state type id)
    (allocated : allocate state owner = .ok (pointer, after)) : RootWritable after type id :=
  cap.stack ((StackFrame.refl state valid).allocate owner pointer after allocated) type id

theorem RootWritable.store_total (state : State) (type : Ty) (id : Nat) (value : Value) (layout : Layout)
    (valid : state.valid = true) (cap : RootWritable state type id) (typed : value.hasType type = true)
    (shaped : type.layout = some layout) (positive : 0 < layout.bytes) :
    ∃ after, store state (.pointer (.pointer true false type) ⟨id, 0⟩) value = .ok after := by
  have same : value.type = type := of_decide_eq_true (Bool.and_eq_true_iff.mp typed).1
  obtain ⟨cell, found, cellType, writable⟩ := cap
  simpa only [same] using root_store_total state id cell value layout valid found
    (cellType.trans same.symm) writable (MemoryAir.value_valid_of_hasType value type typed)
    (same ▸ shaped) positive

theorem RootWritable.store_no_fault (state : State) (type : Ty) (id : Nat) (value : Value)
    (layout : Layout) (fault : Fault) (valid : state.valid = true) (cap : RootWritable state type id)
    (typed : value.hasType type = true) (shaped : type.layout = some layout) (positive : 0 < layout.bytes)
    (failed : store state (.pointer (.pointer true false type) ⟨id, 0⟩) value = .error fault) : False := by
  obtain ⟨after, stored⟩ := cap.store_total state type id value layout valid typed shaped positive
  rw [stored] at failed
  contradiction

theorem allocate_usize_fault (state : State) (fault : Fault) (valid : state.valid = true)
    (failed : allocate state usize = .error fault) : fault = .outOfMemory :=
  allocate_fault_of_layout state usize ⟨8, 8⟩ fault valid rfl failed

theorem RootWritable.usize_store_no_fault (state : State) (id : Nat) (value : Value) (fault : Fault)
    (valid : state.valid = true) (cap : RootWritable state usize id) (typed : value.hasType usize = true)
    (failed : store state (.pointer (.pointer true false usize) ⟨id, 0⟩) value = .error fault) : False :=
  cap.store_no_fault state usize id value ⟨8, 8⟩ fault valid typed rfl (by decide) failed

end Compiler.ZigAir.Memory
