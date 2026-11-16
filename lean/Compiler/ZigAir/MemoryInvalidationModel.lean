/-
// Copyright (C) 2026 OKcontract Pte. Ltd.
// SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.Memory

namespace Compiler.ZigAir.Memory

/-- Forget initialized leaves of a complete typed subobject. This is the
initialization effect of assigning `undefined`, not a write of a chosen byte
pattern. A later read must establish initialization again. -/
def Cells.forget (cells : Cells) (offset bytes : Nat) : Cells :=
  cells.filter (fun entry => decide (entry.1 < offset ∨ offset + bytes ≤ entry.1))

theorem Cells.forget_valid (cells : Cells) (owner : Ty) (offset bytes : Nat)
    (initial : cells.valid owner = true) : (cells.forget offset bytes).valid owner = true := by
  simp only [Cells.valid, Bool.and_eq_true, List.all_eq_true, decide_eq_true_eq] at initial ⊢
  exact ⟨fun entry present => initial.1 entry (List.mem_filter.mp present).1, initial.2.filter _⟩

theorem Cells.lookup_forget (cells : Cells) (offset bytes query : Nat) :
    (cells.forget offset bytes).lookup query =
      if offset ≤ query ∧ query < offset + bytes then none else cells.lookup query := by
  induction cells with
  | nil => simp [Cells.forget, Cells.lookup]
  | cons entry tail ih =>
    rcases entry with ⟨key, value⟩
    by_cases selected : key = query
    · subst key
      by_cases inside : offset ≤ query ∧ query < offset + bytes
      · have outside : ¬(query < offset ∨ offset + bytes ≤ query) := by omega
        simp [Cells.forget, Cells.lookup, outside, inside] at ih ⊢
        exact ih
      · have outside : query < offset ∨ offset + bytes ≤ query := by omega
        simp [Cells.forget, Cells.lookup, outside, inside]
    · simp only [Cells.forget, List.filter_cons]
      split <;> simpa [Cells.lookup, Cells.forget, selected] using ih

/-- The declared view, full extent, alignment and write permission are checked
before forgetting any leaves. No pointee is freed and no allocation identity is
reset. Unsupported storage or failed access remains an explicit rejection. -/
def invalidate (state : State) (writable : Bool) (child : Ty) (address : Address) : Except Fault State := do
  if !writable then .error .readOnly else
  let some layout := child.layout | .error .unsupported
  let cell ← access state address layout true
  if !acceptsView cell.type address.offset child then .error .unsupported else
  .ok { state with heap := (state.heap.replace address.allocation
    ({ cell with cells := cell.cells.forget address.offset layout.bytes })) }

theorem invalidate_of_access (state : State) (child : Ty) (address : Address) (layout : Layout) (cell : Allocation)
    (shaped : child.layout = some layout) (accessed : access state address layout true = .ok cell)
    (view : acceptsView cell.type address.offset child = true) :
    invalidate state true child address = .ok { state with heap := (state.heap.replace address.allocation
      ({ cell with cells := cell.cells.forget address.offset layout.bytes })) } := by
  simp only [invalidate, Bool.not_true, Bool.false_eq_true, ↓reduceIte, shaped, accessed, bind, Except.bind, view]

theorem invalidate_success (state : State) (writable : Bool) (child : Ty) (address : Address) (after : State)
    (executed : invalidate state writable child address = .ok after) :
    writable = true ∧ ∃ layout cell, child.layout = some layout ∧
      access state address layout true = .ok cell ∧ acceptsView cell.type address.offset child = true ∧
      after = { state with heap := (state.heap.replace address.allocation
        ({ cell with cells := cell.cells.forget address.offset layout.bytes })) } := by
  cases writable with
  | false => simp [invalidate] at executed
  | true =>
    refine ⟨rfl, ?_⟩
    cases shaped : child.layout with
    | none => simp [invalidate, shaped] at executed
    | some layout =>
      cases accessed : access state address layout true with
      | error reason => simp [invalidate, shaped, accessed, bind, Except.bind] at executed
      | ok cell =>
        simp only [invalidate, Bool.not_true, Bool.false_eq_true, ↓reduceIte, shaped, accessed, bind, Except.bind] at executed
        split at executed
        · contradiction
        · rename_i view
          exact ⟨layout, cell, rfl, accessed, by simpa using view, (Except.ok.inj executed).symm⟩


end Compiler.ZigAir.Memory
