/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryRootCapability
import Compiler.ZigAir.MemoryReadTyping
import Compiler.ZigAir.MemoryRecordWrites

namespace Compiler.ZigAir.Memory
variable {id : Nat}

/-- After a successful slice load, its checked length projection reads the
same unsigned value. The slice may be embedded in another object. -/
theorem load_slice_length_of_access (state : State) (address data : Address) (cell : Allocation)
    (readWritable readMany writable lengthWritable : Bool) (child : Ty) (length : Nat)
    (accessed : access state address ⟨16, 8⟩ false = .ok cell)
    (declared : acceptsView cell.type (address.offset + 8) usize = true)
    (loaded : load state (.pointer (.pointer readWritable readMany (.slice writable child)) address) =
      .ok (.slice (.slice writable child) data length)) :
    load state (.pointer (.pointer lengthWritable false usize) ⟨address.allocation, address.offset + 8⟩) =
      .ok (.scalar (.int false 64 length)) := by
  have selected := access_subregion state address ⟨16, 8⟩ ⟨8, 8⟩ 8 false cell accessed
    (by decide) (by decide) (by decide) (by decide)
  have read : cell.cells.read cell.type address.offset (.slice writable child) =
      .ok (.slice (.slice writable child) data length) := by
    simpa only [load, Ty.layout, Ty.leafLayout, accessed, bind, Except.bind, readCell] using loaded
  have parts := cell.cells.read_slice_parts cell.type address.offset writable child data length read
  simp only [load, show usize.layout = some ⟨8, 8⟩ from rfl, selected, bind, Except.bind, readCell,
    Cells.read, declared, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
  exact parts.2.2

/-- A saved slice exposes its initialized length field. The field's physical
bounds and alignment follow from the complete slot's checked geometry. -/
theorem RootWritable.slice_length (cap : RootWritable state (.slice writable child) id)
    (valid : state.valid = true)
    (loaded : load state (.pointer (.pointer readWritable readMany (.slice writable child)) ⟨id, 0⟩) =
      .ok (.slice (.slice writable child) data length)) :
    load state (.pointer (.pointer false false usize) ⟨id, 8⟩) = .ok (.scalar (.int false 64 length)) := by
  obtain ⟨cell, found, typed, _⟩ := cap
  have full := root_access state id cell ⟨16, 8⟩ false valid found (by simp [typed, Ty.layout]) (by decide) (by simp)
  have declared : acceptsView cell.type 8 usize = true := by rw [typed]; rfl
  exact load_slice_length_of_access state ⟨id, 0⟩ data cell readWritable readMany writable false child length
    full declared loaded

end Compiler.ZigAir.Memory
