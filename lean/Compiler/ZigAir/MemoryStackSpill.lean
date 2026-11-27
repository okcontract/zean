/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryResources
import Compiler.ZigAir.MemoryRootCapability
import Compiler.ZigAir.MemorySlots

namespace Compiler.ZigAir.Memory

abbrev stackSlot (write : Bool) (child : Ty) (id : Nat) : Value :=
  .pointer (.pointer write false child) ⟨id, 0⟩

/-- Effects of a compiler spill to a new typed stack slot. The read-only
view can recover the saved value while the caller heap stays unchanged. -/
structure StackSpill (before allocated saved : State) (value : Value) : Prop where
  alloc : allocate before value.type = .ok (stackSlot true value.type before.nextId, allocated)
  store : store allocated (stackSlot true value.type before.nextId) value = .ok saved
  cast : pointerCast saved (.pointer false false value.type) (stackSlot true value.type before.nextId) =
    .ok (stackSlot false value.type before.nextId)
  load : load saved (stackSlot false value.type before.nextId) = .ok value
  frame : StackFrame before saved

theorem StackSpill.writable (savedSlot : StackSpill before allocated saved value) :
    RootWritable saved value.type before.nextId :=
  RootWritable.stored _ _ _ _ _ _ (RootWritable.allocated _ _ _ _ savedSlot.alloc) savedSlot.store

theorem spill (state : State) (value : Value) (layout : Layout)
    (valid : state.valid = true) (typed : value.valid = true) (shaped : value.type.layout = some layout)
    (nonempty : 0 < layout.bytes) (positive : 0 < state.nextAddress)
    (room : state.nextAddress + (layout.alignment - 1) + layout.bytes < addressLimit) :
    ∃ allocated saved, StackSpill state allocated saved value ∧ state.nextAddress ≤ saved.nextAddress ∧
      saved.nextAddress ≤ state.nextAddress + (layout.alignment - 1) + layout.bytes := by
  obtain ⟨pointer, allocated, allocation⟩ := allocate_total state value.type valid
    (AllocationRoom.of_budget _ _ _ shaped positive (layout_alignment_positive _ _ shaped) room)
  obtain ⟨rfl, _⟩ := allocate_pointer _ _ _ _ allocation
  obtain ⟨saved, stored⟩ := fresh_store_total state allocated value _ layout typed shaped nonempty allocation
  have frame := ((StackFrame.refl state valid).allocate _ _ _ allocation).store_local
    _ _ _ _ _ _ (Nat.le_refl _) stored
  refine ⟨allocated, saved, ⟨allocation, stored, pointerCast_readonly_of_load _ _ _ _ _ _
    (load_after_store _ _ _ _ stored), readonly_after_store _ _ _ _ _ _ _ stored, frame⟩, ?_⟩
  rw [(store_keeps_counters _ _ _ _ stored).2]
  exact allocate_cursor_cost _ _ _ _ _ shaped allocation

end Compiler.ZigAir.Memory
