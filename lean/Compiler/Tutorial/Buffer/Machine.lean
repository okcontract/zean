/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Buffer.Verification
import Compiler.ZigAir.Verify.Machine

namespace Compiler.Tutorial.Buffer
open Compiler.ZigAir Compiler.ZigAir.Memory Memory.WordArray

/-- The same checked contract on the canonical machine, for every budget.
No instruction-specific proof is needed to transfer the result. -/
theorem machine_contract (version : Version) (state : State) (view : View) (index : Nat) (value : BitVec 32)
    (valid : state.valid = true) (cap : Writable state view) (indexBound : index < addressLimit) (fuel : Nat) :
    MemoryCallMachine.Observes
      (fun result after => Spec.SafeResult state view index value (.ok result) after)
      (fun fault after => Spec.SafeResult state view index value (.error fault) after)
      (MemoryCallMachine.run [MemoryCallMachine.Function.ofMemory (program version).enableLoops]
        fuel 0 (arguments view index value) state) :=
  MemoryCallMachine.ofMemory_contract _ _ _ _ _ _
    (replace_contract version state view index value valid cap indexBound) state rfl fuel

end Compiler.Tutorial.Buffer
