/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Ziglings.Initialization
import Compiler.ZigAir.Verify.Reads

namespace Compiler.Tutorial.Ziglings
open Compiler.ZigAir Compiler.ZigAir.Memory Compiler.ZigAir.MemoryAir MemoryAir.Verify Std.WP

def byte (n : BitVec 8) : Value := .scalar (.int false 8 n.toNat)
def bytes (address : Address) (length : Nat) : ReadView :=
  ⟨.scalar (.int false 8), ⟨1, 1⟩, rfl, by decide, address, length⟩
def byteArguments (address : Address) (length index : Nat) : List Value :=
  [(bytes address length).buffer, size length, size index]

set_option maxHeartbeats 2000000
set_option maxRecDepth 4096

/-- A caller supplies the true readable extent and initialized byte contents.
The result is the indexed byte, or zero when the index is outside the slice.
Caller memory is unchanged, including on modeled stack exhaustion. -/
private theorem byte_contract_int (state : State) (address : Address) (length index : Int) (contents : Nat → BitVec 8)
    (valid : state.valid = true)
    (cap : ReadView.Represents state (bytes address length.toNat) (fun i => byte (contents i)))
    (lower : 0 ≤ length) (indexLower : 0 ≤ index)
    (width : length < (addressLimit : Int)) (indexBound : index < (addressLimit : Int)) :
    Triple (Verify.Invocation.mk Generated.fn_phrase_byte.enableLoops
      [(bytes address length.toNat).buffer, .scalar (.int false 64 length), .scalar (.int false 64 index)]
      (fun _ _ _ => False))
      (fun before => before = state)
      (fun result after => result = (if index < length then byte (contents index.toNat) else byte 0) ∧
        after.valid = true ∧ after.heap = state.heap)
      (fun fault after => fault = .outOfMemory ∧ after.valid = true ∧ after.heap = state.heap) := by
  have initialFrame := StackFrame.refl state valid
  dsimp only [Generated.fn_phrase_byte, ReadView.buffer, bytes]
  air_vcgen
  air_read_finish (gen := 16) (ematch := 10) (verbose := false) [bytes, byte]

theorem byte_contract (state : State) (address : Address) (length index : Nat) (contents : Nat → BitVec 8)
    (valid : state.valid = true)
    (cap : ReadView.Represents state (bytes address length) (fun i => byte (contents i)))
    (width : length < addressLimit) (indexBound : index < addressLimit) :
    Triple (Verify.Invocation.mk Generated.fn_phrase_byte.enableLoops
      (byteArguments address length index) (fun _ _ _ => False))
      (fun before => before = state)
      (fun result after => result = (if index < length then byte (contents index) else byte 0) ∧
        after.valid = true ∧ after.heap = state.heap)
      (fun fault after => fault = .outOfMemory ∧ after.valid = true ∧ after.heap = state.heap) := by
  simpa [byteArguments, size] using byte_contract_int state address length index contents valid cap
    (by omega) (by omega) (by exact_mod_cast width) (by exact_mod_cast indexBound)

end Compiler.Tutorial.Ziglings
