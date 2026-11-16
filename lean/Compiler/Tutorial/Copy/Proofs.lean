/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Copy.Verification

namespace Compiler.Tutorial.Copy
open Compiler.ZigAir Compiler.ZigAir.Memory Compiler.ZigAir.MemoryAir MemoryAir.Verify
open Memory.WordArray Memory.WordCopy

/-- The contract holds at every execution prefix, without a fixed fuel bound
or a termination assumption. -/
theorem copy_observes (initial : State) (target source : View) (items : List (BitVec 32))
    (valid : initial.valid = true) (writable : Writable initial target) (readable : Readable initial source)
    (original : Represents initial source items) (length : source.length = target.length)
    (apart : disjoint source target = true) (fuel : Nat) :
    Observes (Completed initial target source items) (Exhausted initial target source items)
      (Generated.fn_copy.runFuel fuel (arguments target source) initial) :=
  sound _ _ _ _ (copy_contract initial target source items valid writable readable original length apart)
    initial rfl fuel

theorem copy_safe (initial : State) (target source : View) (items : List (BitVec 32))
    (valid : initial.valid = true) (writable : Writable initial target) (readable : Readable initial source)
    (original : Represents initial source items) (length : source.length = target.length)
    (apart : disjoint source target = true) :
    Safe Generated.fn_copy (arguments target source) initial := by
  intro fuel fault after reached
  have observed := copy_observes initial target source items valid writable readable original length apart fuel
  rw [reached] at observed
  exact observed.1

/-- Completion gives the copied contents and preserves the original source
and every caller location outside the destination view. -/
theorem copy_correct (initial : State) (target source : View) (items : List (BitVec 32))
    (valid : initial.valid = true) (writable : Writable initial target) (readable : Readable initial source)
    (original : Represents initial source items) (length : source.length = target.length)
    (apart : disjoint source target = true) (fuel : Nat) (value : Value) (after : State)
    (finished : Generated.fn_copy.runFuel fuel (arguments target source) initial = .finished (.ok value) after) :
    Completed initial target source items value after := by
  have observed := copy_observes initial target source items valid writable readable original length apart fuel
  rwa [finished] at observed

end Compiler.Tutorial.Copy
