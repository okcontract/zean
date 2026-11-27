/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryByteCopyContracts

namespace Compiler.ZigAir.Memory.ByteArray

private theorem copy_initialized {source target : View}
    (valid : state.valid = true) (readable : Region state source false) (writable : Region state target true)
    (readBound : index < source.length) (writeBound : index < target.length)
    (loaded : load state (source.pointer false false index) = .ok (number value)) :
    ∃ after, ByteRange.copyByte state source.address target.address index = .ok after ∧
      store state (target.pointer true false index) (number value) = .ok after := by
  have read := readable.readByte_of_load valid readBound loaded
  obtain ⟨after, stored⟩ := writable.write valid writeBound value
  exact ⟨after, (ByteRange.copyByte_initialized read).trans stored, stored⟩

-- A forward write can intersect already read bytes, so preserve the source
-- snapshots only from the current index to the end of this transfer.
private theorem move_forward {source target : View} (valid : state.valid = true)
    (readable : Region state source false) (writable : Region state target true)
    (srcBound : index + count ≤ source.length) (dstBound : index + count = target.length)
    (order : source.address.allocation ≠ target.address.allocation ∨
      target.address.offset ≤ source.address.offset ∨ source.address.offset + index + count ≤ target.address.offset)
    (unread : ∀ i, index ≤ i → i < index + count →
      load state (source.pointer false false i) = .ok (number (contents i)))
    (filled : Prefix state target contents index) :
    ∃ after, ByteRange.copyLoop state source.address target.address index count = (.ok (), after) ∧
      Represents after target contents ∧ HeapFrame target state after := by
  induction count generalizing state index with
  | zero =>
    exact ⟨state, rfl, fun i inside => filled i (by omega), HeapFrame.refl _ _⟩
  | succ count ih =>
    have iSrc : index < source.length := by omega
    have iDst : index < target.length := by omega
    obtain ⟨middle, copied, stored⟩ := copy_initialized valid readable writable iSrc iDst
      (unread index (Nat.le_refl _) (by omega))
    have stillUnread : ∀ i, index + 1 ≤ i → i < index + 1 + count →
        load middle (source.pointer false false i) = .ok (number (contents i)) := by
      intro i lower upper
      have away : source.address.allocation ≠ target.address.allocation ∨
          source.address.offset + i ≠ target.address.offset + index := by
        rcases order with separate | low | high
        · exact .inl separate
        · exact .inr (by omega)
        · exact .inr (by omega)
      exact (load_byte_after_store_distinct stored away).trans (unread i (by omega) (by omega))
    have nextOrder : source.address.allocation ≠ target.address.allocation ∨
        target.address.offset ≤ source.address.offset ∨
        source.address.offset + (index + 1) + count ≤ target.address.offset := by
      rcases order with separate | low | high
      · exact .inl separate
      · exact .inr (.inl low)
      · exact .inr (.inr (by omega))
    obtain ⟨after, ran, represented, frame⟩ :=
      ih (store_preserves_valid _ _ _ _ valid stored) (readable.stored stored) (writable.stored stored)
        (by omega) (by omega) nextOrder stillUnread (filled.stored stored)
    exact ⟨after, by simpa only [ByteRange.copyLoop, copied] using ran, represented,
      (frame_store iDst stored).trans frame⟩

-- A backward write can intersect higher source indices, which have already
-- been read. Lower indices and the initialized destination suffix remain live.
private theorem move_backward {source target : View} (valid : state.valid = true)
    (readable : Region state source false) (writable : Region state target true)
    (srcBound : count ≤ source.length) (dstBound : count ≤ target.length)
    (order : source.address.offset < target.address.offset)
    (unread : ∀ i < count, load state (source.pointer false false i) = .ok (number (contents i)))
    (filled : ∀ i, count ≤ i → i < target.length →
      load state (target.pointer false false i) = .ok (number (contents i))) :
    ∃ after, ByteRange.copyBackward state source.address target.address count = (.ok (), after) ∧
      Represents after target contents ∧ HeapFrame target state after := by
  induction count generalizing state with
  | zero =>
    exact ⟨state, rfl, fun i inside => filled i (Nat.zero_le _) inside, HeapFrame.refl _ _⟩
  | succ count ih =>
    have iSrc : count < source.length := by omega
    have iDst : count < target.length := by omega
    obtain ⟨middle, copied, stored⟩ := copy_initialized valid readable writable iSrc iDst
      (unread count (by omega))
    have stillUnread : ∀ i < count, load middle (source.pointer false false i) = .ok (number (contents i)) := by
      intro i inside
      exact (load_byte_after_store_distinct stored (.inr (by omega))).trans (unread i (by omega))
    have filledNext : ∀ i, count ≤ i → i < target.length →
        load middle (target.pointer false false i) = .ok (number (contents i)) := by
      intro i lower inside
      by_cases equal : i = count
      · subst i
        exact load_alias_after_store _ true false byte _ _ _ false false stored
      · exact (load_byte_after_store_distinct stored (.inr (by omega))).trans (filled i (by omega) inside)
    obtain ⟨after, ran, represented, frame⟩ :=
      ih (store_preserves_valid _ _ _ _ valid stored) (readable.stored stored) (writable.stored stored)
        (by omega) (by omega) stillUnread filledNext
    exact ⟨after, by simpa only [ByteRange.copyBackward, copied] using ran, represented,
      (frame_store iDst stored).trans frame⟩

/-- Move the original source bytes, including when either window overlaps the
other. Only the destination is modified. The theorem applies to arbitrary
live byte views, including fields of larger objects and zero-length copies. -/
theorem move_refines (valid : state.valid = true) (readable : Region state source false)
    (writable : Region state target true) (initial : Represents state source contents)
    (fits : target.length ≤ source.length) (sourceWritable : Bool) :
    ∃ after, ByteRange.move state (target.slice true) (source.pointer sourceWritable true) = (.ok (), after) ∧
      Represents after target contents ∧ HeapFrame target state after := by
  simp only [ByteRange.move, View.slice, View.pointer, View.at, Nat.add_zero, ByteRange.destination, ByteRange.source]
  split <;> rename_i overlap
  · exact move_backward valid readable writable fits (Nat.le_refl _) overlap.2.1
      (fun i hi => initial i (by omega)) (fun i remaining inside => by omega)
  · have order : source.address.allocation ≠ target.address.allocation ∨
        target.address.offset ≤ source.address.offset ∨
        source.address.offset + 0 + target.length ≤ target.address.offset := by
      by_cases same : source.address.allocation = target.address.allocation
      · exact .inr (by omega)
      · exact .inl same
    exact move_forward valid readable writable (by omega) (Nat.zero_add _) order
      (fun i _ hi => initial i (by omega)) (fun i inside => by omega)

end Compiler.ZigAir.Memory.ByteArray
