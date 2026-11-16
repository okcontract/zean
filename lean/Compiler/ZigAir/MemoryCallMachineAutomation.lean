/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryCallMachineVCGen
import Compiler.ZigAir.MemoryAutomation

/-! Proof-producing VC generation over the canonical call-stack interpreter.
Unfold the selected generated functions and supplied summaries before calling
this tactic. Function identities and instruction numbers are ordinary data.
Remaining goals are verification obligations, never a successful safety result. -/
namespace Compiler.ZigAir.MemoryCallMachine
open MemoryAir.Verify

/-- Lean 4.35's experimental `vcgen` matches instruction constructors before
reducing nested structure projections. Resume generation after definitional
reduction; no execution, recursive unrolling or extra proof oracle is used. -/
macro "machine_vcgen" "[" specs:Lean.Parser.Tactic.simpArg,* "]" : tactic => do
  let specs : Lean.Syntax.TSepArray
      [`Lean.Parser.Tactic.simpStar, `Lean.Parser.Tactic.simpErase, `Lean.Parser.Tactic.simpLemma] "," :=
    ⟨specs.elemsAndSeps⟩
  `(tactic| (
    set_option experimental.vcgen true in vcgen (errorOnMissingSpec := false) [$specs,*]
    all_goals air_conditions
    repeat' (
      dsimp only at *
      all_goals try (set_option experimental.vcgen true in vcgen (errorOnMissingSpec := false) [$specs,*])
      all_goals air_conditions)))

macro "machine_vcgen" : tactic => `(tactic| machine_vcgen [])

/-- Expose client assertions and normalize invocation cleanup alongside the
shared memory obligations. This does not discharge domain-specific invariants. -/
macro "machine_normalize" "[" definitions:Lean.Parser.Tactic.simpArg,* "]" : tactic => do
  let definitions : Lean.Syntax.TSepArray
      [`Lean.Parser.Tactic.simpStar, `Lean.Parser.Tactic.simpErase, `Lean.Parser.Tactic.simpLemma] "," :=
    ⟨definitions.elemsAndSeps⟩
  `(tactic| (
    all_goals try simp only [$definitions,*] at *
    all_goals try simp only [Function.accepts, ResourcePolicy.cleanup, Observes, unwind] at *
    air_normalize
    all_goals try simp only [Option.some.injEq, Memory.Value.scalar.injEq] at *
    all_goals air_subst))

macro "machine_normalize" : tactic => `(tactic| machine_normalize [])

end Compiler.ZigAir.MemoryCallMachine
