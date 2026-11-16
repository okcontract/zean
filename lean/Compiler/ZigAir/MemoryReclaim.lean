/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryRelease
import Compiler.ZigAir.MemoryAllocationShape

/-! Reusable physical storage with fresh lifetime identities. Reclamation only
changes the allocation cursor. Live objects keep their addresses and contents;
holes below the highest live object are deliberately not compacted. This is a
sequential allocation policy, not a theorem about a native stack's capacity. -/
namespace Compiler.ZigAir.Memory

def Heap.highWater : Heap → Nat
  | [] => 8
  | (_, cell) :: rest => max (cell.base + (cell.type.layout.map Layout.bytes).getD 0) (highWater rest)

theorem Heap.highWater_member (heap : Heap) (entry : Nat × Allocation)
    (present : entry ∈ heap) :
    entry.2.base + (entry.2.type.layout.map Layout.bytes).getD 0 ≤ heap.highWater := by
  induction heap with
  | nil => simp at present
  | cons head tail ih =>
    rcases List.mem_cons.mp present with same | later
    · subst entry; exact Nat.le_max_left _ _
    · exact Nat.le_trans (ih later) (Nat.le_max_right _ _)

theorem Heap.highWater_bound (heap : Heap) (cursor : Nat) (minimum : 8 ≤ cursor)
    (bounded : ∀ entry ∈ heap,
      entry.2.base + (entry.2.type.layout.map Layout.bytes).getD 0 ≤ cursor) :
    heap.highWater ≤ cursor := by
  induction heap with
  | nil => exact minimum
  | cons head tail ih =>
    exact Nat.max_le.mpr ⟨bounded head (by simp), ih (fun entry member => bounded entry (by simp [member]))⟩

theorem Heap.highWater_positive (heap : Heap) : 8 ≤ heap.highWater := by
  induction heap with
  | nil => exact Nat.le_refl _
  | cons head tail ih => exact Nat.le_trans ih (Nat.le_max_right _ _)

def reclaim (state : State) : State := { state with nextAddress := state.heap.highWater }

theorem reclaim_preserves_valid (state : State) (valid : state.valid = true) :
    (reclaim state).valid = true := by
  simp only [State.valid, Bool.and_eq_true, decide_eq_true_eq, List.all_eq_true] at valid ⊢
  have bound : state.heap.highWater ≤ max 8 state.nextAddress := by
    apply Heap.highWater_bound _ _ (Nat.le_max_left _ _)
    intro entry member
    have checked := valid.1.2 entry member
    cases layout : entry.2.type.layout with
    | none => simp [layout] at checked
    | some shape =>
      simp only [layout, Bool.and_eq_true, decide_eq_true_eq] at checked
      have endBound : entry.2.base + (entry.2.type.layout.map Layout.bytes).getD 0 ≤ state.nextAddress := by
        simpa [layout] using checked.2.1.2
      simpa only [layout] using Nat.le_trans endBound (Nat.le_max_right 8 state.nextAddress)
  refine ⟨⟨Nat.le_trans bound (Nat.max_le.mpr ⟨by decide, valid.1.1⟩), ?_⟩, valid.2⟩
  intro entry member
  have checked := valid.1.2 entry member
  have bound := Heap.highWater_member state.heap entry member
  cases layout : entry.2.type.layout with
  | none => simp [layout] at checked
  | some shape =>
    simp only [layout, Bool.and_eq_true, decide_eq_true_eq] at checked ⊢
    exact ⟨checked.1, ⟨checked.2.1.1, by simpa [reclaim, layout] using bound⟩, checked.2.2⟩

@[simp] theorem reclaim_heap (state : State) : (reclaim state).heap = state.heap := rfl
@[simp] theorem reclaim_nextId (state : State) : (reclaim state).nextId = state.nextId := rfl
@[simp] theorem reclaim_idempotent (state : State) : reclaim (reclaim state) = reclaim state := rfl

/-- Exact observational agreement for every access, including invalid accesses.
Reclamation neither repairs a dangling pointer nor initializes a cell. -/
theorem access_reclaim (state : State) (address : Address) (layout : Layout) (write : Bool) :
    access (reclaim state) address layout write = access state address layout write := rfl

theorem load_reclaim (state : State) (pointer : Value) :
    load (reclaim state) pointer = load state pointer := rfl

def cleanupReusing (mark : Nat) (state : State) : State := reclaim (cleanup mark state)

theorem cleanupReusing_valid (state : State) (mark : Nat) (valid : state.valid = true) :
    (cleanupReusing mark state).valid = true :=
  reclaim_preserves_valid _ (cleanup_preserves_valid mark state valid)

theorem cleanupReusing_load (state : State) (mark : Nat) (pointer : Value) :
    load (cleanupReusing mark state) pointer = load (cleanup mark state) pointer := rfl

theorem cleanupReusing_fresh (state : State) (mark : Nat) :
    (cleanupReusing mark state).nextId = state.nextId := rfl

/-- Allocation after reclamation still uses a new lifetime. An old pointer
cannot regain validity merely because a physical base address is reused. -/
theorem allocate_reclaimed_identity (state after : State) (type : Ty) (pointer : Value)
    (allocated : allocate (reclaim state) type = .ok (pointer, after)) :
    pointer = .pointer (.pointer true false type) ⟨state.nextId, 0⟩ :=
  (allocate_pointer (reclaim state) type pointer after allocated).1

end Compiler.ZigAir.Memory
