/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MachineCoverage

namespace Compiler.ZigAir.Control.Machine

variable (sem : Semantics Ty Prim Ref Value Fault State) (args : List Value)
    (allowed : Nat × Ty × Prim → Prop) (invariant : State → Prop)
    (preserves : ∀ site, allowed site → ∀ env state, invariant state →
      invariant (sem.evalPrim site.2.2 args env state).2)

include preserves

/-- State preservation only needs contracts for the instructions present in
this code and its saved continuations. Unrelated primitives are unconstrained. -/
theorem step_preserves_covered (config : Config Ty Prim Ref Value State)
    (covered : (Execution.suspended (Fault := Fault) config).covered allowed)
    (initial : invariant config.state) : invariant (step sem args config).state := by
  obtain ⟨code, env, state, frames⟩ := config
  cases code with
  | bind id ty prim next =>
    have contract := covered.1 (id, ty, prim) (by simp [Code.bindings])
    cases evaluated : sem.evalPrim prim args env state with
    | mk result after =>
      have kept : invariant after := by simpa only [evaluated] using preserves _ contract env state initial
      cases result <;> simp only [step, evaluated]
      · exact kept
      · split <;> exact kept
  | branch condition yes no =>
    cases evaluated : sem.evalRef condition env with
    | error => simpa only [step, evaluated, Execution.state, Outcome.state] using initial
    | ok value =>
      cases flag : sem.truth value <;>
        simpa only [step, evaluated, flag, Execution.state, Outcome.state] using initial
  | block | loop => exact initial
  | «repeat» => simpa only [step, backedge_state] using initial
  | jump target ref =>
    cases evaluated : sem.evalRef ref env with
    | error => simpa only [step, evaluated, Execution.state, Outcome.state] using initial
    | ok value => simpa only [step, evaluated, jump_state] using initial
  | ret ref => cases evaluated : sem.evalRef ref env <;>
      simpa only [step, evaluated, Execution.state, Outcome.state] using initial

theorem advance_preserves_covered (fuel : Nat) (execution : Execution Ty Prim Ref Value Fault State)
    (covered : execution.covered allowed) (initial : invariant execution.state) :
    invariant (advance sem args fuel execution).state := by
  induction fuel generalizing execution with
  | zero => exact initial
  | succ fuel ih =>
    cases execution with
    | finished => exact initial
    | suspended config =>
      exact ih (step sem args config) (step_covered sem args allowed config covered)
        (step_preserves_covered sem args allowed invariant preserves config covered initial)

end Compiler.ZigAir.Control.Machine
