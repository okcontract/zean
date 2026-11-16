/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryPartialCallWP

/-! Synthetic execution controls for the generic observation semantics. These
are not native captures. Expected faults and effects are specified separately
from constructing each program. -/
namespace Compiler.Tests.ZigAir.MemoryPartialCallControls
open Compiler.ZigAir Compiler.ZigAir.Memory MemoryPartialCall

def byte : Ty := .scalar (.int false 8)
def unitRef : MemoryAir.Ref := .constant (.scalar .unit)

def spin : MemoryCall.Program true :=
  ⟨[], .scalar .unit, .bind 0 (.pointer true false byte) (.memory (.alloc byte))
    (.loop rfl 1 (.repeat rfl 1))⟩

def spinCaller : Program :=
  ⟨[], .scalar .unit, .bind 0 (.scalar .unit) (.call (Target.loop spin) [])
    (.bind 1 (.scalar .unit) (.memory .unreachable) (.ret unitRef))⟩

theorem suspended_call_keeps_locals :
    (match spinCaller.observe 30 [] {} with
    | .pending state => decide (state.heap.length = 1 ∧ state.nextId = 1 ∧ state.nextAddress = 9)
    | .finished .. => false) = true := by decide +kernel

def fails : MemoryCall.Program true :=
  ⟨[], byte, .loop rfl 3
    (.bind 0 byte (.memory (.load (.constant (.pointer (.pointer false false byte) ⟨99, 0⟩))))
      (.ret (.local 0)))⟩

def failedCaller : Program :=
  ⟨[], byte, .bind 0 byte (.call (Target.loop fails) []) (.ret (.local 0))⟩

theorem exhausted_observation_is_pending : failedCaller.observe 0 [] {} = .pending {} := rfl
theorem later_callee_fault_is_visible : failedCaller.observe 10 [] {} = .finished (.error .unallocated) {} := rfl
theorem caller_not_safe : ¬Safe failedCaller [] {} := by
  intro safe
  have impossible := safe 10 .unallocated {} later_callee_fault_is_visible
  contradiction

def returns : MemoryCall.Program true :=
  ⟨[], .scalar .unit, .loop rfl 7 (.ret unitRef)⟩

def afterReturn : Program :=
  ⟨[], .scalar .unit, .bind 0 (.scalar .unit) (.call (Target.loop returns) [])
    (.bind 1 (.scalar .unit) (.memory .unreachable) (.ret unitRef))⟩

theorem suffix_fault_is_visible :
    afterReturn.observe 10 [] {} = .finished (.error (.scalar .illegalBehavior)) {} := rfl

def nested : Program :=
  ⟨[], .scalar .unit, .bind 0 (.scalar .unit) (.call afterReturn.target []) (.ret unitRef)⟩

theorem nested_call_keeps_fault :
    nested.observe 10 [] {} = .finished (.error (.scalar .illegalBehavior)) {} := rfl

theorem completed_observation_is_stable (extra : Nat) :
    nested.observe (10 + extra) [] {} = .finished (.error (.scalar .illegalBehavior)) {} :=
  nested.finished_stable 10 extra [] {} {} _ nested_call_keeps_fault

end Compiler.Tests.ZigAir.MemoryPartialCallControls
