/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.Captured
import Compiler.ZigAir.MemoryCallMachine

/-! Independent decoding into data-based functions. A call may reference only
an earlier declaration in the table, with an exact source identity/signature.
This gives an acyclic closure without executing or trusting a callee summary. -/
namespace Compiler.ZigAir.CapturedCallMachine
open Captured Memory MemoryAir MemoryCallMachine

def sameIdentity (raw expected : Raw) : Bool :=
  ["name", "sourceFile", "sourceSha256"].all fun key =>
    match raw.textAt key, expected.textAt key with
    | some left, some right => left == right
    | _, _ => false

def function (earlier : List Raw) (raw : Raw) : Option Function := do
  require (!(earlier.any (sameIdentity · raw)))
  let input ← prepare raw
  let operation (inst : Raw) : Option MemoryCallMachine.Prim := do
    if ["call", "call_never_inline", "call_never_tail"].contains (← inst.textAt "tag") then
      let callee ← inst.get "callee"
      require ((← callee.textAt "kind") == "function")
      let identity ← callee.get "identity"
      let [(record, index)] := earlier.zipIdx.filter (fun (record, _) => sameIdentity record identity) | none
      let signature ← prepare record
      let arguments ← (← inst.listAt "arguments").mapM reference
      require (arguments.length == signature.parameters.length &&
        (← typeOf 17 (← inst.get "type")) == signature.returnType)
      pure (.call index arguments)
    else pure (.memory (← primitive input.mapping inst input.table))
  let code ← bodyWith MemoryCallMachine.Prim.memory operation true input.table input.guards 1024 input.root
  pure ⟨input.parameters, input.returnType, code⟩

def decode (records : List Raw) : Option MemoryCallMachine.Program :=
  (records.zipIdx).mapM fun (record, index) => function (records.take index) record

theorem interpretation_eq (records : List Raw) (program other : MemoryCallMachine.Program)
    (certificate : decode records = some program) (decoded : decode records = some other) :
    other = program := Option.some.inj (decoded.symm.trans certificate)

end Compiler.ZigAir.CapturedCallMachine
