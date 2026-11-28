/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Lean.Util.CollectAxioms
import Lean.Elab.Command

/-! Client replay checks named theorems and their transitive axiom dependencies.
The standard Lean logical axioms are permitted; `sorryAx` and client axioms are
not. This does not infer that the user-selected proposition is a safety contract. -/
open Lean Elab Command

private def auditProof (declaration : Name) (modules : Option (Array Name)) : CommandElabM (Array Name) := do
  match (← getEnv).find? declaration with
  | some (.thmInfo _) => pure ()
  | _ => throwError "expected a checked theorem: {declaration}"
  if let some modules := modules then
    let origin ← findModuleOf? declaration
    unless modules.any (fun module => origin == some module) do
      throwError "theorem {declaration} is not declared in a checked client proof module"
  let axioms ← collectAxioms declaration
  for axiomName in axioms do
    unless #[``propext, ``Classical.choice, ``Quot.sound].contains axiomName do
      throwError "theorem {declaration} depends on unsupported axiom {axiomName}"
  return axioms

elab "#audit_proof " name:str : command => do
  discard <| auditProof name.getString.toName none

elab "#audit_proof " name:str " from " "[" modules:str,* "]" : command => do
  discard <| auditProof name.getString.toName (some (modules.getElems.map fun module => module.getString.toName))

/-- Audit each manifest's theorems against its own proof modules, including shared declarations. -/
def Compiler.ZigAir.ProofAudit.theoremAxioms (groups : Array (Array String × Array String)) :
    CommandElabM Json := do
  let mut result := Json.mkObj []
  for (theorems, modules) in groups do
    let owners := modules.map String.toName
    for theoremName in theorems do
      let axioms ← auditProof theoremName.toName (some owners)
      result := result.setObjVal! theoremName (toJson ((axioms.map Name.toString).qsort (· < ·)))
  return result

/-- Fresh replay modules intentionally have random names. Restore only the private-name
    prefix of an actual module in this replay, preserving both its owner and local name. -/
private def stableName (modules : List (String × String)) : Name → Name
  | .str (.str .anonymous "_private") m =>
    match modules.lookup m with
    | some owner => `_private ++ owner.toName
    | none => Name.str `_private m
  | .str p s => .str (stableName modules p) s
  | .num p i => .num (stableName modules p) i
  | .anonymous => .anonymous

/-- Encode the closed kernel type independently of local binder names, layout and pretty-printer
    settings. Constants and universe levels remain explicit. A change to a referenced definition
    is covered separately by the replay's input and library identities. -/
private partial def statementTree (normalize : Name → Name) : Expr → Except String Json
  | .bvar n => pure <| toJson ("bound", n)
  | .sort u => pure <| toJson ("sort", reprStr u)
  | .const n us => pure <| toJson ("const", reprStr (normalize n), us.map reprStr)
  | .app f x => return Json.arr #["app", ← statementTree normalize f, ← statementTree normalize x]
  | .lam _ t b i => return Json.arr #["lam", toJson (reprStr i), ← statementTree normalize t, ← statementTree normalize b]
  | .forallE _ t b i => return Json.arr #["forall", toJson (reprStr i), ← statementTree normalize t, ← statementTree normalize b]
  | .letE _ t v b d => return Json.arr #["let", ← statementTree normalize t, ← statementTree normalize v, ← statementTree normalize b, toJson d]
  | .lit l => pure <| toJson ("literal", reprStr l)
  | .proj n i x => return Json.arr #["proj", toJson (reprStr (normalize n)), toJson i, ← statementTree normalize x]
  | .mdata _ x => statementTree normalize x
  | .mvar _ | .fvar _ => throw "theorem type contains a free variable"

/-- The consumer hashes these encodings and retains the separately audited axiom set. -/
def Compiler.ZigAir.ProofAudit.theoremStatements (names : List String)
    (modules : List (String × String) := []) : CommandElabM Json := do
  let mut statements := Json.mkObj []
  for name in names do
    let some (.thmInfo info) := (← getEnv).find? name.toName | throwError "unknown theorem {name}"
    let .ok tree := statementTree (stableName modules) info.type | throwError "invalid kernel type for {name}"
    statements := statements.setObjVal! name (toJson (info.levelParams.map reprStr, tree))
  return statements
