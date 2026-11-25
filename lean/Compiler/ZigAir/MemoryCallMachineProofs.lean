/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryCallMachine

namespace Compiler.ZigAir.MemoryCallMachine
open Memory

@[simp] theorem advance_finished (program : Program) (fuel : Nat)
    (result : Except Fault Value) (state : State) :
    advance program fuel (.finished result state) = .finished result state := by
  cases fuel <;> rfl

theorem advance_add (program : Program) (first second : Nat) (execution : Execution) :
    advance program (first + second) execution =
      advance program second (advance program first execution) := by
  induction first generalizing execution with
  | zero => simp only [Nat.zero_add, advance]
  | succ first ih =>
    cases execution with
    | finished => simp only [advance_finished]
    | suspended config => simpa only [Nat.succ_add, advance] using ih (step program config)

theorem advance_steps (program : Program) (fuel : Nat) (execution : Execution) :
    Steps program execution (advance program fuel execution) := by
  induction fuel generalizing execution with
  | zero => exact .refl _
  | succ fuel ih =>
    cases execution with
    | finished => exact .refl _
    | suspended config => exact .step config (ih (step program config))

theorem steps_iff_fuel (program : Program) (first last : Execution) :
    Steps program first last ↔ ∃ fuel, advance program fuel first = last := by
  constructor
  · intro reached
    induction reached with
    | refl => exact ⟨0, rfl⟩
    | step config _ ih => obtain ⟨fuel, h⟩ := ih; exact ⟨fuel + 1, h⟩
  · rintro ⟨fuel, rfl⟩
    exact advance_steps program fuel first

theorem finished_stable (program : Program) (fuel extra : Nat) (first : Execution)
    (result : Except Fault Value) (state : State)
    (done : advance program fuel first = .finished result state) :
    advance program (fuel + extra) first = .finished result state := by
  rw [advance_add, done, advance_finished]

theorem safe_iff_fuel (program : Program) (first : Execution) :
    Safe program first ↔ ∀ fuel fault after,
      advance program fuel first = .finished (.error fault) after → fault = .outOfMemory := by
  constructor
  · intro safe fuel fault after reached
    exact safe fault after ((steps_iff_fuel program _ _).mpr ⟨fuel, reached⟩)
  · intro safe fault after reached
    obtain ⟨fuel, h⟩ := (steps_iff_fuel program _ _).mp reached
    exact safe fuel fault after h

theorem Steps.preserves (program : Program) (invariant : Execution → Prop)
    (closed : ∀ config, invariant (.suspended config) → invariant (MemoryCallMachine.step program config))
    {first last : Execution} (reached : Steps program first last) (initial : invariant first) :
    invariant last := by
  induction reached with
  | refl => exact initial
  | step config _ ih => exact ih (closed config initial)

/-- A reusable invariant rule. This excludes reached faults, rather than only
requiring heaps to remain valid. It also covers nonterminating executions. -/
theorem safe_of_invariant (program : Program) (invariant : Execution → Prop)
    (first : Execution) (initial : invariant first)
    (closed : ∀ config, invariant (.suspended config) → invariant (step program config))
    (faults : ∀ fault after, invariant (.finished (.error fault) after) → fault = .outOfMemory) :
    Safe program first := by
  intro fault after reached
  exact faults fault after (reached.preserves program invariant closed initial)

/-- A positive fault witness must be reachable and violate the selected fault
policy. A stuck proof or an exhausted observation budget is not such a witness. -/
theorem unsafe_of_witness (program : Program) (first : Execution) (fuel : Nat)
    (fault : Fault) (after : State)
    (reached : advance program fuel first = .finished (.error fault) after)
    (invalid : fault ≠ .outOfMemory) : ¬ Safe program first := by
  intro safe
  exact invalid ((safe_iff_fuel program first).mp safe fuel fault after reached)

/-- Two observed finite executions can be composed without a fuel budget. -/
theorem Steps.trans (firstRun : Steps program first middle)
    (suffix : Steps program middle last) : Steps program first last := by
  induction firstRun with
  | refl => exact suffix
  | step config _ ih => exact .step config (ih suffix)

end Compiler.ZigAir.MemoryCallMachine
