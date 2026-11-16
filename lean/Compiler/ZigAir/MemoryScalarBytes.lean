/-
// Copyright (C) 2026 OKcontract Pte. Ltd.
// SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryRecordWrites
import Compiler.ZigAir.MemoryScalarByteModel

namespace Compiler.ZigAir.Memory.ScalarBytes

theorem locate_integer (signed : Bool) (bits offset : Nat) (shape : Layout)
    (shaped : (Ty.scalar (.int signed bits)).layout = some shape)
    (positive : 0 < bits) (whole : bits % 8 = 0) (size : shape.bytes = bits / 8)
    (inside : offset < shape.bytes) :
    locate (.scalar (.int signed bits)) offset = some (0, signed, bits) := by
  have bound : offset < bits / 8 := by omega
  simp [locate, atom, shaped, positive, whole, size, bound]

theorem locateField_integer (signed : Bool) (bits offset : Nat) (shape : Layout)
    (shaped : (Ty.scalar (.int signed bits)).layout = some shape)
    (positive : 0 < bits) (whole : bits % 8 = 0) (size : shape.bytes = bits / 8)
    (inside : offset < shape.bytes) :
    locateField (.scalar (.int signed bits)) offset = some (0, signed, bits) := by
  exact locate_integer signed bits offset shape shaped positive whole size inside

theorem arrayCast_const (state : State) (address : Address) (cell : Allocation)
    (signed mutable many : Bool) (bits alignment count : Nat) (shape : Layout)
    (shaped : (Ty.scalar (.int signed bits)).layout = some shape)
    (positive : 0 < bits) (whole : bits % 8 = 0) (counted : count = bits / 8)
    (size : shape.bytes = count) (aligned : 0 < alignment ∧ shape.alignment % alignment = 0)
    (accessed : access state address shape false = .ok cell)
    (viewed : acceptsView cell.type address.offset (.scalar (.int signed bits)) = true) :
    arrayCast state false alignment count (.pointer (.pointer mutable many (.scalar (.int signed bits))) address) =
      .ok (.pointer (.pointer false false (.array count (.scalar (.int false 8)))) address) := by
  simp [arrayCast, shaped, positive, whole, counted, size, aligned, accessed, viewed, bind, Except.bind]

/-- The enclosing owner/array proof derives the selected leaf and its ordinary
load. This lemma derives the interior-byte access from that leaf's geometry. -/
theorem readAt_of_load (state : State) (address : Address) (cell : Allocation)
    (signed : Bool) (bits index : Nat) (value : Int) (shape : Layout)
    (accessed : access state address shape false = .ok cell) (inside : index < shape.bytes)
    (selected : locate cell.type (address.offset + index) = some (address.offset, signed, bits))
    (loaded : load state (.pointer (.pointer false false (.scalar (.int signed bits))) address) =
      .ok (.scalar (.int signed bits value))) :
    readAt state ⟨address.allocation, address.offset + index⟩ =
      .ok (BitVec.ofNat 8 ((BitVec.ofInt bits value).toNat / 256 ^ index)) := by
  have accessedByte := access_subregion state address shape ⟨1, 1⟩ index false cell accessed
    (by decide) (by change index + 1 ≤ shape.bytes; omega) (Nat.mod_one _) (Nat.mod_one _)
  cases address
  simp only [readAt, accessedByte, selected, bind, Except.bind, loaded, Nat.add_sub_cancel_left]

theorem readAt_same_allocation (before after : State) (address : Address)
    (same : before.heap.lookup address.allocation = after.heap.lookup address.allocation) :
    readAt before address = readAt after address := by
  simp only [readAt, access, load, same]

end Compiler.ZigAir.Memory.ScalarBytes
