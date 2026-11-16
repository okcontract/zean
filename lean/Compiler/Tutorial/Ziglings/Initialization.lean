/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Ziglings.Generated
import Compiler.ZigAir.Verify.Words

namespace Compiler.Tutorial.Ziglings
open Compiler.ZigAir Compiler.ZigAir.Memory Compiler.ZigAir.MemoryAir MemoryAir.Verify
open Memory.WordArray Std.WP

def size (n : Nat) : Value := .scalar (.int false 64 n)
def pairArguments (view : View) (first second : BitVec 32) (index : Nat) : List Value :=
  [view.buffer, number first, number second, size index]

set_option maxHeartbeats 2000000
set_option maxRecDepth 4096

/-- No initial contents are assumed. Two writable slots and an in-bounds index
suffice: successful execution returns the selected newly initialized value;
the only permitted failure is modeled stack exhaustion. -/
theorem initialize_contract (state : State) (view : View) (first second : BitVec 32) (index : Nat)
    (valid : state.valid = true) (cap : Writable state view) (length : view.length = 2)
    (inside : index < 2) :
    Triple (Verify.Invocation.mk Generated.fn_initialize_pair.enableLoops
      (pairArguments view first second index) (fun _ _ _ => False))
      (fun before => before = state)
      (fun result after => result = number (if index = 0 then first else second) ∧ after.valid = true)
      (fun fault after => fault = .outOfMemory ∧ after.valid = true) := by
  have initialFrame := StackFrame.refl state valid
  have choices : index = 0 ∨ index = 1 := by omega
  rcases choices with rfl | rfl
  all_goals dsimp only [Generated.fn_initialize_pair, pairArguments, size]
  all_goals air_vcgen
  air_word_finish (gen := 16) (ematch := 10) (verbose := false) [write_frame, StackFrame.store_local]

end Compiler.Tutorial.Ziglings
