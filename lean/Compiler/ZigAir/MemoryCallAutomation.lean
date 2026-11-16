/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryCallVerification
import Compiler.ZigAir.MemoryAutomation

namespace Compiler.ZigAir.MemoryCall
open MemoryAir.Verify

theorem semantics_hasType (value : Memory.Value) (type : Memory.Ty) :
    semantics.hasType value type = value.hasType type := rfl
theorem semantics_truth (value : Memory.Value) :
    semantics.truth value = MemoryAir.semantics.truth value := rfl
theorem semantics_reference (reference : MemoryAir.Ref) (env : MemoryAir.Env) :
    semantics.evalRef reference env = reference.eval env := rfl
theorem semantics_malformed : semantics.malformed = Memory.Fault.malformed := rfl

/-- Use the shared instruction rules with direct-call contracts registered as
`[spec]` theorems. Callee implementations are not unfolded here. -/
macro "call_normalize" "[" definitions:Lean.Parser.Tactic.simpArg,* "]" : tactic => do
  let definitions : Lean.Syntax.TSepArray
      [`Lean.Parser.Tactic.simpStar, `Lean.Parser.Tactic.simpErase, `Lean.Parser.Tactic.simpLemma] "," :=
    ⟨definitions.elemsAndSeps⟩
  `(tactic| (
  all_goals try simp only [$definitions,*] at *
  all_goals air_split
  all_goals try simp only [semantics_hasType, semantics_truth, semantics_reference, semantics_malformed,
    env_set_apply, MemoryAir.Ref.eval_local, MemoryAir.Ref.eval_constant,
    pointer_typed, bool_typed, unit_typed, pointer_valid, bool_valid, unit_valid] at *
  all_goals air_subst
  all_goals air_prune
  air_normalize
  air_reduce
  air_reduce))

macro "call_vcgen" "[" specs:Lean.Parser.Tactic.simpArg,* "]"
    "unfolding" "[" definitions:Lean.Parser.Tactic.simpArg,* "]" : tactic => do
  let specs : Lean.Syntax.TSepArray
      [`Lean.Parser.Tactic.simpStar, `Lean.Parser.Tactic.simpErase, `Lean.Parser.Tactic.simpLemma] "," :=
    ⟨specs.elemsAndSeps⟩
  let definitions : Lean.Syntax.TSepArray
      [`Lean.Parser.Tactic.simpStar, `Lean.Parser.Tactic.simpErase, `Lean.Parser.Tactic.simpLemma] "," :=
    ⟨definitions.elemsAndSeps⟩
  `(tactic| (
  try dsimp only [BodyContract, Program.enableLoops, Control.Code.enableLoops]
  set_option experimental.vcgen true in vcgen [$specs,*]
  all_goals call_normalize [$definitions,*]))

macro "call_vcgen" "[" specs:Lean.Parser.Tactic.simpArg,* "]" : tactic => do
  let specs : Lean.Syntax.TSepArray
      [`Lean.Parser.Tactic.simpStar, `Lean.Parser.Tactic.simpErase, `Lean.Parser.Tactic.simpLemma] "," :=
    ⟨specs.elemsAndSeps⟩
  `(tactic| call_vcgen [$specs,*] unfolding [])

macro "call_vcgen" : tactic => `(tactic| call_vcgen [])

end Compiler.ZigAir.MemoryCall
