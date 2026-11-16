/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Components.Replace.Generated
import Compiler.ZigAir.MemoryInitializedWords

/-! Independent concrete observations of the captured standard-library body.
Invalid accesses run only in the model. -/
namespace Compiler.Components.Replace.Controls
open Compiler.ZigAir Compiler.ZigAir.Memory Compiler.ZigAir.MemoryAir Memory.WordArray
deriving instance DecidableEq for Except
set_option maxRecDepth 4096
set_option maxHeartbeats 1000000

def view : View := ⟨0, 1, 3⟩
def cell : Allocation :=
  ⟨16, .array 5 word, [(0, number 101), (4, number 2), (8, number 7), (12, number 2), (16, number 103)], true, false⟩
def caller : State := ⟨[(0, cell)], 1, 36⟩
def incomplete : State := { caller with heap := [(0, { cell with cells := [(0, number 101), (4, number 2)] })] }
def readonly : State := { caller with heap := [(0, { cell with writable := false })] }

def result : MemoryAir.Invocation → Option (Except Fault Value)
  | .finished outcome _ => some outcome
  | .suspended .. => none

def run (state : State) (slice : View) :=
  Generated.fn_replaceScalar__func_0.runFuel 160 [slice.slice, number 2, number 3] state

theorem caller_valid : caller.valid = true := by decide
theorem incomplete_valid : incomplete.valid = true := by decide
theorem readonly_valid : readonly.valid = true := by decide
theorem replaces_matches : result (run caller view) = some (.ok (.scalar .unit)) := by decide +kernel
theorem preserves_neighbors :
    (List.range 5).map (fun i => load (run caller view).state (({ view with first := 0 } : View).pointer i)) =
      [101, 3, 7, 3, 103].map (fun n => .ok (number n)) := by decide +kernel
theorem empty_succeeds : result (run caller { view with length := 0 }) = some (.ok (.scalar .unit)) := by decide +kernel
theorem missing_initialization_faults : result (run incomplete view) = some (.error .uninitialized) := by decide +kernel
theorem failure_keeps_reached_write : load (run incomplete view).state (view.pointer 0) = .ok (number 3) := by decide +kernel
theorem missing_permission_faults : result (run readonly view) = some (.error .readOnly) := by decide +kernel
theorem exaggerated_length_faults :
    result (run caller { view with length := 5 }) = some (.error .memoryValidity) := by decide +kernel

end Compiler.Components.Replace.Controls
