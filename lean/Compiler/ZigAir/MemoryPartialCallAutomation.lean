/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryPartialCallWP
import Compiler.ZigAir.MemoryAutomation

namespace Compiler.ZigAir.MemoryPartialCall
open MemoryAir.Verify

theorem semantics_hasType (budget : Nat) (value : Memory.Value) (type : Memory.Ty) :
    (semantics budget).hasType value type = value.hasType type := rfl
theorem semantics_truth (budget : Nat) (value : Memory.Value) :
    (semantics budget).truth value = MemoryAir.semantics.truth value := rfl
theorem semantics_reference (budget : Nat) (reference : MemoryAir.Ref) (env : MemoryAir.Env) :
    (semantics budget).evalRef reference env = (reference.eval env).mapError Signal.fault := rfl
theorem semantics_malformed (budget : Nat) : (semantics budget).malformed = .fault .malformed := rfl

/-- Generate obligations for arbitrary admitted code. Callee contracts describe
only completed observations; a pending call cannot advance its continuation. -/
macro "nested_call_vcgen" "[" specs:Lean.Parser.Tactic.simpArg,* "]"
    "unfolding" "[" definitions:Lean.Parser.Tactic.simpArg,* "]" : tactic => do
  let specs : Lean.Syntax.TSepArray
      [`Lean.Parser.Tactic.simpStar, `Lean.Parser.Tactic.simpErase, `Lean.Parser.Tactic.simpLemma] "," :=
    ⟨specs.elemsAndSeps⟩
  let definitions : Lean.Syntax.TSepArray
      [`Lean.Parser.Tactic.simpStar, `Lean.Parser.Tactic.simpErase, `Lean.Parser.Tactic.simpLemma] "," :=
    ⟨definitions.elemsAndSeps⟩
  `(tactic| (
  try dsimp only [BodyContract]
  set_option experimental.vcgen true in vcgen [$specs,*]
  all_goals try simp only [$definitions,*] at *
  all_goals air_split
  all_goals try simp only [semantics_hasType, semantics_truth, semantics_reference, semantics_malformed,
    errorsWithPending, Except.mapError, env_set_apply, MemoryAir.Ref.eval_local, MemoryAir.Ref.eval_constant,
    pointer_typed, bool_typed, unit_typed, pointer_valid, bool_valid, unit_valid] at *
  all_goals air_subst
  all_goals air_prune
  air_normalize
  air_reduce
  air_reduce))

end Compiler.ZigAir.MemoryPartialCall
