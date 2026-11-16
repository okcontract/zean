/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryPrimitiveWP
import Compiler.ZigAir.ScalarPrimitiveWP
import Compiler.ZigAir.MemoryAirLaws
import Compiler.ZigAir.MemoryByteAirLaws
import Compiler.ZigAir.MemoryReadTyping
import Compiler.ZigAir.MemoryStackLaws
import Compiler.ZigAir.MemoryVerificationFacts
import Compiler.ZigAir.MemoryFrameVerification
import Lean.Elab.Tactic

/-! Generic instruction normalization and proof-producing VC generation.
No function identities, SSA register numbers or control-tree shapes are selected
here. Client definitions can be unfolded before `air_vcgen`; remaining goals are
ordinary Lean obligations, not successful verification results. -/
/-- Optional domains register their normalization facts without changing the core tactic. -/
register_simp_attr air_simps

namespace Compiler.ZigAir.MemoryAir.Verify
open Memory

/-- VC generation can mark branch premises as implementation details. Expose
those propositions to ordinary simplification and case analysis. This changes
only tactic visibility: their types and proof terms remain unchanged. -/
elab "air_conditions" : tactic => Lean.Elab.Tactic.liftMetaTactic fun goal => do
  let conditions ← goal.withContext do
    let mut conditions := #[]
    for declaration in ← Lean.getLCtx do
      if declaration.kind == .implDetail && (← Lean.Meta.isProp declaration.type) then
        conditions := conditions.push declaration.fvarId
    return conditions
  for condition in conditions do goal.setFVarKind condition .default
  return [goal]

/-- Eliminate conjunctions using Lean's ordinary proof-producing case tactic.
This exposes equalities for substitution without choosing an operation outcome. -/
private partial def splitConjunctions (goal : Lean.MVarId) : Lean.MetaM (List Lean.MVarId) := goal.withContext do
  for declaration in ← Lean.getLCtx do
    if declaration.isImplementationDetail then continue
    if declaration.type.isAppOf ``And || declaration.type.isAppOf ``Exists then
      let alternatives ← goal.cases declaration.fvarId
      let mut goals := []
      for alternative in alternatives do
        goals := goals ++ (← splitConjunctions alternative.mvarId)
      return goals
  return [goal]

elab "air_split" : tactic => Lean.Elab.Tactic.liftMetaTactic splitConjunctions

private partial def substituteValues (goal : Lean.MVarId) : Lean.MetaM (List Lean.MVarId) := goal.withContext do
  for declaration in ← Lean.getLCtx do
    if !declaration.type.isAppOf ``Eq then continue
    let args := declaration.type.getAppArgs
    if !args[1]!.isFVar && !args[2]!.isFVar then continue
    if let some next ← Lean.Meta.subst? goal declaration.fvarId then return ← substituteValues next
  return [goal]

/-- Substitute explicit SSA equalities without unfolding arbitrary heap
predicates while searching for equalities. -/
elab "air_subst" : tactic => Lean.Elab.Tactic.liftMetaTactic substituteValues

/-- Discard discharged bookkeeping facts before building the next contextual
rewrite set. Clearing checks dependencies and never removes an obligation. -/
elab "air_prune" : tactic => Lean.Elab.Tactic.liftMetaTactic fun goal => do
  let facts ← goal.withContext do
    (← Lean.getLCtx).getFVarIds.filterM fun id => do
      return (← id.getType).isConstOf ``True
  return [← goal.tryClearMany facts]

/-- Instantiate one-premise facts from the current context. Every derived fact
is an application of a checked theorem; no evaluation oracle is used. -/
def forwardFacts (goal : Lean.MVarId) (rules : Array Lean.Name) : Lean.MetaM (List Lean.MVarId) := do
  let mut goal := goal
  for rule in rules do
    let hypotheses ← goal.withContext do pure (← Lean.getLCtx).getFVarIds
    for hypothesis in hypotheses do
      goal ← goal.withContext do
        let proof ← Lean.Meta.mkConstWithFreshMVarLevels rule
        let (arguments, _, conclusion) ← Lean.Meta.forallMetaTelescope (← Lean.Meta.inferType proof)
        if arguments.isEmpty then return goal
        let last := arguments.back!
        let premise ← Lean.Meta.inferType last
        let actual ← hypothesis.getType
        -- Avoid unfolding unrelated heap definitions during unification.
        if premise.isAppOf ``Eq && actual.isAppOf ``Eq then
          if premise.getAppArgs[1]!.getAppFn != actual.getAppArgs[1]!.getAppFn then return goal
        else return goal
        let matched ← Lean.Meta.isDefEq premise actual
        if !matched then return goal
        last.mvarId!.assign (.fvar hypothesis)
        let result ← Lean.instantiateMVars (Lean.mkAppN proof arguments)
        if result.hasMVar then return goal
        let conclusion ← Lean.instantiateMVars conclusion
        for declaration in ← Lean.getLCtx do
          if declaration.type == conclusion then return goal
        return (← goal.note `airFact result).2
  return [goal]

@[simp] theorem pointer_valid (write many : Bool) (child : Ty) (address : Address) :
    (Value.pointer (.pointer write many child) address).valid = true := rfl

@[simp] theorem pointer_typed (write many : Bool) (child : Ty) (address : Address) :
    (Value.pointer (.pointer write many child) address).hasType (.pointer write many child) = true := by
  simp [Value.hasType, Value.type]

@[simp] theorem bool_valid (flag : Bool) : (Value.scalar (.bool flag)).valid = true := rfl
@[simp] theorem bool_typed (flag : Bool) : (Value.scalar (.bool flag)).hasType (.scalar .bool) = true := rfl
@[simp] theorem unit_valid : (Value.scalar .unit).valid = true := rfl
@[simp] theorem unit_typed : (Value.scalar .unit).hasType (.scalar .unit) = true := rfl

@[simp] theorem scalar_valid (value : Scalar.Value) : (Value.scalar value).valid = value.valid := rfl
@[simp] theorem scalar_bool_valid (flag : Bool) : (Scalar.Value.bool flag).valid = true := rfl
@[simp] theorem scalar_unit_valid : Scalar.Value.unit.valid = true := rfl

theorem unsigned_valid (width n : Nat) (bound : n < 2 ^ width) :
    (Scalar.Value.int false width n).valid = true := by
  simp [Scalar.Value.valid, Scalar.Ty.contains, Scalar.Ty.lower, Scalar.Ty.upper]
  exact_mod_cast bound

@[simp] theorem unsigned_zero_valid (width : Nat) : (Scalar.Value.int false width 0).valid = true :=
  unsigned_valid width 0 (Nat.two_pow_pos width)

@[simp] theorem unsigned_one_valid (width : Nat) (positive : 0 < width) :
    (Scalar.Value.int false width 1).valid = true :=
  unsigned_valid width 1 (Nat.one_lt_two_pow (by omega))

theorem unsigned_typed (width n : Nat) (bound : n < 2 ^ width) :
    (Value.scalar (.int false width n)).hasType (.scalar (.int false width)) = true := by
  simpa [Value.hasType, Value.type, Scalar.Value.type] using unsigned_valid width n bound

theorem unsigned_typed_int (width : Nat) (value : Int) (lower : 0 ≤ value) (upper : value < 2 ^ width) :
    (Value.scalar (.int false width value)).hasType (.scalar (.int false width)) = true := by
  simp [Value.hasType, Value.type, Value.valid, Scalar.Value.type, Scalar.Value.valid,
    Scalar.Ty.contains, Scalar.Ty.lower, Scalar.Ty.upper, lower, upper]

@[simp] theorem unsigned_zero_typed (width : Nat) :
    (Value.scalar (.int false width 0)).hasType (.scalar (.int false width)) = true :=
  unsigned_typed width 0 (Nat.two_pow_pos width)

@[simp] theorem unsigned_one_typed (width : Nat) (positive : 0 < width) :
    (Value.scalar (.int false width 1)).hasType (.scalar (.int false width)) = true :=
  unsigned_typed width 1 (Nat.one_lt_two_pow (by omega))

theorem usize_typed (n : Nat) (bound : n < addressLimit) :
    (Value.scalar (.int false 64 n)).hasType (.scalar (.int false 64)) = true := unsigned_typed 64 n bound

theorem usize_typed_int (value : Int) (lower : 0 ≤ value) (upper : value < (addressLimit : Int)) :
    (Value.scalar (.int false 64 value)).hasType (.scalar (.int false 64)) = true :=
  unsigned_typed_int 64 value lower upper

/-- Supply a natural-number witness for an integer-valued loop increment.
VC arithmetic uses `Int`; client loop invariants commonly quantify over `Nat`. -/
theorem usize_successor (index limit : Nat) (inside : index < limit) (width : limit < addressLimit) :
    ∃ next : Nat, next ≤ limit ∧ (index : Int) + 1 = (next : Int) ∧
      (Value.scalar (.int false 64 next)).hasType (.scalar (.int false 64)) = true :=
  ⟨index + 1, by omega, by omega, usize_typed _ (by omega)⟩

grind_pattern usize_successor => (Scalar.Ty.int false 64).contains ((index : Int) + 1), index < limit

theorem normalize_unsigned (width : Nat) (value : Int) (lower : 0 ≤ value) (upper : value < 2 ^ width) :
    Scalar.normalize false width value = value := by
  simp only [Scalar.normalize, Bool.false_and, Bool.false_eq_true, ↓reduceIte]
  exact Int.emod_eq_of_lt lower upper

theorem normalize_unsigned_valid (width : Nat) (value : Int)
    (valid : (Scalar.Value.int false width value).valid = true) :
    Scalar.normalize false width value = value := by
  have bounds : 0 ≤ value ∧ value < 2 ^ width := of_decide_eq_true valid
  exact normalize_unsigned width value bounds.1 bounds.2

theorem integer_contains (signed : Bool) (width : Nat) (value : Int)
    (valid : (Scalar.Value.int signed width value).valid = true) :
    (Scalar.Ty.int signed width).contains value = true := valid

/-- Checks that discard their successful payload still determine the returned
value. No assumption about whether the check succeeds is introduced. -/
theorem checked_value_result {Error Input Result : Type} (first : Except Error Input)
    (value result : Result)
    (success : (match first with | .error fault => Except.error fault | .ok _ => Except.ok value) =
      Except.ok result) : result = value := by
  cases first <;> simp_all

elab "air_forward" : tactic => Lean.Elab.Tactic.liftMetaTactic fun goal =>
  forwardFacts goal #[``allocation_record, ``store_record, ``value_valid_of_hasType, ``allocate_pointer, ``allocate_preserves_valid,
    ``load_after_store, ``readonly_after_store, ``load_record, ``store_keeps_counters, ``pointerCast_readonly_of_load,
    ``normalize_unsigned_valid, ``integer_contains, ``checked_value_result]

theorem Prim.eval_allocate (child : Ty) (args : List Value) (env : Env) (state : State) :
    (Prim.alloc child).eval args env state = match allocate state child with
      | .ok (value, after) => (.ok value, after)
      | .error fault => (.error fault, state) := rfl

theorem semantics_hasType (value : Value) (type : Ty) :
    semantics.hasType value type = value.hasType type := rfl
theorem semantics_truth (value : Value) :
    semantics.truth value = (match value with | .scalar (.bool flag) => some flag | _ => none) := rfl
theorem semantics_reference (reference : Ref) (env : Env) :
    semantics.evalRef reference env = reference.eval env := rfl
theorem semantics_primitive (primitive : Prim) (args : List Value) (env : Env) (state : State) :
    semantics.evalPrim primitive args env state = primitive.eval args env state := rfl
theorem semantics_malformed : semantics.malformed = Fault.malformed := rfl

theorem env_set_apply (env : Env) (id query : Nat) (value : Value) :
    env.set id value query = (if query = id then some value else env query) := rfl
theorem scalarEnv_apply (env : Env) (id : Nat) :
    scalarEnv env id = (match env id with | some (.scalar value) => some value | _ => none) := rfl

/-- A successful checked operation retains both its guard and its exact result.
Expose these before choosing loop witnesses or querying arithmetic solvers. -/
theorem checked_success {Error Result : Type} (condition : Prop) [Decidable condition]
    (value result : Result) (fault : Error) :
    (if condition then Except.ok value else Except.error fault) = .ok result ↔
      condition ∧ value = result := by
  by_cases condition <;> simp_all

theorem checked_success_else {Error Result : Type} (condition : Prop) [Decidable condition]
    (value result : Result) (fault : Error) :
    (if condition then Except.error fault else Except.ok value) = .ok result ↔
      ¬condition ∧ value = result := by
  by_cases condition <;> simp_all

/-- Retain the evidence from each successful stage of a checked expression.
In particular, a bound check followed by slice construction must expose both
the bound and the resulting slice before spatial inference begins. -/
theorem checked_bind_success {Error Input Result : Type} (first : Except Error Input)
    (next : Input → Except Error Result) (result : Result) :
    (match first with | .error fault => Except.error fault | .ok value => next value) = Except.ok result ↔
      ∃ value, first = .ok value ∧ next value = .ok result := by
  cases first <;> simp

theorem guarded_success {Error Result : Type} (condition : Prop) [Decidable condition]
    (operation : Except Error Result) (result : Result) (fault : Error) :
    (if condition then operation else Except.error fault) = .ok result ↔
      condition ∧ operation = .ok result := by
  by_cases condition <;> simp_all

theorem guarded_success_else {Error Result : Type} (condition : Prop) [Decidable condition]
    (operation : Except Error Result) (result : Result) (fault : Error) :
    (if condition then Except.error fault else operation) = .ok result ↔
      ¬condition ∧ operation = .ok result := by
  by_cases condition <;> simp_all

/-- Refresh the contextual rewrite rules after each changed hypothesis. In
particular, two equivalent operation equations must not erase each other. -/
private def contextualSimp (goal : Lean.MVarId) (base : Lean.Meta.Simp.Context)
    (simprocs : Lean.Meta.Simp.SimprocsArray) (select : Lean.Expr → Bool := fun _ => true) : Lean.MetaM (List Lean.MVarId) := do
  let context (goal : Lean.MVarId) := goal.withContext do
    let mut theorems := base.simpTheorems
    for hypothesis in ← Lean.Meta.getPropHyps do
      let type ← hypothesis.getType
      if !select type then continue
      -- Definitional address and value identities are not rewrite rules.
      -- Forward rules can express the same pointer through `View.pointer`
      -- and its constructor in opposite directions, creating a rewrite cycle.
      if type.isAppOf ``Eq &&
          (type.getAppArgs[0]!.isConstOf ``Memory.Address || type.getAppArgs[0]!.isConstOf ``Memory.Value) then
        if ← Lean.Meta.isDefEq type.getAppArgs[1]! type.getAppArgs[2]! then continue
      theorems ← theorems.addTheorem (.fvar hypothesis) (.fvar hypothesis) (config := base.indexConfig)
    return base.setSimpTheorems theorems
  -- Forward inference can retain proofs of an earlier equation. Simplify it
  -- anyway: simpLocalDecl preserves a depended-on original and asserts a
  -- proved simplified copy, instead of discarding its operational evidence.
  let hypotheses ← goal.withContext Lean.Meta.getPropHyps
  let mut current := goal
  let mut indexed ← context goal
  for hypothesis in hypotheses do
    let ctx := indexed.setSimpTheorems (indexed.simpTheorems.eraseTheorem (.fvar hypothesis))
    match (← Lean.Meta.simpLocalDecl current hypothesis ctx simprocs).1 with
    | none => return []
    | some (updated, next) =>
      current := next
      if updated != hypothesis then indexed ← context current
  match (← Lean.Meta.simpTarget current indexed simprocs).1 with
  | none => return []
  | some next => return [next]

elab "air_simp" : tactic => do
  let simpSyntax ← `(tactic| simp [scalar_valid, naturalValue, castValue, compareValues, arithmeticValues, extremumValues, booleanNot,
    Scalar.integer, Scalar.Arithmetic.eval, Scalar.Comparison.eval, Bound.eval, checkSliceBounds,
    scalarEnv_apply, Ref.eval_local, Ref.eval_constant, env_set_apply, bind, Except.bind, pure, Except.pure,
    checked_success, checked_success_else, checked_bind_success,
    guarded_success, guarded_success_else, air_simps])
  let context ← Lean.Elab.Tactic.mkSimpContext simpSyntax false
  Lean.Elab.Tactic.liftMetaTactic fun goal => contextualSimp goal context.ctx context.simprocs

/-- Canonicalize allocation identities before choosing existential witnesses.
Only natural-number equalities are used, leaving heap operations opaque. -/
elab "air_nat_equalities" : tactic => do
  let simpSyntax ← `(tactic| simp only [Nat.add_assoc, Nat.add_zero, Nat.zero_add])
  let context ← Lean.Elab.Tactic.mkSimpContext simpSyntax false
  Lean.Elab.Tactic.liftMetaTactic fun goal => contextualSimp goal context.ctx context.simprocs fun type =>
    type.isAppOf ``Eq && type.getAppArgs[0]!.isConstOf ``Nat

/-- Normalize primitive evaluation without unfolding the heap implementation.
Successful stores, reads and allocation remain explicit obligations. -/
macro "air_normalize" : tactic => `(tactic| (
  all_goals air_conditions
  all_goals try simp only [Program.accepts, semantics_hasType, semantics_truth, semantics_reference,
    semantics_primitive, semantics_malformed, Prim.eval_argument, Prim.eval_allocate, Prim.eval_load, Prim.eval_store,
    Prim.eval_cast, Prim.eval_element, Prim.eval_offset, Prim.eval_slice_element, Prim.eval_slice,
    Prim.eval_bounds, Prim.eval_scalar, Prim.eval_word_byte_cast,
    Ref.eval_local, Ref.eval_constant, Ref.natural_eq, env_set_apply, scalarEnv_apply,
    Scalar.Ref.eval, Scalar.Prim.eval, Scalar.integer, Scalar.Arithmetic.eval, Scalar.Comparison.eval,
    bind, Except.bind] at *
  all_goals try simp [pointer_valid, bool_valid, unit_valid,
    Lean.Order.CompleteLattice.ofProp_apply, Lean.Order.ofProp_prop_eq] at *
  all_goals air_split
  all_goals air_forward
  all_goals air_split
  all_goals try simp [Program.accepts, Ref.eval_local, Ref.eval_constant, env_set_apply,
    air_simps,
    pointer_typed, bool_typed, unit_typed] at *))

macro "air_reduce" : tactic => `(tactic| (
  all_goals air_conditions
  all_goals air_simp
  all_goals air_subst
  all_goals air_forward
  all_goals air_split
  all_goals air_simp
  all_goals air_subst
  all_goals air_prune))

/-- Generate VCs from admitted program data; optionally expose client invariant
definitions before normalizing the generated conditions. -/
macro "air_vcgen_prepare" "[" definitions:Lean.Parser.Tactic.simpArg,* "]" : tactic => do
  let definitions : Lean.Syntax.TSepArray
      [`Lean.Parser.Tactic.simpStar, `Lean.Parser.Tactic.simpErase, `Lean.Parser.Tactic.simpLemma] "," :=
    ⟨definitions.elemsAndSeps⟩
  `(tactic| (
  try simp only [Program.enableLoops, Control.Code.enableLoops]
  set_option experimental.vcgen true in vcgen
  all_goals try simp only [$definitions,*] at *
  all_goals air_split
  air_normalize))

macro "air_vcgen" "[" definitions:Lean.Parser.Tactic.simpArg,* "]" : tactic => do
  let definitions : Lean.Syntax.TSepArray
      [`Lean.Parser.Tactic.simpStar, `Lean.Parser.Tactic.simpErase, `Lean.Parser.Tactic.simpLemma] "," :=
    ⟨definitions.elemsAndSeps⟩
  `(tactic| (
  air_vcgen_prepare [$definitions,*]
  air_reduce
  air_reduce
  all_goals try solve | simp_all))

macro "air_vcgen" : tactic => `(tactic| air_vcgen [])

/-- Optional Lean 4.35 shared-context discharge. Difficult memory conditions
still pass through the same checked normalization as `air_vcgen`. Keep this
opt-in until measurements justify changing the default. -/
macro "air_vcgen_shared" "[" definitions:Lean.Parser.Tactic.simpArg,* "]" : tactic => do
  let definitions : Lean.Syntax.TSepArray
      [`Lean.Parser.Tactic.simpStar, `Lean.Parser.Tactic.simpErase, `Lean.Parser.Tactic.simpLemma] "," :=
    ⟨definitions.elemsAndSeps⟩
  `(tactic| (
  try simp only [Program.enableLoops, Control.Code.enableLoops]
  set_option experimental.vcgen true in vcgen with try finish
  all_goals try simp only [$definitions,*] at *
  all_goals air_split
  air_normalize
  air_reduce
  air_reduce
  all_goals try solve | simp_all))

macro "air_vcgen_shared" : tactic => `(tactic| air_vcgen_shared [])

/-- Discharge routine typing and heap-validity goals. Unresolved bounds,
permissions, initialization or user contracts remain visible to the caller. -/
macro "air_finish" config:Lean.Parser.Tactic.optConfig "[" facts:Lean.Parser.Tactic.grindParam,* "]" : tactic => `(tactic| (
  all_goals air_forward
  all_goals air_subst
  all_goals try simp only [checked_bind_success, checked_success, checked_success_else,
    unit_typed] at *
  all_goals air_split
  all_goals air_subst
  all_goals grind $config:optConfig [→ AllocationStep.equation, → StoreStep.equation, → LoadStep.equation,
    value_valid_of_hasType, Value.boolean_value, pointer_valid, pointer_typed, bool_valid, bool_typed,
    unit_valid, unit_typed, unsigned_typed_int, usize_typed, usize_typed_int,
    → allocate_preserves_valid, → store_preserves_valid, cleanup_preserves_valid, cleanup_initial,
    load_alias_after_store,
    allocate_pointer_fault, fresh_pointer_store_no_fault,
    → StackFrame.allocate, $facts,*]))

macro "air_finish" : tactic => `(tactic| air_finish (verbose := false) [])

end Compiler.ZigAir.MemoryAir.Verify
