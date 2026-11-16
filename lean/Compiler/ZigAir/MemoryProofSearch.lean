/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryAutomation
import Lean.Elab.Tactic.Omega

namespace Compiler.ZigAir.MemoryAir.Verify
open Lean Meta

initialize registerTraceClass `air.inference

/-- Stop a batch at the first failed condition, instead of recovering and
continuing through the other VCs with a failed elaboration. -/
elab "air_strict" " => " body:Lean.Parser.Tactic.tacticSeq : tactic =>
  Lean.Elab.Tactic.withoutRecover (Lean.Elab.Tactic.evalTactic body)

/-- Check an independent VC in a separate metavariable context, then retain its
ordinary auxiliary theorem. Search caches and intermediate goals can otherwise
accumulate across hundreds of VCs. Shared unresolved metavariables reject this
mode; the theorem and its application are still checked by the kernel. -/
elab "air_separate" " => " body:Lean.Parser.Tactic.tacticSeq : tactic =>
  Lean.Elab.Tactic.withMainContext do
    let goal ← Lean.Elab.Tactic.getMainGoal
    let type ← instantiateMVars (← goal.getType)
    if type.hasMVar then throwError "air_separate requires an independent verification condition"
    for declaration in ← getLCtx do
      if (← instantiateMVars declaration.type).hasMVar then
        throwError "air_separate requires a fully determined local context"
    let original ← getMCtx
    let localGoal ← mkFreshExprMVar type
    let remaining ← Lean.Elab.withEnableInfoTree false <|
      Lean.Elab.Tactic.run localGoal.mvarId! <|
        Lean.Elab.Tactic.withoutRecover (Lean.Elab.Tactic.evalTactic body)
    unless remaining.isEmpty do throwError "air_separate left unresolved verification conditions"
    let proof ← instantiateMVars localGoal
    if proof.hasMVar then throwError "air_separate left unresolved proof metavariables"
    let checked ← mkAuxTheorem type proof
    setMCtx original
    modifyThe Lean.Meta.State fun state => { state with cache := {} }
    goal.assign checked
    Lean.Elab.Tactic.replaceMainGoal []

/-- Match explicit facts without unfolding heap predicates. The resulting
expressions are ordinary theorem applications checked by Lean's kernel. -/
private def matchingHead (left right : Expr) : Bool :=
  if left.isAppOf ``Eq && right.isAppOf ``Eq then Id.run do
    if left.getAppArgs[1]!.getAppFn != right.getAppArgs[1]!.getAppFn then return false
    let a := left.getAppArgs[2]!
    let b := right.getAppArgs[2]!
    -- Refute distinct result constructors before asking definitional equality
    -- to compare their potentially large interpreter applications.
    if (a.isAppOf ``Except.error && b.isAppOf ``Except.ok) ||
        (a.isAppOf ``Except.ok && b.isAppOf ``Except.error) then return false
    return true
  else left.getAppFn == right.getAppFn

/-- Forward matching treats an operation as a symbol. If its explicit operands
do not unify, unfolding the interpreter cannot produce a useful rule match. -/
private def matchingType (left right : Expr) : MetaM Bool := do
  if left.isAppOf ``Eq && right.isAppOf ``Eq then
    let a := left.getAppArgs[1]!.getAppArgs
    let b := right.getAppArgs[1]!.getAppArgs
    if a.size != b.size then return false
    for (x, y) in a.zip b do
      if !(← isDefEq x y) then return false
  else
    -- Heap predicates are symbols too. Comparing whole predicates at distinct
    -- states would unfold their quantified definitions before discovering the
    -- mismatch, even though no rule can use that pair of facts.
    let a := left.getAppArgs
    let b := right.getAppArgs
    if a.size != b.size then return false
    for (x, y) in a.zip b do
      if !(← isDefEq x y) then return false
  isDefEq left right

private partial def arithmeticFact (type : Expr) : Bool :=
  if let .mdata _ inner := type then arithmeticFact inner
  else if type.isAppOf ``Not then arithmeticFact type.getAppArgs[0]!
  else if let .forallE _ premise conclusion _ := type then
    conclusion.isConstOf ``False && arithmeticFact premise
  else if type.isAppOf ``Eq || type.isAppOf ``Ne || type.isAppOf ``LT.lt || type.isAppOf ``LE.le then
    let domain := type.getAppArgs[0]!
    domain.isConstOf ``Nat || domain.isConstOf ``Int
  else false

/-- VC generation can mark branch premises as implementation details. They
remain checked local hypotheses and must participate in arithmetic reasoning. -/
private def arithmeticHyps : MetaM (List FVarId) := do
  let mut facts := []
  for declaration in ← getLCtx do
    if arithmeticFact (← instantiateMVars declaration.type) then
      facts := facts ++ [declaration.fvarId]
  return facts

/-- Reduce record projections in arithmetic without unfolding the overloaded
arithmetic operations that omega recognizes. -/
private def arithmeticFields (type : Expr) : MetaM Expr :=
  transform type (post := fun expression => do
    if let .mdata _ inner := expression then return .visit inner
    -- Reduction of generated projections can expose primitive arithmetic
    -- applications. Omega recognizes the overloaded syntax, so restore that
    -- definitionally equal form instead of treating subtraction as an atom.
    let args := expression.getAppArgs
    if args.size == 2 then
      let name := expression.getAppFn.constName?
      let operation := if name == some ``Nat.sub || name == some ``Int.sub then some ``HSub.hSub
        else if name == some ``Nat.add || name == some ``Int.add then some ``HAdd.hAdd
        else if name == some ``Nat.mul || name == some ``Int.mul then some ``HMul.hMul
        else none
      if let some operation := operation then
        return .done (← mkAppM operation args)
    if expression.isProj then
      if let some reduced ← reduceProj? expression then return .visit reduced
      return .done expression
    if expression.isApp then
      if let .const name _ := expression.getAppFn then
        if let some projection ← getProjectionFnInfo? name then
          if !projection.fromClass && expression.getAppNumArgs > projection.numParams then
            let arguments := expression.getAppArgs
            let constructor ← getConstInfoCtor projection.ctorName
            let field := mkProj constructor.induct projection.i arguments[projection.numParams]!
            let reduced := (← reduceProj? field).getD field
            return .visit (mkAppN reduced (arguments.extract (projection.numParams + 1) arguments.size))
    return .done expression)

/-- Try the linear arithmetic fragment before instantiating heap rules. Only
explicit arithmetic hypotheses enter omega; heap predicates remain opaque. -/
elab "air_arithmetic" : tactic => Lean.Elab.Tactic.liftMetaTactic fun goal => goal.withContext do
  let saved ← saveState
  try
    let type ← instantiateMVars (← goal.getType)
    if type.hasMVar then return [goal]
    if let some contradiction ← goal.falseOrByContra then
      let facts ← contradiction.withContext arithmeticHyps
      let mut normalized := contradiction
      for fact in facts do
        normalized ← normalized.withContext do
          normalized.replaceLocalDeclDefEq fact (← arithmeticFields (← instantiateMVars (← fact.getType)))
      Lean.Elab.Tactic.Omega.omega (facts.map Expr.fvar) normalized
    return []
  catch _ =>
    saved.restore
    return [goal]

private partial def matchPremises (proof : Expr) (premises : List Expr)
    (hypotheses : Array FVarId) : MetaM (Array Expr) := do
  match premises with
  | [] =>
    let result ← instantiateMVars proof
    return if result.hasMVar then #[] else #[result]
  | premise :: rest =>
    let type ← instantiateMVars (← inferType premise)
    if !(← isProp type) then return ← matchPremises proof rest hypotheses
    let mut results := #[]
    for hypothesis in hypotheses do
      let actual ← instantiateMVars (← hypothesis.getType)
      if !matchingHead type actual then continue
      let saved ← saveState
      if ← matchingType type actual then
        premise.mvarId!.assign (.fvar hypothesis)
        results := results ++ (← matchPremises proof rest hypotheses)
      saved.restore
    -- Allocation separation commonly follows from a bound rather than an
    -- explicit disequality. Solve only fully instantiated arithmetic premises;
    -- heap predicates stay opaque and every result contains omega's proof.
    if results.isEmpty && arithmeticFact type && !type.hasMVar then
      let saved ← saveState
      try
        if let some contradiction ← premise.mvarId!.falseOrByContra then
          let facts ← contradiction.withContext arithmeticHyps
          let mut normalized := contradiction
          for fact in facts do
            normalized ← normalized.withContext do
              normalized.replaceLocalDeclDefEq fact (← arithmeticFields (← instantiateMVars (← fact.getType)))
          Lean.Elab.Tactic.Omega.omega (facts.map Expr.fvar) normalized
        results := ← matchPremises proof rest hypotheses
      catch error => trace[air.inference] "Arithmetic premise {type} was not discharged: {error.toMessageData}"
      saved.restore
    return results

/-- Bounded forward saturation of a caller-selected rule set. This exposes
known heap reads before scalar normalization, avoiding case splits on values
whose precise constructors already follow from allocation and store facts. -/
def saturateFacts (goal : MVarId) (rules : Array Name) (rounds : Nat) : MetaM (List MVarId) := do
  let mut goal := goal
  let mut known : ExprSet := ← goal.withContext do
    let mut known : ExprSet := {}
    for declaration in ← getLCtx do
      known := known.insert (← instantiateMVars declaration.type)
    return known
  for _ in [:rounds] do
    let mut changed := false
    for rule in rules do
      let results ← goal.withContext do
        let saved ← saveState
        let ruleProof ← mkConstWithFreshMVarLevels rule
        -- Keep a predicate-valued conclusion intact. Unfolding `Represents`
        -- here would turn its quantified reads into extra input premises.
        let (arguments, _, _) ← forallMetaTelescope (← inferType ruleProof)
        let ordered := arguments.toList.reverse
        let sideConditions ← ordered.filterM fun argument => return arithmeticFact (← inferType argument)
        let premises ← ordered.filterM fun argument => return !arithmeticFact (← inferType argument)
        let results ← matchPremises (mkAppN ruleProof arguments) (premises ++ sideConditions) (← getLCtx).getFVarIds
        trace[air.inference] "{rule}: {results.size} matching applications"
        saved.restore
        return results
      for result in results do
        let type ← goal.withContext (instantiateMVars (← inferType result))
        if known.contains type then continue
        goal := (← goal.note `airHeap result).2
        known := known.insert type
        changed := true
    if !changed then break
  return [goal]

/-- Eliminate an explicit contradiction without unfolding unrelated predicates
or inspecting every constructor of an interpreter state. -/
elab "air_false" : tactic => Lean.Elab.Tactic.liftMetaTactic fun goal => goal.withContext do
  for declaration in ← getLCtx do
    if declaration.type.isConstOf ``False then
      goal.assign (← mkAppOptM ``False.elim #[some (← goal.getType), some (.fvar declaration.fvarId)])
      return []
  return [goal]

private partial def splitWitnesses (goal : MVarId) : MetaM (List MVarId) := goal.withContext do
  let target ← instantiateMVars (← goal.getType)
  let constructor := if target.isAppOf ``Exists then some ``Exists.intro
    else if target.isAppOf ``And then some ``And.intro else none
  match constructor with
  | none => return [goal]
  | some constructor =>
    let goals ← goal.applyConst constructor { newGoals := .nonDependentOnly }
    return (← goals.mapM splitWitnesses).flatten

/-- Infer existential counter/slot witnesses from a known read equation.
The remaining bounds and invariant clauses are separate proof obligations.
Unassigned witnesses still fail elaboration; this is ordinary unification. -/
elab "air_witnesses" : tactic => Lean.Elab.Tactic.liftMetaTactic fun goal => do
  let mut goals ← splitWitnesses goal
  -- Contextual simplification can already have reduced a read equality to
  -- equality of its scalar payloads. Reflexivity then determines the witness
  -- directly, without searching for a load that is no longer in the goal.
  goals ← goals.filterM fun goal => goal.withContext do
    let target ← instantiateMVars (← goal.getType)
    if !target.isAppOf ``Eq || !target.hasMVar then return true
    let type := target.getAppArgs[0]!
    if !type.isConstOf ``Int && !type.isConstOf ``Nat then return true
    let saved ← saveState
    try
      goal.refl
      return false
    catch _ =>
      saved.restore
      return true
  -- First bind storage identities from environment equations. With several
  -- counters, choosing an arbitrary matching load first could select the
  -- wrong slot and leave an otherwise provable invariant unresolved.
  for loads in [false, true] do
    goals ← goals.filterM fun goal => goal.withContext do
      let target ← instantiateMVars (← goal.getType)
      if !target.isAppOf ``Eq || target.getAppArgs[1]!.isAppOf ``Memory.load != loads then return true
      if !loads && !target.hasMVar then return true
      for declaration in ← getLCtx do
        let actual := declaration.type
        if !actual.isAppOf ``Eq || !matchingHead target actual then continue
        let saved ← saveState
        if ← isDefEq target actual then
          goal.assign (.fvar declaration.fvarId)
          return false
        saved.restore
      return true
  -- Spatial invariants may existentially hide their current contents. Infer
  -- such witnesses from an existing predicate fact, without unfolding reads
  -- or manufacturing an initialization assumption.
  goals ← goals.filterM fun goal => goal.withContext do
    let target ← instantiateMVars (← goal.getType)
    if !target.hasMVar || target.isAppOf ``Eq then return true
    for declaration in ← getLCtx do
      let actual ← instantiateMVars declaration.type
      if !matchingHead target actual then continue
      let saved ← saveState
      if ← matchingType target actual then
        goal.assign (.fvar declaration.fvarId)
        return false
      saved.restore
    return true
  return goals

end Compiler.ZigAir.MemoryAir.Verify
