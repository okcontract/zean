/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.Verify.Core
import Compiler.ZigAir.MemoryResourceAutomation

namespace Compiler.ZigAir.MemoryAir.Verify.ResourceControls
open Memory Std.WP
set_option maxRecDepth 4096

def allocateOne : Program :=
  ⟨[], .scalar .unit, .bind 0 (.pointer true false usize) (.alloc usize)
    (.ret (.constant (.scalar .unit)))⟩

theorem allocation_contract (state : State) (valid : state.valid = true)
    (room : AllocationRoom state.nextAddress usize) :
    Triple (Invocation.mk allocateOne.enableLoops [] (fun _ _ _ => False))
      (fun before => before = state)
      (fun value after => value = .scalar .unit ∧ after.valid = true ∧ after.heap = state.heap)
      (fun _ _ => False) := by
  have frame := StackFrame.refl state valid
  unfold allocateOne
  air_vcgen
  air_finish [allocate_no_fault, StackFrame.cleanup_heap, StackFrame.cleanup_valid]

theorem allocation_completes (state : State) (valid : state.valid = true)
    (room : AllocationRoom state.nextAddress usize) :
    Completes allocateOne.enableLoops [] state
      (fun value after => value = .scalar .unit ∧ after.valid = true ∧ after.heap = state.heap) :=
  finite_completes _ _ _ _ (allocation_contract state valid room) state rfl

/-- An allowed exhaustion is not successful completion. Even an empty valid
heap can run out of modeled address history. -/
def exhausted : State := ⟨[], 0, addressLimit - 8⟩

theorem exhausted_valid : exhausted.valid = true := by decide +kernel
theorem exhausted_result : allocateOne.run [] exhausted = (.error .outOfMemory, exhausted) := by
  rfl
theorem exhausted_has_no_room : ¬ AllocationRoom exhausted.nextAddress usize := by
  intro room
  obtain ⟨value, after, success⟩ := allocate_total exhausted usize exhausted_valid room
  have failed : allocate exhausted usize = .error .outOfMemory := rfl
  rw [failed] at success
  contradiction

/-- A caller's two-slot budget survives the first allocation and its store.
The second allocation needs no assumed-success premise. -/
theorem two_slice_budget (before allocated current : State) (pointer value : Value)
    (positive : 0 < before.nextAddress)
    (budget : before.nextAddress + 46 < addressLimit)
    (first : allocate before (.slice firstWritable firstChild) = .ok (pointer, allocated))
    (saved : store allocated pointer value = .ok current)
    (failed : allocate current (.slice secondWritable secondChild) = .error fault) : False := by
  have allocatedValid := allocate_preserves_valid before _ pointer allocated first
  have currentValid := store_preserves_valid allocated pointer value current allocatedValid saved
  air_resources
  air_split
  air_resources
  air_false

end Compiler.ZigAir.MemoryAir.Verify.ResourceControls
