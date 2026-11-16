/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryRootCapability
import Compiler.ZigAir.MemoryReadTyping
import Compiler.ZigAir.MemoryRecordWrites

namespace Compiler.ZigAir.Memory
variable {id : Nat}

/-- A saved slice exposes its initialized length field. The field's physical
bounds and alignment follow from the complete slot's checked geometry. -/
theorem RootWritable.slice_length (cap : RootWritable state (.slice writable child) id)
    (valid : state.valid = true)
    (loaded : load state (.pointer (.pointer readWritable readMany (.slice writable child)) ⟨id, 0⟩) =
      .ok (.slice (.slice writable child) data length)) :
    load state (.pointer (.pointer false false usize) ⟨id, 8⟩) = .ok (.scalar (.int false 64 length)) := by
  obtain ⟨cell, found, typed, _⟩ := cap
  have full := root_access state id cell ⟨16, 8⟩ false valid found (by simp [typed, Ty.layout]) (by decide) (by simp)
  have selected := access_subregion state ⟨id, 0⟩ ⟨16, 8⟩ ⟨8, 8⟩ 8 false cell full
    (by decide) (by decide) (by decide) (by decide)
  have read : cell.cells.read cell.type 0 (.slice writable child) = .ok (.slice (.slice writable child) data length) := by
    simpa only [load, Ty.layout, Ty.leafLayout, full, bind, Except.bind, readCell] using loaded
  have parts := cell.cells.read_slice_parts cell.type 0 writable child data length read
  simpa [load, usize, Ty.layout, selected, bind, Except.bind, readCell, Cells.read, typed,
    acceptsView] using parts.2.2

end Compiler.ZigAir.Memory
