/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.Captured
import Compiler.ZigAir.MemoryCallMachine

/-! Independent decoding into data-based functions. A call selects a unique
declaration with an exact source identity and matching signature. The acyclic
decoder restricts references to earlier bodies. The recursive decoder uses the
complete table and still checks every body. -/
namespace Compiler.ZigAir.CapturedCallMachine
open Captured Memory MemoryAir MemoryCallMachine

private structure Identity where
  name : String
  file : String
  sha256 : String
  deriving BEq

private def readIdentity (raw : Raw) : Option Identity := do
  let name ← raw.textAt "name"
  let file ← raw.textAt "sourceFile"
  let sha ← raw.textAt "sourceSha256"
  require (!name.isEmpty && !file.isEmpty && sha.length == 64 &&
    sha.toList.all (fun ch => ('0' ≤ ch && ch ≤ '9') || ('a' ≤ ch && ch ≤ 'f')))
  pure ⟨name, file, sha⟩

def sameIdentity (raw expected : Raw) : Bool :=
  match readIdentity raw, readIdentity expected with
  | some left, some right => left == right
  | _, _ => false

private structure Entry where
  identity : Identity
  index : Nat
  input : Input

/-- Validate all declarations, including leaves that no call references. -/
private def entries (records : List Raw) : Option (List Entry) := do
  let reversed ← records.zipIdx.foldlM (init := []) fun (seen : List Entry) (raw, index) => do
    let identity ← readIdentity raw
    require (!seen.any (·.identity == identity))
    pure (⟨identity, index, ← prepare raw .directCall⟩ :: seen)
  pure reversed.reverse

private def functionWithTargets (targets : List Entry) (entry : Entry) (allowRecursion : Bool) :
    Option Function := do
  let input := entry.input
  let operation (inst : Raw) : Option MemoryCallMachine.Prim := do
    if ["call", "call_never_inline", "call_never_tail"].contains (← inst.textAt "tag") then
      let callee ← inst.get "callee"
      require ((← callee.textAt "kind") == "function")
      let identity ← readIdentity (← callee.get "identity")
      let target ← targets.find? (·.identity == identity)
      require (allowRecursion || target.index < entry.index)
      let arguments ← (← inst.listAt "arguments").mapM reference
      require (arguments.length == target.input.parameters.length &&
        (← typeOf 17 (← inst.get "type")) == target.input.returnType)
      pure (.call target.index arguments)
    else pure (.memory (← primitive input.mapping inst input.table))
  let code ← bodyWith MemoryCallMachine.Prim.memory operation true input.table input.guards 1024 input.root
  pure ⟨input.parameters, input.returnType, code⟩

def function (earlier : List Raw) (raw : Raw) : Option Function := do
  let table ← entries (earlier ++ [raw])
  functionWithTargets table (← table.getLast?) false

private def decodeWith (records : List Raw) (allowRecursion : Bool) :
    Option MemoryCallMachine.Program := do
  let table ← entries records
  table.mapM (functionWithTargets table · allowRecursion)

def decode (records : List Raw) : Option MemoryCallMachine.Program := decodeWith records false

def decodeRecursive (records : List Raw) : Option MemoryCallMachine.Program := decodeWith records true

theorem interpretation_eq (records : List Raw) (program other : MemoryCallMachine.Program)
    (certificate : decode records = some program) (decoded : decode records = some other) :
    other = program := Option.some.inj (decoded.symm.trans certificate)

end Compiler.ZigAir.CapturedCallMachine
