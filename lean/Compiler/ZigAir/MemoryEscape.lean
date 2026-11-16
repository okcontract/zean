/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryAllocationShape

namespace Compiler.ZigAir.Memory

mutual
/-- Lifetime identities carried by a value, including optional record fields.
This conservative escape contract also retains the address of an empty slice. -/
def Value.lifetimes : Value → List Nat
  | .pointer _ address | .slice _ address _ => [address.allocation]
  | .optionalObject _ _ (some payload) => payload.lifetimes
  | _ => []
termination_by structural value => value

def ObjectValue.lifetimes : ObjectValue → List Nat
  | .leaf value => value.lifetimes
  | .fields fields => fieldLifetimes fields
termination_by structural value => value

def fieldLifetimes : List (Nat × ObjectValue) → List Nat
  | [] => []
  | (_, value) :: rest => value.lifetimes ++ fieldLifetimes rest
termination_by structural fields => fields
end

/-- Follow pointers stored in reachable allocations, not only the pointer
returned directly. Cyclic graphs are covered by finite reachability paths. -/
inductive Reachable (heap : Heap) (roots : List Nat) : Nat → Prop where
  | root {id : Nat} (member : id ∈ roots) : Reachable heap roots id
  | stored {id : Nat} (prior : Reachable heap roots parent) (found : heap.lookup parent = some cell)
      (entry : (offset, value) ∈ cell.cells) (points : id ∈ value.lifetimes) : Reachable heap roots id

variable {id : Nat}

def EscapeSafe (state : State) (mark : Nat) (roots : List Nat) : Prop :=
  ∀ id, Reachable state.heap roots id → ∃ cell,
    state.heap.lookup id = some cell ∧ (cell.stack = false ∨ id < mark)

theorem cleanup_lookup_persistent (valid : state.valid = true)
    (found : state.heap.lookup id = some cell) (persistent : cell.stack = false) :
    (cleanup mark state).heap.lookup id = some cell := by
  apply lookup_of_mem_valid _ _ _ (cleanup_preserves_valid mark state valid)
  apply List.mem_filter.mpr
  exact ⟨Heap.lookup_mem _ _ _ found, by simp [persistent]⟩

theorem Reachable.before_cleanup (valid : state.valid = true)
    (path : Reachable (cleanup mark state).heap roots id) : Reachable state.heap roots id := by
  induction path with
  | root member => exact .root member
  | stored prior found entry points ih =>
    have original := lookup_of_mem_valid _ _ _ valid
      (List.mem_filter.mp (Heap.lookup_mem _ _ _ found)).1
    exact .stored ih original entry points

/-- No allocation reachable from the escaping roots is retired by return.
Bounds, initialization and alias permissions remain separate obligations. -/
theorem EscapeSafe.cleanup_live (safe : EscapeSafe state mark roots) (valid : state.valid = true)
    (path : Reachable (cleanup mark state).heap roots id) :
    ∃ cell, (cleanup mark state).heap.lookup id = some cell := by
  obtain ⟨cell, found, persistent | older⟩ := safe id (path.before_cleanup valid)
  · exact ⟨cell, cleanup_lookup_persistent valid found persistent⟩
  · exact ⟨cell, (cleanup_lookup_older state mark id older).trans found⟩

end Compiler.ZigAir.Memory
