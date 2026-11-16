/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemorySlots
import Compiler.ZigAir.MemoryAirLaws

/-! Fault-exclusion forms of memory contracts, suitable for automated matching.
These facts retain access failures as obligations; they do not assume execution
of a whole program succeeds. -/
namespace Compiler.ZigAir.Memory

/-- Keep allocation history available while SSA normalization rewrites its
result values and allocator counters. The equation is recovered by ordinary
theorem application when proving memory obligations. -/
structure AllocationStep (before : State) (type : Ty) (pointer : Value) (after : State) : Prop where
  equation : allocate before type = .ok (pointer, after)

theorem allocation_record (before : State) (type : Ty) (pointer : Value) (after : State)
    (allocated : allocate before type = .ok (pointer, after)) : AllocationStep before type pointer after :=
  ⟨allocated⟩

structure StoreStep (before : State) (pointer value : Value) (after : State) : Prop where
  equation : store before pointer value = .ok after

structure LoadStep (state : State) (pointer value : Value) : Prop where
  equation : load state pointer = .ok value

theorem store_record (before : State) (pointer value : Value) (after : State)
    (stored : store before pointer value = .ok after) : StoreStep before pointer value after := ⟨stored⟩

theorem load_record (state : State) (pointer value : Value)
    (loaded : load state pointer = .ok value) : LoadStep state pointer value := ⟨loaded⟩

theorem LoadStep.readonly (state : State) (many : Bool) (child : Ty) (address : Address) (value : Value)
    (loaded : LoadStep state (.pointer (.pointer true many child) address) value) :
    LoadStep state (.pointer (.pointer false many child) address) value := ⟨loaded.equation⟩

theorem readonly_after_store (before after : State) (write many : Bool) (child : Ty)
    (address : Address) (value : Value)
    (stored : store before (.pointer (.pointer write many child) address) value = .ok after) :
    load after (.pointer (.pointer false false child) address) = .ok value :=
  load_alias_after_store before write many child address value after false false stored

theorem LoadStep.allocated (before after : State) (write many : Bool) (child : Ty) (address : Address)
    (value : Value) (owner : Ty) (pointer : Value)
    (loaded : LoadStep before (.pointer (.pointer write many child) address) value)
    (allocated : AllocationStep before owner pointer after) (apart : address.allocation ≠ before.nextId) :
    LoadStep after (.pointer (.pointer write many child) address) value :=
  ⟨(load_after_allocate before owner pointer after write many child address allocated.equation apart).trans loaded.equation⟩

theorem LoadStep.stored_other (before after : State) (write many : Bool) (child : Ty) (address : Address)
    (value : Value) (write' many' : Bool) (child' : Ty) (address' : Address) (value' : Value)
    (loaded : LoadStep before (.pointer (.pointer write many child) address) value)
    (stored : StoreStep before (.pointer (.pointer write' many' child') address') value' after)
    (apart : address.allocation ≠ address'.allocation) :
    LoadStep after (.pointer (.pointer write many child) address) value :=
  ⟨(load_other_after_store before write' many' child' address' value' after write many child address
    stored.equation apart).trans loaded.equation⟩

grind_pattern LoadStep.readonly => LoadStep state (.pointer (.pointer true many child) address) value
grind_pattern LoadStep.allocated => LoadStep before (.pointer (.pointer write many child) address) value,
  AllocationStep before owner pointer after
grind_pattern LoadStep.stored_other => LoadStep before (.pointer (.pointer write many child) address) value,
  StoreStep before (.pointer (.pointer write' many' child') address') value' after

theorem allocate_pointer_fault (state : State) (write many : Bool) (child : Ty) (fault : Fault)
    (valid : state.valid = true)
    (failed : allocate state (.pointer write many child) = .error fault) : fault = .outOfMemory :=
  allocate_fault_of_layout state _ ⟨8, 8⟩ fault valid rfl failed

theorem fresh_pointer_store_no_fault (state allocated : State) (write many : Bool) (child : Ty)
    (address : Address) (pointer : Value) (fault : Fault)
    (allocation : allocate state (.pointer write many child) = .ok (pointer, allocated))
    (failed : store allocated pointer (.pointer (.pointer write many child) address) = .error fault) : False := by
  obtain ⟨after, stored⟩ := fresh_store_total state allocated
    (.pointer (.pointer write many child) address) pointer ⟨8, 8⟩ rfl rfl (by decide) allocation
  rw [stored] at failed
  contradiction


end Compiler.ZigAir.Memory
