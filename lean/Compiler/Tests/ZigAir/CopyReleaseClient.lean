/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryClaims

/-! A model-level comparison client for sequential resources. This composes
existing executable copy and typed-release operations; it is not native capture
evidence or an implementation of a Zig allocator vtable. -/
namespace Compiler.Tests.ZigAir.CopyReleaseClient
open Compiler.ZigAir Compiler.ZigAir.Memory ByteArray

def copyRelease (state : State) (target : Address) (source count : Nat) : Except Fault Unit × State :=
  match ByteRange.copy state (.slice (.slice true byte) target count)
      (.pointer (.pointer false true byte) ⟨source, 0⟩) with
  | (.error fault, after) => (.error fault, after)
  | (.ok (), middle) => match releaseOwned middle source (.array count byte) with
    | .ok after => (.ok (), after)
    | .error fault => (.error fault, middle)

theorem copy_release (state : State) (target : View) (source count : Nat) (cell : Allocation)
    (contents : Nat → BitVec 8) (claim : Resources.Claim)
    (valid : state.valid = true) (found : state.heap.lookup source = some cell)
    (typed : cell.type = .array count byte) (write : cell.writable = true) (persistent : cell.stack = false)
    (positive : 0 < count) (targetRegion : Region state target true) (room : count ≤ target.length)
    (initialized : Represents state ⟨⟨source, 0⟩, count⟩ contents)
    (apart : source ≠ target.address.allocation) (held : claim.holds state)
    (framed : Resources.Disjoint claim.footprint
      (Resources.Union (Resources.Single target.address.allocation) (Resources.Single source))) :
    ∃ after, copyRelease state target.address source count = (.ok (), after) ∧
      after.valid = true ∧ after.heap.lookup source = none ∧
      Prefix after target contents count ∧ claim.holds after := by
  have sourceRegion : Region state ⟨⟨source, 0⟩, count⟩ false :=
    Region.array found typed (by simp) positive (by simp)
  obtain ⟨middle, copied, middleValid, _, _, _, filled, frame⟩ :=
    copy_refines valid sourceRegion targetRegion initialized (.inl apart) (Nat.le_refl _) room
  have foundAfter : middle.heap.lookup source = some cell := (frame.allocations source apart).trans found
  have released : releaseOwned middle source (.array count byte) = .ok (erase middle source) := by
    simp [releaseOwned, middleValid, foundAfter, typed, write, persistent]
  have equation : ByteRange.copy state (.slice (.slice true byte) target.address count)
      (.pointer (.pointer false true byte) ⟨source, 0⟩) = (.ok (), middle) := by
    simpa [View.pointer, View.at] using copied
  refine ⟨erase middle source, ?_, erase_preserves_valid _ _ middleValid, ?_, ?_, ?_⟩
  · simp only [copyRelease, equation, released]
  · simp [erase_lookup]
  · intro index inside
    exact (erase_load_other middle source false false byte (target.at index) (Ne.symm apart)).trans
      (filled index inside)
  · exact Resources.copy_release_frame claim held equation released framed

end Compiler.Tests.ZigAir.CopyReleaseClient
