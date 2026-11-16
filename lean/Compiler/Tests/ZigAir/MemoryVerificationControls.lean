/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryAutomation

/-! Synthetic clients of the public verification API; no native capture claim. -/
namespace Compiler.ZigAir.MemoryAir.Verify.Controls
open Memory Std.WP
set_option maxRecDepth 4096

private def echo : Program true :=
  ⟨[.scalar .bool], .scalar .bool, .bind 0 (.scalar .bool) (.argument 0) (.ret (.local 0))⟩

theorem echo_contract (state : State) (flag : Bool) (valid : state.valid = true) :
    Triple (Invocation.mk echo [.scalar (.bool flag)] (fun _ _ _ => False))
      (fun before => before = state)
      (fun value after => value = .scalar (.bool flag) ∧ after = state) (fun _ _ => False) := by
  unfold echo
  air_vcgen
  all_goals grind [value_valid_of_hasType, bool_typed, bool_valid, cleanup_initial]

/-- Symbolic machine integers exercise reference validation without evaluating
or enumerating their possible values. -/
theorem unsigned_echo (state : State) (n : Nat) (bound : n < addressLimit)
    (valid : state.valid = true) :
    Triple (Invocation.mk
      ⟨[usize], usize, .bind 8 usize (.argument 0) (.ret (.local 8))⟩
      [.scalar (.int false 64 n)] (fun _ _ _ => False))
      (fun before => before = state)
      (fun value after => value = .scalar (.int false 64 n) ∧ after = state) (fun _ _ => False) := by
  have typed := usize_typed n bound
  have valueValid := unsigned_valid 64 n bound
  dsimp only [usize]
  air_vcgen
  all_goals grind [cleanup_initial]

theorem symbolic_cast (state : State) (n : Nat) (bound : n < addressLimit) :
    Triple (Control.Verification.Atomic.mk (sem := semantics) (args := [])
      (.scalar (.cast .bitcast (.int false 64) (.constant (.int false 64 n)))) (fun _ => none))
      (fun before => before = state)
      (fun value after => value = .scalar (.int false 64 n) ∧ after = state) (fun _ _ => False) := by
  have valid := unsigned_valid 64 n bound
  have normalized := normalize_unsigned_valid 64 n valid
  air_vcgen

theorem symbolic_element (state : State) (address : Address) (n : Nat) (bound : n < addressLimit)
    (value : Value)
    (success : elementPointer state (.pointer (.pointer true true WordArray.word) address) n = .ok value) :
    Triple (Control.Verification.Atomic.mk (sem := semantics) (args := [])
      (.elementPointer (.constant (.pointer (.pointer true true WordArray.word) address))
        (.constant (.scalar (.int false 64 n)))) (fun _ => none))
      (fun before => before = state) (fun actual after => actual = value ∧ after = state)
      (fun _ _ => False) := by
  have valid := unsigned_valid 64 n bound
  air_vcgen

/-- An unused load still needs initialization; its fault keeps the caller heap. -/
theorem failed_load (state : State) (address : Address) (fault : Fault)
    (valid : state.valid = true)
    (failed : load state (.pointer (.pointer false false WordArray.word) address) = .error fault) :
    Triple (Invocation.mk
      ⟨[], .scalar .unit, .bind 23 WordArray.word
        (.load (.constant (.pointer (.pointer false false WordArray.word) address)))
        (.ret (.constant (.scalar .unit)))⟩ [] (fun _ _ _ => False))
      (fun before => before = state) (fun _ _ => False)
      (fun actual after => actual = fault ∧ after = state) := by
  air_vcgen
  all_goals grind [cleanup_initial]

/-- Cleanup does not erase a successful caller write when a later dead
instruction faults. -/
theorem store_then_fault (state written : State) (address : Address) (value : Value)
    (valid : state.valid = true) (valueValid : value.valid = true)
    (stored : store state (.pointer (.pointer true false WordArray.word) address)
      value = .ok written) :
    Triple (Invocation.mk
      ⟨[], .scalar .unit,
        .bind 91 (.scalar .unit)
          (.store (.constant (.pointer (.pointer true false WordArray.word) address))
            (.constant value))
          (.bind 17 (.scalar .unit) (.argument 0) (.ret (.constant (.scalar .unit))))⟩
      [] (fun _ _ _ => False))
      (fun before => before = state) (fun _ _ => False)
      (fun fault after => fault = .malformed ∧ after = written) := by
  have counters := store_keeps_counters state _ _ written stored
  have heapValid := store_preserves_valid state _ _ written valid stored
  air_vcgen
  all_goals grind [cleanup_initial]

/-- Multiple fresh allocations preserve an earlier initialized local. This
also checks that normalization retains allocation history for cleanup proofs. -/
theorem two_saved_pointers (state : State) (address : Address) (valid : state.valid = true) :
    Triple (Invocation.mk
      ⟨[], .pointer true false WordArray.word,
        .bind 81 (.pointer true false (.pointer true false WordArray.word))
          (.alloc (.pointer true false WordArray.word))
          (.bind 82 (.scalar .unit)
            (.store (.local 81) (.constant (.pointer (.pointer true false WordArray.word) address)))
            (.bind 7 (.pointer true false (.pointer true false WordArray.word))
              (.alloc (.pointer true false WordArray.word))
              (.bind 8 (.scalar .unit)
                (.store (.local 7) (.constant (.pointer (.pointer true false WordArray.word) address)))
                (.bind 9 (.pointer true false WordArray.word) (.load (.local 81)) (.ret (.local 9))))))⟩
      [] (fun _ _ _ => False))
      (fun before => before = state)
      (fun value after => value = .pointer (.pointer true false WordArray.word) address ∧
        after.valid = true ∧ after.heap = state.heap)
      (fun fault after => fault = .outOfMemory ∧ after.valid = true ∧ after.heap = state.heap) := by
  have frame := StackFrame.refl state valid
  air_vcgen
  air_finish [StackFrame.cleanup_heap, StackFrame.cleanup_valid]

end Compiler.ZigAir.MemoryAir.Verify.Controls
