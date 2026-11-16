/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Buffer.Inputs
import Compiler.Tutorial.Buffer.Contracts
import Compiler.ZigAir.Verify.Words

/-! The generated programs are clients of the generic verifier. Neither proof
imports the historical instruction-by-instruction execution development. -/
namespace Compiler.Tutorial.Buffer
open Compiler.ZigAir Compiler.ZigAir.Memory Compiler.ZigAir.MemoryAir MemoryAir.Verify
open Memory.WordArray Std.WP

set_option maxHeartbeats 2000000
set_option maxRecDepth 4096

theorem replace_contract (version : Version) (state : State) (view : View) (index : Nat) (value : BitVec 32)
    (valid : state.valid = true) (cap : Writable state view) (indexBound : index < addressLimit) :
    Triple (Verify.Invocation.mk (program version).enableLoops (arguments view index value) (fun _ _ _ => False))
      (fun before => before = state)
      (fun result after => Spec.SafeResult state view index value (.ok result) after)
      (fun fault after => Spec.SafeResult state view index value (.error fault) after) := by
  have initialFrame := StackFrame.refl state valid
  cases version <;> dsimp only [program, V1.Generated.fn_replace, V2.Generated.fn_replace, arguments, size]
  all_goals air_vcgen
  air_word_finish [Spec.exhausted, Spec.rejected, Spec.replaced]

end Compiler.Tutorial.Buffer
