/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryRelease
import Compiler.ZigAir.MemoryRegionAllocationProofs

/-! Sequential allocator ownership. The registry is part of the modeled state;
a pointer value alone does not authorize release. These are boundary semantics,
not assumed contracts for an unverified native allocator or platform FFI. -/
namespace Compiler.ZigAir.Memory.Ownership
variable {id : Nat}

abbrev Registry := List (Nat × Nat)

def Registry.owner (registry : Registry) (id : Nat) : Option Nat :=
  (registry.find? fun entry => entry.1 == id).map Prod.snd

def Registry.retire (registry : Registry) (id : Nat) : Registry :=
  registry.filter fun entry => entry.1 != id

theorem Registry.owner_retire (registry : Registry) (id query : Nat) :
    (registry.retire id).owner query = if query = id then none else registry.owner query := by
  induction registry with
  | nil => simp [retire, owner]
  | cons entry tail ih =>
    rcases entry with ⟨key, allocator⟩
    by_cases selected : key = id
    · subst key
      by_cases same : query = id
      · subst query; simp [retire, owner]
      · simpa [retire, owner, same, Ne.symm same] using ih
    · by_cases same : key = query
      · subst query; simp [retire, owner, selected]
      · simpa [retire, owner, selected, same] using ih

structure World where
  memory : State
  owners : Registry
  deriving DecidableEq, Repr

/-- Registry entries describe distinct live persistent writable allocations.
Clients must establish this when introducing an external ownership state. -/
structure World.Consistent (world : World) : Prop where
  valid : world.memory.valid = true
  unique : world.owners.Pairwise (fun first second => first.1 ≠ second.1)
  live : ∀ entry ∈ world.owners, ∃ cell, world.memory.heap.lookup entry.1 = some cell ∧
    cell.writable = true ∧ cell.stack = false

/-- Only a successful nonempty allocator response creates an ownership entry.
Empty requests carry no releasable allocation in this boundary model. -/
def reserve (world : World) (allocator : Nat) (type : Ty)
    (allocate : RegionAllocation.Allocator σ) (effects : σ) :
    (Except Fault (Option Address) × World) × σ :=
  let ((result, memory), reached) := RegionAllocation.reserve world.memory type allocate effects
  let owners := match result with
    | .ok (some address) =>
      if address.allocation = world.memory.nextId ∧ memory.nextId = world.memory.nextId + 1 then
        (address.allocation, allocator) :: world.owners
      else world.owners
    | _ => world.owners
  ((result, ⟨memory, owners⟩), reached)

/-- Release checks allocator identity, the original base, and the complete
declared allocation. It consumes the registry entry on success. -/
def release (world : World) (allocator : Nat) (address : Address) (type : Ty) : Except Fault World := do
  if address.offset ≠ 0 ∨ world.owners.owner address.allocation ≠ some allocator then
    .error .memoryValidity
  else
    let memory ← releaseOwned world.memory address.allocation type
    .ok ⟨memory, world.owners.retire address.allocation⟩

theorem reserve_admitted (world : World) (allocator : Nat) (type : Ty) (layout : Layout) (base : Nat)
    (allocate : RegionAllocation.Allocator σ) (effects reached : σ)
    (valid : world.memory.valid = true) (shaped : type.layout = some layout)
    (nonempty : layout.bytes ≠ 0) (size : layout.bytes < addressLimit)
    (response : allocate layout.bytes layout.alignment effects = (some base, reached))
    (fits : RegionAllocation.Fits world.memory layout base) :
    reserve world allocator type allocate effects =
      ((.ok (some ⟨world.memory.nextId, 0⟩),
        ⟨RegionAllocation.extend world.memory type layout.bytes base,
          (world.memory.nextId, allocator) :: world.owners⟩), reached) := by
  simp only [reserve, RegionAllocation.reserve_admitted world.memory type layout base allocate
    effects reached valid shaped nonempty size response fits, RegionAllocation.extend,
    and_self, ↓reduceIte]

/-- Ordinary OOM retains the old allocation and registry, while preserving the
allocator's reached private effects. This is the failure branch needed by a
transactional reallocating caller. -/
theorem reserve_failed (world : World) (allocator : Nat) (type : Ty) (layout : Layout)
    (allocate : RegionAllocation.Allocator σ) (effects reached : σ)
    (valid : world.memory.valid = true) (shaped : type.layout = some layout)
    (nonempty : layout.bytes ≠ 0) (size : layout.bytes < addressLimit)
    (response : allocate layout.bytes layout.alignment effects = (none, reached)) :
    reserve world allocator type allocate effects = ((.ok none, world), reached) := by
  simp only [reserve, RegionAllocation.reserve_failed world.memory type layout allocate
    effects reached valid shaped nonempty size response]

theorem release_total (valid : world.memory.valid = true)
    (registered : world.owners.owner id = some allocator)
    (found : world.memory.heap.lookup id = some cell) (typed : cell.type = type)
    (writable : cell.writable = true) (persistent : cell.stack = false) :
    release world allocator ⟨id, 0⟩ type =
      .ok ⟨erase world.memory id, world.owners.retire id⟩ := by
  simp [release, registered, releaseOwned, valid, found, typed, writable, persistent, bind, Except.bind]

theorem release_success (ran : release before allocator address type = .ok after) :
    address.offset = 0 ∧ before.owners.owner address.allocation = some allocator ∧
    releaseOwned before.memory address.allocation type = .ok after.memory ∧
    after.memory = erase before.memory address.allocation ∧
    after.owners = before.owners.retire address.allocation := by
  unfold release at ran
  split at ran
  · contradiction
  · rename_i authorized
    cases released : releaseOwned before.memory address.allocation type with
    | error fault => simp only [released, bind, Except.bind] at ran; cases ran
    | ok memory =>
      simp only [released, bind, Except.bind] at ran
      cases Except.ok.inj ran
      obtain ⟨_, cell, _, _, _, _, same⟩ := releaseOwned_shape _ _ _ _ released
      exact ⟨by omega, by simpa using (not_or.mp authorized).2, rfl, same, rfl⟩

theorem release_valid (ran : release before allocator address type = .ok after) :
    after.memory.valid = true := by
  have result := release_success ran
  rw [result.2.2.2.1]
  exact erase_preserves_valid _ _ (releaseOwned_shape _ _ _ _ result.2.2.1).1

theorem release_consumes (ran : release before allocator address type = .ok after) :
    after.owners.owner address.allocation = none := by
  rw [(release_success ran).2.2.2.2, Registry.owner_retire]
  simp

theorem release_twice (ran : release before allocator address type = .ok after) :
    release after allocator address type = .error .memoryValidity := by
  simp [release, release_consumes ran]

/-- Every alias with the retired lifetime fails, regardless of its offset or
mutability. Reusing a native base address cannot revive this lifetime ID. -/
theorem release_invalidates_alias (ran : release before allocator address type = .ok after)
    (child : Ty) (layout : Layout) (shaped : child.layout = some layout)
    (offset : Nat) (write many : Bool) :
    load after.memory (.pointer (.pointer write many child) ⟨address.allocation, offset⟩) =
      .error .unallocated := by
  rw [(release_success ran).2.2.2.1]
  exact erase_load_dead _ _ _ _ _ _ _ shaped

theorem release_frame (ran : release before allocator address type = .ok after)
    (other : Address) (apart : other.allocation ≠ address.allocation) (write many : Bool) (child : Ty) :
    load after.memory (.pointer (.pointer write many child) other) =
      load before.memory (.pointer (.pointer write many child) other) := by
  rw [(release_success ran).2.2.2.1]
  exact erase_load_other _ _ _ _ _ _ apart

theorem release_keeps_other_owner (ran : release before allocator address type = .ok after)
    (other : Nat) (apart : other ≠ address.allocation) :
    after.owners.owner other = before.owners.owner other := by
  rw [(release_success ran).2.2.2.2, Registry.owner_retire, ite_eq_right apart]

theorem World.Consistent.released (consistent : before.Consistent)
    (ran : release before allocator address type = .ok after) : after.Consistent := by
  have result := release_success ran
  refine ⟨release_valid ran, ?_, ?_⟩
  · rw [result.2.2.2.2]
    exact consistent.unique.filter _
  · intro entry present
    rw [result.2.2.2.2] at present
    obtain ⟨old, retained⟩ := List.mem_filter.mp present
    obtain ⟨cell, found, writable, persistent⟩ := consistent.live entry old
    have apart : entry.1 ≠ address.allocation := by simpa using retained
    exact ⟨cell, by rw [result.2.2.2.1, erase_lookup, ite_eq_right apart]; exact found,
      writable, persistent⟩

theorem World.Consistent.extended {world : World} (consistent : world.Consistent) (allocator : Nat)
    (type : Ty) (bytes base : Nat)
    (valid : (RegionAllocation.extend world.memory type bytes base).valid = true) :
    (World.mk (RegionAllocation.extend world.memory type bytes base)
      ((world.memory.nextId, allocator) :: world.owners)).Consistent := by
  refine ⟨valid, ?_, ?_⟩
  · apply List.pairwise_cons.mpr
    refine ⟨?_, consistent.unique⟩
    intro entry present
    obtain ⟨cell, found, _⟩ := consistent.live entry present
    have older := (valid_lookup _ _ _ consistent.valid found).1
    dsimp only
    omega
  · intro entry present
    rcases List.mem_cons.mp present with same | old
    · subst entry
      exact ⟨RegionAllocation.cell type base, by simp [RegionAllocation.extend_lookup], rfl, rfl⟩
    · obtain ⟨cell, found, writable, persistent⟩ := consistent.live entry old
      have older := (valid_lookup _ _ _ consistent.valid found).1
      exact ⟨cell, by rw [RegionAllocation.extend_lookup, ite_eq_right (by omega)]; exact found,
        writable, persistent⟩

end Compiler.ZigAir.Memory.Ownership
