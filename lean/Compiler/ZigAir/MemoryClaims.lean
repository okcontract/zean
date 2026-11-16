/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryRelease
import Compiler.ZigAir.MemoryByteCopyFrame

/-! Sequential, allocation-granular resources. A claim states its footprint
and proves that equal allocations preserve it. Separating conjunction requires
disjoint footprints; plain conjunction can describe permitted read aliases.
These are logical resources, not a native borrowing discipline. Suballocation
word/byte views retain their more precise existing frame rules. -/
namespace Compiler.ZigAir.Memory.Resources

abbrev Footprint := Nat → Prop
def Disjoint (left right : Footprint) : Prop := ∀ id, left id → right id → False
def Union (left right : Footprint) : Footprint := fun id => left id ∨ right id
def Single (id : Nat) : Footprint := fun query => query = id

/-- All allocation metadata and initialized cells outside the write footprint
are preserved, including absent lifetimes. Counters are accounted separately. -/
def Modifies (writes : Footprint) (before after : State) : Prop :=
  ∀ id, ¬writes id → after.heap.lookup id = before.heap.lookup id

theorem Modifies.refl (writes : Footprint) (state : State) : Modifies writes state state := fun _ _ => rfl

theorem Modifies.then (first : Modifies left before middle) (second : Modifies right middle after) :
    Modifies (Union left right) before after := by
  intro id outside
  exact (second id (fun h => outside (.inr h))).trans (first id (fun h => outside (.inl h)))

structure Claim where
  footprint : Footprint
  holds : State → Prop
  stable : ∀ before after, (∀ id, footprint id → after.heap.lookup id = before.heap.lookup id) →
    holds before → holds after

def Claim.sep (left right : Claim) : Claim where
  footprint := Union left.footprint right.footprint
  holds state := Disjoint left.footprint right.footprint ∧ left.holds state ∧ right.holds state
  stable before after same held := ⟨held.1,
    left.stable before after (fun id member => same id (.inl member)) held.2.1,
    right.stable before after (fun id member => same id (.inr member)) held.2.2⟩

theorem Claim.sep_comm (left right : Claim) (state : State) :
    (left.sep right).holds state ↔ (right.sep left).holds state := by
  constructor <;> rintro ⟨apart, left, right⟩
  · exact ⟨fun id a b => apart id b a, right, left⟩
  · exact ⟨fun id a b => apart id b a, right, left⟩

theorem Claim.sep_assoc (left middle right : Claim) (state : State) :
    ((left.sep middle).sep right).holds state ↔ (left.sep (middle.sep right)).holds state := by
  simp only [Claim.sep, Disjoint, Union]
  constructor
  · rintro ⟨outer, ⟨inner, a, b⟩, c⟩
    exact ⟨fun id ha hbc => hbc.elim (inner id ha) (outer id (.inl ha)), a,
      ⟨fun id hb hc => outer id (.inr hb) hc, b, c⟩⟩
  · rintro ⟨outer, a, ⟨inner, b, c⟩⟩
    exact ⟨fun id hab hc => hab.elim (fun ha => outer id ha (.inr hc)) (fun hb => inner id hb hc),
      ⟨fun id ha hb => outer id ha (.inl hb), a, b⟩, c⟩

theorem Claim.frame (claim : Claim) (held : claim.holds before)
    (effects : Modifies writes before after) (apart : Disjoint claim.footprint writes) :
    claim.holds after :=
  claim.stable before after (fun id member => effects id (apart id member)) held

/-- A complete allocation claim includes its permission, shape, lifetime kind
and sparse initialization contents. It does not invent initialized bytes. -/
def allocation (id : Nat) (cell : Allocation) : Claim where
  footprint := Single id
  holds state := state.heap.lookup id = some cell
  stable _ _ same held := (same id rfl).trans held

def initialized (write many : Bool) (child : Ty) (address : Address) (value : Value) : Claim where
  footprint := Single address.allocation
  holds state := load state (.pointer (.pointer write many child) address) = .ok value
  stable before after same held :=
    (load_eq_of_lookup before after write many child address (same address.allocation rfl)).trans held

theorem allocation_exclusive (id : Nat) (left right : Allocation) (state : State) :
    ¬((allocation id left).sep (allocation id right)).holds state := by
  intro claimed
  exact claimed.1 id rfl rfl

theorem store_modifies (stored : store before (.pointer (.pointer write many child) address) value = .ok after) :
    Modifies (Single address.allocation) before after :=
  heap_after_store_other before write many child address value after stored

theorem erase_modifies (state : State) (id : Nat) : Modifies (Single id) state (erase state id) := by
  intro query apart
  change query ≠ id at apart
  simp only [erase_lookup, ite_eq_right apart]

theorem copy_modifies (copied : ByteRange.copy before (.slice (.slice true ByteArray.byte) target count)
    (.pointer (.pointer false true ByteArray.byte) source) = (.ok (), after)) :
    Modifies (Single target.allocation) before after :=
  (ByteArray.copy_frame copied).allocations

/-- Copy followed by release preserves every disjoint claim, irrespective of
the claim's word/byte/record interpretation. Callee contracts supply the two
execution equations; the frame rule does not unfold those executions. -/
theorem copy_release_frame (claim : Claim) (held : claim.holds before)
    (copied : ByteRange.copy before (.slice (.slice true ByteArray.byte) target count)
      (.pointer (.pointer false true ByteArray.byte) source) = (.ok (), middle))
    (released : releaseOwned middle source.allocation type = .ok after)
    (apart : Disjoint claim.footprint (Union (Single target.allocation) (Single source.allocation))) :
    claim.holds after := by
  obtain ⟨_, _, _, _, _, _, rfl⟩ := releaseOwned_shape middle after source.allocation type released
  exact claim.frame held ((copy_modifies copied).then (erase_modifies middle source.allocation)) apart

end Compiler.ZigAir.Memory.Resources
