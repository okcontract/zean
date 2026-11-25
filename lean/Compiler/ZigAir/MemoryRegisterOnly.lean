/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MachineCoverage
import Compiler.ZigAir.MemoryAirLaws
import Compiler.ZigAir.MemoryCallMachineEmbedding
import Compiler.ZigAir.MemoryStackLaws

namespace Compiler.ZigAir.MemoryAir
open Memory

/-- Register operations inspect only arguments or the environment. The
remaining primitives require their own memory reasoning. -/
def Prim.registerOnly : Prim → Bool
  | .argument .. | .scalar .. | .booleanNot .. | .testOptional .. | .optionalPayload ..
  | .wrapOptional .. | .testError .. | .unwrapError .. | .wrapError .. | .unreachable => true
  | _ => false

def Code.registerOnly (code : Code) : Bool :=
  code.bindings.all (fun site => site.2.2.registerOnly)

private theorem Prim.eval_registerOnly (prim : Prim) (checked : prim.registerOnly = true)
    (args : List Value) (env : Env) (before reference : State) :
    prim.eval args env before = ((prim.eval args env reference).1, before) := by
  cases prim <;> simp only [Prim.registerOnly] at checked <;> try contradiction
  case argument index => simp only [Prim.eval_argument]
  case scalar operation => simp only [Prim.eval_scalar]
  case unreachable => rfl
  all_goals simp only [Prim.eval, Prim.transition, bind, Except.bind]
  case booleanNot ref =>
    cases ref.eval env with
    | error => rfl
    | ok value => dsimp only; cases MemoryAir.booleanNot value <;> rfl
  case testError flag ref =>
    cases ref.eval env with
    | error => rfl
    | ok value => dsimp only; cases Memory.testError flag value <;> rfl
  case unwrapError flag ref =>
    cases ref.eval env with
    | error => rfl
    | ok value => dsimp only; cases Memory.unwrapError flag value <;> rfl
  case wrapError allowed ref =>
    cases ref.eval env with
    | error => rfl
    | ok value => dsimp only; cases Memory.wrapError allowed value <;> rfl
  all_goals
    rename_i ref
    cases ref.eval env with
    | error => rfl
    | ok resolved =>
      cases resolved <;> try rfl
      all_goals
        rename_i payload
        cases payload <;> rfl

private def restate (state : State) : Control.Outcome Value Fault State → Control.Outcome Value Fault State
  | .returned value _ => .returned value state
  | .fault fault _ => .fault fault state
  | .jumped label value env _ => .jumped label value env state

private theorem eval_restate (code : Code) (checked : code.registerOnly = true)
    (args : List Value) (env : Env) (before reference : State) :
    code.eval semantics args env before = restate before (code.eval semantics args env reference) := by
  induction code generalizing env before reference with
  | bind id ty prim next ih =>
    have properties : prim.registerOnly = true ∧ Code.registerOnly next = true := by
      simpa only [Code.registerOnly, Control.Code.bindings, List.all_cons, Bool.and_eq_true] using checked
    have evaluated := prim.eval_registerOnly properties.1 args env before reference
    simp only [Code.eval_bind, evaluated]
    cases (prim.eval args env reference) with
    | mk result after =>
      cases result with
      | error => rfl
      | ok value =>
        by_cases typed : value.hasType ty = true
        · simpa only [typed, ↓reduceIte] using ih properties.2 (env.set id value) before after
        · simp [typed, restate]
  | branch condition yes no ihYes ihNo =>
    have properties : Code.registerOnly yes = true ∧ Code.registerOnly no = true := by
      simpa only [Code.registerOnly, Control.Code.bindings, List.all_append, Bool.and_eq_true] using checked
    simp only [Code.eval_branch]
    generalize condition.eval env = evaluated
    cases evaluated with
    | error => rfl
    | ok value =>
      cases value <;> try rfl
      rename_i scalar
      cases scalar <;> try rfl
      rename_i flag
      cases flag
      · exact ihNo properties.2 _ before reference
      · exact ihYes properties.1 _ before reference
  | block id ty body next ihBody ihNext =>
    have properties : Code.registerOnly body = true ∧ Code.registerOnly next = true := by
      simpa only [Code.registerOnly, Control.Code.bindings, List.all_append, Bool.and_eq_true] using checked
    rw [Control.Code.eval, Control.Code.eval, ihBody properties.1 env before reference]
    cases body.eval semantics args env reference with
    | returned | fault => rfl
    | jumped label value afterEnv after =>
      simp only [restate]
      split
      · split
        · exact ihNext properties.2 _ before after
        · rfl
      · rfl
  | jump | ret => simp only [Control.Code.eval]; split <;> rfl
  | loop | «repeat» => contradiction

/-- A finite register-only program returns the same result on any valid heap
and returns that heap intact, including when the modeled result is a fault. -/
theorem Program.run_registerOnly (program : Program) (checked : Code.registerOnly program.body = true)
    (args : List Value) (before reference : State)
    (valid : before.valid = true) (referenceValid : reference.valid = true) :
    program.run args before = ((program.run args reference).1, before) := by
  have accepts : program.accepts args before = program.accepts args reference := by
    simp only [Program.accepts, valid, referenceValid]
  simp only [Program.run, accepts]
  split
  · rw [eval_restate _ checked args _ before reference]
    cases program.body.eval semantics args (fun _ => none) reference <;>
      simp only [restate, Program.finish, cleanup_initial before valid]
  · rfl

end Compiler.ZigAir.MemoryAir

namespace Compiler.ZigAir.MemoryCallMachine
open Memory

/-- Recover finite memory code from the captured function. Every binding
is preserved. A direct call, loop, or back edge fails the projection. -/
def projectFiniteMemory : Code → Option MemoryAir.Code
  | .bind id type (.memory operation) next => (projectFiniteMemory next).map (.bind id type operation)
  | .branch cond yes no => do return .branch cond (← projectFiniteMemory yes) (← projectFiniteMemory no)
  | .block id type body next => do return .block id type (← projectFiniteMemory body) (← projectFiniteMemory next)
  | .jump id ref => some (.jump id ref)
  | .ret ref => some (.ret ref)
  | .bind _ _ (.call ..) _ | .loop .. | .repeat .. => none

theorem projectFiniteMemory_sound (code : Code) (projected : MemoryAir.Code)
    (found : projectFiniteMemory code = some projected) :
    embedCode projected.enableLoops = code := by
  induction code generalizing projected with
  | bind id ty prim next ih =>
    cases prim with
    | call => contradiction
    | memory operation =>
      cases rest : projectFiniteMemory next with
      | none => simp [projectFiniteMemory, rest] at found
      | some body =>
        simp [projectFiniteMemory, rest] at found
        subst projected
        simp only [Control.Code.enableLoops, embedCode, ih _ rest]
  | branch condition yes no ihYes ihNo =>
    cases left : projectFiniteMemory yes <;> cases right : projectFiniteMemory no <;>
      simp [projectFiniteMemory, left, right] at found
    subst projected
    simp only [Control.Code.enableLoops, embedCode, ihYes _ left, ihNo _ right]
  | block id ty body next ihBody ihNext =>
    cases first : projectFiniteMemory body <;> cases rest : projectFiniteMemory next <;>
      simp [projectFiniteMemory, first, rest] at found
    subst projected
    simp only [Control.Code.enableLoops, embedCode, ihBody _ first, ihNext _ rest]
  | jump | ret => cases found; rfl
  | loop | «repeat» => contradiction

/-- Execute the actual call-machine entry using its finite memory code. -/
theorem steps_finite_memory (program : Program) (root : Nat) (function : Function)
    (body : MemoryAir.Code) (atRoot : program[root]? = some function)
    (projected : projectFiniteMemory function.body = some body)
    (args : List Value) (state : State) :
    let finite : MemoryAir.Program := ⟨function.parameters, function.returnType, body⟩
    Steps program (start program root args state)
      (.finished (finite.run args state).1 (finite.run args state).2) := by
  intro finite
  have checked : program[root]? = some (Function.ofMemory finite.enableLoops) := by
    rw [atRoot]
    cases function
    simp only [Function.ofMemory, MemoryAir.Program.enableLoops, finite, Option.some.injEq]
    exact congrArg _ (projectFiniteMemory_sound _ _ projected).symm
  obtain ⟨fuel, done⟩ := MemoryAir.Program.runFuel_finite finite args state
  apply (steps_iff_fuel _ _ _).mpr
  refine ⟨fuel, ?_⟩
  change run program fuel root args state = _
  rw [ofMemory_run_at _ _ _ checked, done]
  rfl

end Compiler.ZigAir.MemoryCallMachine
