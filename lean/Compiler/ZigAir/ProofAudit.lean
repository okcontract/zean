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

/-- Encode the closed kernel type independently of local binder names, layout and pretty-printer
    settings. Constants and universe levels remain explicit. A change to a referenced definition
    is covered separately by the replay's input and library identities. -/
private partial def statementTree : Expr → Except String Json
  | .bvar n => pure <| toJson ("bound", n)
  | .sort u => pure <| toJson ("sort", reprStr u)
  | .const n us => pure <| toJson ("const", reprStr n, us.map reprStr)
  | .app f x => return Json.arr #["app", ← statementTree f, ← statementTree x]
  | .lam _ t b i => return Json.arr #["lam", toJson (reprStr i), ← statementTree t, ← statementTree b]
  | .forallE _ t b i => return Json.arr #["forall", toJson (reprStr i), ← statementTree t, ← statementTree b]
  | .letE _ t v b d => return Json.arr #["let", ← statementTree t, ← statementTree v, ← statementTree b, toJson d]
  | .lit l => pure <| toJson ("literal", reprStr l)
  | .proj n i x => return Json.arr #["proj", toJson (reprStr n), toJson i, ← statementTree x]
  | .mdata _ x => statementTree x
  | .mvar _ | .fvar _ => throw "theorem type contains a free variable"

/-- The consumer hashes these encodings and retains the separately audited axiom set. -/
def Compiler.ZigAir.ProofAudit.theoremStatements (names : List String) : CommandElabM Json := do
  let mut statements := Json.mkObj []
  for name in names do
    let some (.thmInfo info) := (← getEnv).find? name.toName | throwError "unknown theorem {name}"
    let .ok tree := statementTree info.type | throwError "invalid kernel type for {name}"
    statements := statements.setObjVal! name (toJson (info.levelParams.map reprStr, tree))
  return statements
