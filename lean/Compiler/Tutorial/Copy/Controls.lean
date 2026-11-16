/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Copy.Contracts

/-! Kernel-checked observations of the captured loop. Unsafe cases execute
only in the Lean model. Expected values are recorded independently of copying. -/
namespace Compiler.Tutorial.Copy.Controls
open Compiler.ZigAir Compiler.ZigAir.Memory Compiler.ZigAir.MemoryAir
open Memory.WordArray
deriving instance DecidableEq for Except
set_option maxRecDepth 4096
set_option maxHeartbeats 1000000

def source : View := ⟨0, 0, 3⟩
def target : View := ⟨1, 1, 3⟩
def targetCell : Allocation := ⟨32, .array 5 word, [(0, number 101), (16, number 103)], true, false⟩
def caller : State :=
  ⟨[(0, ⟨16, .array 3 word, [(0, number 10), (4, number 20), (8, number 30)], false, false⟩),
    (1, targetCell)], 2, 52⟩

def result : MemoryAir.Invocation → Option (Except Fault Value)
  | .finished outcome _ => some outcome
  | .suspended .. => none

def run (state : State) (destination origin : View) :=
  Generated.fn_copy.runFuel 128 (arguments destination origin) state

theorem caller_valid : caller.valid = true := by decide
theorem initializes_unwritten_target : result (run caller target source) = some (.ok (.scalar .unit)) := by decide +kernel
theorem preserves_neighbors :
    (List.range 5).map (fun i => load (run caller target source).state (({ target with first := 0 } : View).pointer i)) =
      [101, 10, 20, 30, 103].map (fun n => .ok (number n)) := by decide +kernel

def incomplete : State := { caller with heap :=
  [(0, ⟨16, .array 3 word, [(0, number 10)], false, false⟩), (1, targetCell)] }

theorem incomplete_valid : incomplete.valid = true := by decide
theorem missing_initialization_faults : result (run incomplete target source) = some (.error .uninitialized) := by decide +kernel
theorem failed_copy_keeps_reached_write :
    load (run incomplete target source).state (target.pointer 0) = .ok (number 10) ∧
    load (run incomplete target source).state (target.pointer 1) = .error .uninitialized := by decide +kernel

theorem exaggerated_length_faults :
    result (run caller { target with length := 4 } { source with length := 4 }) =
      some (.error .memoryValidity) := by decide +kernel

def shared : State :=
  ⟨[(0, ⟨16, .array 4 word, [(0, number 10), (4, number 20), (8, number 30), (12, number 40)], true, false⟩)], 1, 32⟩

theorem shared_valid : shared.valid = true := by decide
theorem overlapping_copy_succeeds : result (run shared ⟨0, 1, 3⟩ source) = some (.ok (.scalar .unit)) := by decide +kernel
theorem overlapping_copy_changes_source :
    load (run shared ⟨0, 1, 3⟩ source).state (source.pointer 1) = .ok (number 10) := by decide +kernel

end Compiler.Tutorial.Copy.Controls
