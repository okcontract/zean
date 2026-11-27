/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.Captured
import Compiler.ZigAir.MemoryCall

/-! Independent interpretation of an acyclic captured call closure. Every
callee is decoded from inert AIR, rather than accepting an executable target
from the emitter. Finite callees may call other finite callees; the root may
loop. Identity matching includes the source file and its captured digest. -/
namespace Compiler.ZigAir.CapturedCalls
open Captured Memory MemoryAir

private def sameIdentity (raw expected : Raw) : Bool :=
  ["name", "sourceFile", "sourceSha256"].all fun key =>
    match raw.textAt key, expected.textAt key with
    | some left, some right => left == right
    | _, _ => false

def decode : Nat → (loops : Bool) → List Raw → Raw → Option (MemoryCall.Program loops)
  | 0, _, _, _ => none
  | fuel + 1, loops, closure, raw => do
    let input ← prepare raw .directCall
    let operation (inst : Raw) : Option MemoryCall.Prim := do
      if ["call", "call_never_inline", "call_never_tail"].contains (← inst.textAt "tag") then
        let callee ← inst.get "callee"
        require ((← callee.textAt "kind") == "function")
        let identity ← callee.get "identity"
        let [record] := closure.filter (sameIdentity · identity) | none
        let target ← decode fuel false closure record
        let arguments ← callArguments inst (← (← record.get "signature").listAt "parameters")
        require (arguments.length == target.parameters.length &&
          (← typeOf 17 (← inst.get "type")) == target.returnType)
        pure (.call target.target arguments)
      else pure (.memory (← primitive input.mapping inst input.table))
    let code ← bodyWith MemoryCall.Prim.memory operation loops input.table input.guards 1024 input.root
    pure ⟨input.parameters, input.returnType, code⟩

theorem interpretation_eq (raw : Raw) (closure : List Raw) (program : MemoryCall.Program loops)
    (certificate : decode fuel loops closure raw = some program)
    (decoded : decode fuel loops closure raw = some other) : other = program :=
  Option.some.inj (decoded.symm.trans certificate)

end Compiler.ZigAir.CapturedCalls
