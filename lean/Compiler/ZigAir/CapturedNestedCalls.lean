/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.CapturedCalls
import Compiler.ZigAir.MemoryPartialCallStability

/-! Independently decode acyclic calls with looping callees. Finite bodies use
the total evaluator; a looping body with finite callees uses the existing loop
machine. Further callers use finite observations with stable completion. -/
namespace Compiler.ZigAir.CapturedNestedCalls
open Captured Memory MemoryPartialCall

private def sameIdentity (raw expected : Raw) : Bool :=
  ["name", "sourceFile", "sourceSha256"].all fun key =>
    match raw.textAt key, expected.textAt key with
    | some left, some right => left == right
    | _, _ => false

def decode : Nat → List Raw → Raw → Option Program
  | 0, _, _ => none
  | fuel + 1, closure, raw => do
    let input ← prepare raw .directCall
    let operation (inst : Raw) : Option MemoryPartialCall.Prim := do
      if ["call", "call_never_inline", "call_never_tail"].contains (← inst.textAt "tag") then
        let callee ← inst.get "callee"
        require ((← callee.textAt "kind") == "function")
        let identity ← callee.get "identity"
        let [record] := closure.filter (sameIdentity · identity) | none
        let (target, parameters, returnType) ←
          if let some finite := CapturedCalls.decode 64 false closure record then
            pure (Target.finite finite.target, finite.parameters, finite.returnType)
          else if let some looping := CapturedCalls.decode 64 true closure record then
            pure (Target.loop looping, looping.parameters, looping.returnType)
          else do
            let nested ← decode fuel closure record
            pure (nested.target, nested.parameters, nested.returnType)
        let arguments ← callArguments inst (← (← record.get "signature").listAt "parameters")
        require (arguments.length == parameters.length && (← typeOf 17 (← inst.get "type")) == returnType)
        pure (.call target arguments)
      else pure (.memory (← primitive input.mapping inst input.table))
    let code ← bodyWith MemoryPartialCall.Prim.memory operation true input.table input.guards 1024 input.root
    pure ⟨input.parameters, input.returnType, code⟩

theorem interpretation_eq (raw : Raw) (closure : List Raw) (program other : Program)
    (certificate : decode fuel closure raw = some program)
    (decoded : decode fuel closure raw = some other) : other = program :=
  Option.some.inj (decoded.symm.trans certificate)

end Compiler.ZigAir.CapturedNestedCalls
