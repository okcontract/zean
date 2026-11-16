/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryByteArray
import Compiler.ZigAir.MemoryRootCapability

namespace Compiler.ZigAir.Memory.ByteArray

/-- Static byte-view geometry in a complete owner. Every selected byte must
be declared as a byte leaf; padding and integer representation casts do not
satisfy this contract. Initialization is deliberately absent. -/
def ByteField (owner : Ty) (offset length : Nat) : Prop :=
  ∃ layout, owner.layout = some layout ∧ offset < layout.bytes ∧
    offset + length ≤ layout.bytes ∧ DeclaredBytes owner offset length

/-- A checked field and a writable owner provide the same capability consumed
by byte-copy and loop contracts. No separate allocation is invented for a field. -/
theorem ByteField.region (geometry : ByteField owner offset length)
    (cap : RootWritable state owner objectId) : Region state ⟨⟨objectId, offset⟩, length⟩ true := by
  obtain ⟨layout, shaped, start, bound, declared⟩ := geometry
  obtain ⟨cell, found, typed, writable⟩ := cap
  exact ⟨layout, cell, found, typed ▸ shaped, fun _ => writable, start, bound, typed ▸ declared⟩

end Compiler.ZigAir.Memory.ByteArray
