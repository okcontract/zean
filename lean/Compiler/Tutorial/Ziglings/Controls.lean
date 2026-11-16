/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Ziglings.Proofs

/-! Unsafe cases execute only in the Lean model. Expected values and faults are
recorded independently of the generated programs and the input constructors. -/
namespace Compiler.Tutorial.Ziglings.Controls
open Compiler.ZigAir Compiler.ZigAir.Memory Compiler.ZigAir.MemoryAir Memory.WordArray
deriving instance DecidableEq for Except
set_option maxRecDepth 4096
set_option maxHeartbeats 1000000

def pair : View := ⟨0, 0, 2⟩
def uninitialized : State := ⟨[(0, ⟨8, .array 2 word, [], true, false⟩)], 1, 16⟩
def initialized := Generated.fn_initialize_pair.run (pairArguments pair 20 10 1) uninitialized
def missing := Generated.fn_missing_character.run (pairArguments pair 20 10 1) uninitialized

theorem caller_valid : uninitialized.valid = true := by decide
theorem caller_writable : Writable uninitialized pair := ⟨2, _, rfl, rfl, rfl, by decide⟩
theorem corrected_initializes : initialized.1 = .ok (number 10) ∧
    load initialized.2 (pair.pointer 0) = .ok (number 20) ∧
    load initialized.2 (pair.pointer 1) = .ok (number 10) := by decide +kernel
theorem missing_initialization : missing.1 = .error .uninitialized := by decide +kernel
theorem reached_write_survives : load missing.2 (pair.pointer 0) = .ok (number 20) := by decide +kernel

def address : Address := ⟨0, 0⟩
def phrase : State :=
  ⟨[(0, ⟨8, .array 3 (.scalar (.int false 8)),
    [(0, byte 77), (1, byte 101), (2, byte 109)], false, false⟩)], 1, 11⟩
def bounded := Generated.fn_phrase_byte.run (byteArguments address 3 2) phrase
def oversized := Generated.fn_exaggerated_byte.run (byteArguments address 3 3) phrase

theorem phrase_valid : phrase.valid = true := by decide
theorem corrected_reads_last_byte : bounded.1 = .ok (byte 109) ∧ bounded.2.heap = phrase.heap := by decide +kernel
theorem corrected_rejects_index :
    (Generated.fn_phrase_byte.run (byteArguments address 3 3) phrase).1 = .ok (byte 0) := by decide +kernel
theorem exaggerated_extent : oversized.1 = .error .memoryValidity := by decide +kernel
theorem empty_needs_no_access :
    (Generated.fn_phrase_byte.run (byteArguments ⟨999, 0⟩ 0 0) phrase).1 = .ok (byte 0) := by decide +kernel

end Compiler.Tutorial.Ziglings.Controls
