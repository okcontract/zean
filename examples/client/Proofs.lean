/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Cell.Generated
import Compiler.ZigAir.Verify.Words

namespace Cell
open Compiler.ZigAir Compiler.ZigAir.Memory Compiler.ZigAir.MemoryAir MemoryAir.Verify
open Memory.WordArray Std.WP
set_option maxRecDepth 4096
set_option maxHeartbeats 1000000

theorem contract (state : State) (view : View) (value : BitVec 32)
    (valid : state.valid = true) (writable : Writable state view) (nonempty : 0 < view.length) :
    Triple (Verify.Invocation.mk Generated.fn_put.enableLoops [view.pointer 0, number value]
      (fun _ _ _ => False)) (fun before => before = state)
      (fun _ after => after.valid = true) ResourceOnly := by
  have initialFrame := StackFrame.refl state valid
  dsimp only [Generated.fn_put, ResourceOnly]
  air_vcgen
  air_word_finish

/-- Every finite execution prefix avoids memory faults for an arbitrary valid
writable caller region. Resource exhaustion remains an explicit outcome. -/
theorem safe (state : State) (view : View) (value : BitVec 32)
    (valid : state.valid = true) (writable : Writable state view) (nonempty : 0 < view.length) :
    Safe Generated.fn_put.enableLoops [view.pointer 0, number value] state :=
  safe_of_contract _ _ _ (contract state view value valid writable nonempty) state rfl

end Cell
