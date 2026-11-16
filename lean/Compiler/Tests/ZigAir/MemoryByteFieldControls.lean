/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryByteFields
import Compiler.ZigAir.MemoryByteWriteContracts
import Compiler.ZigAir.MemoryByteSubviews

namespace Compiler.Tests.ZigAir.MemoryByteFieldControls
open Compiler.ZigAir Compiler.ZigAir.Memory Memory.ByteArray

def owner : Ty := .aggregate "Packet" ⟨8, 2⟩
  [(0, .scalar (.int false 16)), (2, .object (.array 3 byte))]

theorem payload : ByteField owner 2 3 := by
  refine ⟨⟨8, 2⟩, rfl, by decide, by decide, ?_⟩
  intro index inside
  have cases : index = 0 ∨ index = 1 ∨ index = 2 := by omega
  rcases cases with rfl | rfl | rfl <;> decide +kernel

/-- The quantified write theorem requires no initialized payload. -/
example (state : State) (id index : Nat) (value : BitVec 8)
    (valid : state.valid = true) (cap : RootWritable state owner id) (inside : index < 3) :
    ∃ after, store state (.pointer (.pointer true false byte) ⟨id, 2 + index⟩)
      (number value) = .ok after :=
  (payload.region cap).write valid inside value

/-- Suffixes retain the actual owner and its nonzero field offset. -/
example (state : State) (id : Nat) (cap : RootWritable state owner id) :
    Region state ⟨⟨id, 3⟩, 2⟩ true := by
  exact (payload.region cap).suffix (by decide : 1 < 3)

theorem padding_rejects : ¬ByteField owner 5 1 := by
  rintro ⟨_, _, _, _, declared⟩
  have selected := (declared 0 (by decide)).1
  have absent : acceptsView owner (5 + 0) byte = false := by decide +kernel
  rw [absent] at selected
  contradiction

theorem integer_field_rejects : ¬ByteField owner 0 1 := by
  rintro ⟨_, _, _, _, declared⟩
  have selected := (declared 0 (by decide)).1
  have absent : acceptsView owner (0 + 0) byte = false := by decide +kernel
  rw [absent] at selected
  contradiction

end Compiler.Tests.ZigAir.MemoryByteFieldControls
