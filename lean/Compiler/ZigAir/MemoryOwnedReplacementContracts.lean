/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryOwnedReplacement
import Compiler.ZigAir.MemoryByteCopyContracts

namespace Compiler.ZigAir.Memory.Ownership
open Compiler.ZigAir.Memory.ByteArray

/-- Successful allocate/copy/release preserves the old initialized prefix in
the new owner and invalidates the old lifetime. The allocator response is
checked against `Fits`; no property of an unmodeled native allocator is assumed.
The new tail need not be initialized. -/
theorem replaceBytes_success (world : World) (allocator oldId oldCount newCount base : Nat)
    (cell : Allocation) (contents : Nat → BitVec 8)
    (allocate : RegionAllocation.Allocator σ) (effects reached : σ)
    (valid : world.memory.valid = true)
    (registered : world.owners.owner oldId = some allocator)
    (found : world.memory.heap.lookup oldId = some cell)
    (typed : cell.type = .array oldCount byte)
    (writable : cell.writable = true) (persistent : cell.stack = false)
    (oldPositive : 0 < oldCount) (newPositive : 0 < newCount) (size : newCount < addressLimit)
    (initialized : Represents world.memory ⟨⟨oldId, 0⟩, oldCount⟩ contents)
    (response : allocate newCount 1 effects = (some base, reached))
    (fits : RegionAllocation.Fits world.memory ⟨newCount, 1⟩ base) :
    ∃ after, replaceBytes world allocator ⟨oldId, 0⟩ oldCount newCount allocate effects =
        ((.ok (some ⟨world.memory.nextId, 0⟩), after), reached) ∧
      after.memory.valid = true ∧ after.memory.heap.lookup oldId = none ∧
      after.owners.owner oldId = none ∧
      after.owners.owner world.memory.nextId = some allocator ∧
      Region after.memory ⟨⟨world.memory.nextId, 0⟩, newCount⟩ true ∧
      Prefix after.memory ⟨⟨world.memory.nextId, 0⟩, newCount⟩ contents (min oldCount newCount) := by
  let fresh := RegionAllocation.extend world.memory (.array newCount byte) newCount base
  have older := (valid_lookup _ _ _ valid found).1
  have distinct : oldId ≠ world.memory.nextId := by omega
  have freshValid : fresh.valid = true :=
    RegionAllocation.extend_valid _ _ _ _ valid (by simp [Ty.layout]) fits
  have source : Region world.memory ⟨⟨oldId, 0⟩, oldCount⟩ false :=
    Region.array found typed (by simp) oldPositive (by simp)
  have sourceFresh : Region fresh ⟨⟨oldId, 0⟩, oldCount⟩ false :=
    source.retained (RegionAllocation.extend_shape world.memory (.array newCount byte) newCount base valid)
  have target : Region fresh ⟨⟨world.memory.nextId, 0⟩, newCount⟩ true :=
    Region.array (cell := RegionAllocation.cell (.array newCount byte) base)
      (by simp [fresh, RegionAllocation.extend_lookup]) rfl (by simp [RegionAllocation.cell])
      newPositive (by simp)
  have readFresh : Represents fresh ⟨⟨oldId, 0⟩, oldCount⟩ contents := by
    intro index inside
    simpa only [View.pointer, View.at, Nat.zero_add] using
      (RegionAllocation.extend_load_other world.memory (.array newCount byte) newCount base
        false false byte ⟨oldId, index⟩ distinct).trans
          (by simpa only [View.pointer, View.at, Nat.zero_add] using initialized index inside)
  have apart : Disjoint ⟨⟨oldId, 0⟩, oldCount⟩ ⟨⟨world.memory.nextId, 0⟩, newCount⟩ := Or.inl distinct
  obtain ⟨copied, ran, copiedValid, _, copiedTarget, _, filled, frame⟩ :=
    copy_refines freshValid sourceFresh target readFresh apart (Nat.min_le_left _ _) (Nat.min_le_right _ _)
  have oldFound : copied.heap.lookup oldId = some cell := by
    rw [frame.allocations oldId distinct]
    simpa only [fresh, RegionAllocation.extend_lookup, ite_eq_right (Ne.symm distinct)] using found
  let prepared : World := ⟨copied, (world.memory.nextId, allocator) :: world.owners⟩
  have oldOwner : prepared.owners.owner oldId = some allocator := by
    simpa [prepared, Registry.owner, Ne.symm distinct] using registered
  have released := release_total (world := prepared) copiedValid oldOwner oldFound typed writable persistent
  let after : World := ⟨erase copied oldId, prepared.owners.retire oldId⟩
  have finished : release prepared allocator ⟨oldId, 0⟩ (.array oldCount byte) = .ok after := released
  have reserved := reserve_admitted world allocator (.array newCount byte) ⟨newCount, 1⟩ base allocate
    effects reached valid (by simp [Ty.layout]) (by dsimp; omega) size response fits
  have first := release_total valid registered found typed writable persistent
  refine ⟨after, ?_, erase_preserves_valid _ _ copiedValid, ?_, release_consumes finished, ?_, ?_, ?_⟩
  · simp only [View.pointer, View.at, Nat.add_zero] at ran
    unfold replaceBytes
    simp only [ByteRange.byte]
    rw [first]
    dsimp only
    rw [reserved]
    dsimp only
    rw [ran]
    dsimp only
    rw [finished]
  · simp [after, erase_lookup]
  · rw [release_keeps_other_owner finished _ (Ne.symm distinct)]
    simp [prepared, Registry.owner]
  · obtain ⟨extent, targetCell, targetFound, rest⟩ := copiedTarget
    exact ⟨extent, targetCell, by simpa only [after, erase_lookup, ite_eq_right (Ne.symm distinct)] using targetFound, rest⟩
  · intro index inside
    simpa only [View.pointer, View.at, Nat.zero_add] using
      (erase_load_other copied oldId false false byte ⟨world.memory.nextId, index⟩
        (Ne.symm distinct)).trans
          (by simpa only [View.pointer, View.at, Nat.zero_add] using filled index inside)

end Compiler.ZigAir.Memory.Ownership
