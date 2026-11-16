/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import ByteScan.Generated
import Compiler.ZigAir.Verify.Machine
import Compiler.ZigAir.Verify.Reads

namespace Overrun
open Compiler.ZigAir Compiler.ZigAir.Memory MemoryCallMachine
open ByteScan

def byte : Ty := .scalar (.int false 8)
def one : Value := .scalar (.int false 8 1)
def initial : State := ⟨[(0, ⟨8, .array 1 byte, [(0, one)], false, false⟩)], 1, 9⟩
def view : ReadView := ⟨byte, ⟨1, 1⟩, rfl, by decide, ⟨0, 0⟩, 1⟩
def arguments : List Value := [view.buffer, .scalar (.int false 64 1)]

/-- A valid initialized one-byte caller satisfies the safe scan's contract. -/
theorem caller_contract : initial.valid = true ∧ view.length < addressLimit ∧
    ReadView.Represents initial view (fun _ => one) := by
  refine ⟨rfl, by decide, ?_⟩
  intro index inside
  have zero : index = 0 := by change index < 1 at inside; omega
  subst index
  rfl

/-- One iteration and helper call complete before the inclusive bound admits
the invalid read. Both local stack slots are cleaned up on failure. -/
theorem reached :
    run Generated.functions 100 Generated.FunctionId.fn_all_nonzero arguments initial =
      .finished (.error .memoryValidity) { initial with nextId := 3, nextAddress := 32 } := rfl

theorem not_safe :
    ¬Safe Generated.functions (start Generated.functions Generated.FunctionId.fn_all_nonzero arguments initial) :=
  unsafe_of_witness _ _ 100 .memoryValidity _ reached (by decide)

end Overrun
