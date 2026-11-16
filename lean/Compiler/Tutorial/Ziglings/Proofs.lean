/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Ziglings.Bounds

/-! Connect the generated verification conditions to actual interpreter runs. -/
namespace Compiler.Tutorial.Ziglings
open Compiler.ZigAir Compiler.ZigAir.Memory Compiler.ZigAir.MemoryAir MemoryAir.Verify
open Memory.WordArray

theorem initialize_safe (state : State) (view : View) (first second : BitVec 32) (index : Nat)
    (valid : state.valid = true) (cap : Writable state view) (length : view.length = 2)
    (inside : index < 2) :
    match Generated.fn_initialize_pair.run (pairArguments view first second index) state with
    | (.ok result, after) => result = number (if index = 0 then first else second) ∧ after.valid = true
    | (.error fault, after) => fault = .outOfMemory ∧ after.valid = true :=
  finite_sound _ _ _ _ _ (initialize_contract state view first second index valid cap length inside) state rfl

theorem byte_safe (state : State) (address : Address) (length index : Nat) (contents : Nat → BitVec 8)
    (valid : state.valid = true)
    (cap : ReadView.Represents state (bytes address length) (fun i => byte (contents i)))
    (width : length < addressLimit) (indexBound : index < addressLimit) :
    match Generated.fn_phrase_byte.run (byteArguments address length index) state with
    | (.ok result, after) => result = (if index < length then byte (contents index) else byte 0) ∧
        after.valid = true ∧ after.heap = state.heap
    | (.error fault, after) => fault = .outOfMemory ∧ after.valid = true ∧ after.heap = state.heap :=
  finite_sound _ _ _ _ _ (byte_contract state address length index contents valid cap width indexBound) state rfl

end Compiler.Tutorial.Ziglings
