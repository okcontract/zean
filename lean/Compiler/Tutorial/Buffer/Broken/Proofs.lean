/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Buffer.Proofs
import Compiler.Tutorial.Buffer.Broken.Generated

/-! Kernel-checked counterexamples for the captured off-by-one edit. No
undefined native operation is executed to obtain these witnesses. -/
namespace Compiler.Tutorial.Buffer.Broken
open Compiler.ZigAir Compiler.ZigAir.Memory Compiler.ZigAir.MemoryAir
open Compiler.ZigAir.Memory.WordArray

def caller : State :=
  ⟨[(0, ⟨8, .array 3 word, [(0, number 10), (4, number 20), (8, number 30)], true, false⟩)], 1, 20⟩

def whole : View := ⟨0, 0, 3⟩
def middle : View := ⟨0, 1, 1⟩

theorem caller_valid : caller.valid = true := by decide
theorem whole_writable : Writable caller whole :=
  ⟨3, _, rfl, rfl, rfl, by decide⟩
theorem middle_writable : Writable caller middle :=
  ⟨3, _, rfl, rfl, rfl, by decide⟩

def boundary := Generated.fn_replace.run (arguments whole 3 99) caller
def escaped := Generated.fn_replace.run (arguments middle 1 99) caller

/-- At the allocation boundary, the bad guard reaches an invalid access. -/
theorem boundary_fault : boundary.1 = .error .memoryValidity := rfl
theorem boundary_heap : boundary.2.heap = caller.heap := by decide

/-- Inside a larger allocation, the same bug silently writes outside the
logical buffer. Physical allocation bounds alone would miss this contract bug. -/
theorem escaped_success : escaped.1 = .ok (.scalar (.bool true)) := rfl
theorem escaped_changes_neighbor :
    load caller (whole.pointer 2) = .ok (number 30) ∧
    load escaped.2 (whole.pointer 2) = .ok (number 99) := ⟨rfl, rfl⟩
theorem escaped_not_framed : ¬ HeapFrame middle caller escaped.2 := by
  intro framed
  have unchanged := framed.outside 8 (Or.inr (by decide))
  change (Except.ok (number 99) : Except Fault Value) = .ok (number 30) at unchanged
  cases unchanged

/-- The repaired capture rejects both boundary inputs and preserves the heap. -/
theorem repaired_boundaries :
    (V2.Generated.fn_replace.run (arguments whole 3 99) caller).1 = .ok (.scalar (.bool false)) ∧
    (V2.Generated.fn_replace.run (arguments middle 1 99) caller).2.heap = caller.heap := ⟨rfl, rfl⟩

end Compiler.Tutorial.Buffer.Broken
