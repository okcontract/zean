/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import CellCalls.Generated
import Compiler.ZigAir.Verify.Machine
import Compiler.ZigAir.Verify.Words

namespace NeighborCell
open Compiler.ZigAir Compiler.ZigAir.Memory MemoryCallMachine WordArray
open CellCalls

def initial : State := ⟨[(0, ⟨8, .array 1 word, [], true, false⟩)], 1, 12⟩
def view : View := ⟨0, 0, 1⟩
def arguments : List Value := [view.pointer 0, number 9]

/-- This one-word caller satisfies the original example's storage contract. -/
theorem caller_contract : initial.valid = true ∧ Writable initial view ∧ 0 < view.length :=
  ⟨rfl, ⟨1, ⟨8, .array 1 word, [], true, false⟩, rfl, rfl, rfl, by decide⟩, by decide⟩

/-- The temporary pointer slot is cleaned up; the reached invalid access is
retained as a fault. Reduction is checked by the Lean kernel. -/
theorem reached :
    run Generated.functions 40 Generated.FunctionId.fn_update arguments initial =
      .finished (.error .memoryValidity) { initial with nextId := 2, nextAddress := 24 } := rfl

theorem not_safe :
    ¬Safe Generated.functions (start Generated.functions Generated.FunctionId.fn_update arguments initial) :=
  unsafe_of_witness _ _ 40 .memoryValidity _ reached (by decide)

end NeighborCell
