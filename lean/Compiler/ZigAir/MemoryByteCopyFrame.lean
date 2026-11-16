/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryByteCopyContracts
import Compiler.ZigAir.MemoryRecordFields
import Compiler.ZigAir.MemoryRootCapability

namespace Compiler.ZigAir.Memory.ByteArray
variable {id : Nat}

/-- Every successful byte-copy prefix writes only its destination. This rule
also preserves invocation locals, before the caller performs stack cleanup. -/
theorem copyLoop_frame (ran : ByteRange.copyLoop before source target index count = (.ok (), after)) :
    HeapFrame ⟨target, index + count⟩ before after := by
  induction count generalizing before index with
  | zero => cases Prod.mk.inj ran |>.2; exact HeapFrame.refl _ _
  | succ count ih =>
    cases copied : ByteRange.copyByte before source target index with
    | error fault => simp only [ByteRange.copyLoop, copied] at ran; cases Prod.mk.inj ran |>.1
    | ok middle =>
      simp only [ByteRange.copyLoop, copied] at ran
      rcases ByteRange.copyByte_success copied with ⟨value, _, stored⟩ | ⟨_, forgotten⟩
      ·
        have first : HeapFrame ⟨target, index + (count + 1)⟩ before middle :=
          frame_store (by dsimp; omega) stored
        exact first.trans (by simpa only [Nat.add_assoc, Nat.add_comm 1 count] using ih ran)
      ·
        have first : HeapFrame ⟨target, index + (count + 1)⟩ before middle :=
          frame_invalidate (by dsimp; omega) forgotten
        exact first.trans (by simpa only [Nat.add_assoc, Nat.add_comm 1 count] using ih ran)

theorem copy_frame (ran : ByteRange.copy before (.slice (.slice true byte) target count)
    (.pointer (.pointer false true byte) source) = (.ok (), after)) :
    HeapFrame ⟨target, count⟩ before after := by
  simp only [ByteRange.copy, ByteRange.destination, ByteRange.source] at ran
  split at ran
  · cases Prod.mk.inj ran |>.1
  · simpa only [Nat.zero_add] using copyLoop_frame ran

theorem HeapFrame.load_other (frame : HeapFrame target before after) (write many : Bool)
    (child : Ty) (address : Address) (apart : address.allocation ≠ target.address.allocation) :
    load after (.pointer (.pointer write many child) address) =
      load before (.pointer (.pointer write many child) address) :=
  load_eq_of_lookup before after write many child address (frame.allocations _ apart)

theorem HeapFrame.root_other (frame : HeapFrame target before after) (cap : RootWritable before owner id)
    (apart : id ≠ target.address.allocation) : RootWritable after owner id := by
  obtain ⟨cell, found, typed, writable⟩ := cap
  exact ⟨cell, (frame.allocations id apart).trans found, typed, writable⟩

theorem HeapFrame.field_other (frame : HeapFrame target before after) (write many : Bool)
    (owner : Ty) (address : Address) (offset : Nat) (apart : address.allocation ≠ target.address.allocation) :
    fieldPointer after (.pointer (.pointer write many owner) address) offset =
      fieldPointer before (.pointer (.pointer write many owner) address) offset :=
  fieldPointer_eq_of_lookup before after write many owner address offset (frame.allocations _ apart)

end Compiler.ZigAir.Memory.ByteArray

namespace Compiler.ZigAir.Memory
open Compiler.ZigAir.Memory.ByteArray
variable {id : Nat}

theorem LoadStep.copied_other (loaded : LoadStep before (.pointer (.pointer write many child) address) value)
    (copied : ByteRange.copy before (.slice (.slice true byte) target count)
      (.pointer (.pointer false true byte) source) = (.ok (), after))
    (apart : address.allocation ≠ target.allocation) :
    LoadStep after (.pointer (.pointer write many child) address) value :=
  ⟨((copy_frame copied).load_other write many child address apart).trans loaded.equation⟩

theorem RootWritable.copied_other (cap : RootWritable before owner id)
    (copied : ByteRange.copy before (.slice (.slice true byte) target count)
      (.pointer (.pointer false true byte) source) = (.ok (), after))
    (apart : id ≠ target.allocation) : RootWritable after owner id :=
  (copy_frame copied).root_other cap apart

theorem field_pointer_copied_other
    (selected : fieldPointer before (.pointer (.pointer write many owner) address) offset = .ok value)
    (copied : ByteRange.copy before (.slice (.slice true byte) target count)
      (.pointer (.pointer false true byte) source) = (.ok (), after))
    (apart : address.allocation ≠ target.allocation) :
    fieldPointer after (.pointer (.pointer write many owner) address) offset = .ok value :=
  ((copy_frame copied).field_other write many owner address offset apart).trans selected

end Compiler.ZigAir.Memory
