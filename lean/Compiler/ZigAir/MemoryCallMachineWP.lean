/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryCallMachineContext
import Compiler.ZigAir.MemoryCallMachineVerification

/-! Weakest-precondition contracts for the actual call-stack machine. The WP
quantifies over every finite observation. It allows suspension without assuming
termination, and checks both successful and exceptional continuations. -/
namespace Compiler.ZigAir.MemoryCallMachine
open Memory Std.WP Lean.Order

abbrev Postcondition := Value → State → Prop
abbrev Exceptions := Fault → State → Prop

def Ensures (program : Program) (first : Execution) (post : Postcondition) (errors : Exceptions) : Prop :=
  ∀ fuel, Observes post errors (advance program fuel first)

theorem Observes.mono (post post' : Postcondition) (errors errors' : Exceptions)
    (hp : ∀ value state, post value state → post' value state)
    (he : ∀ fault state, errors fault state → errors' fault state)
    (execution : Execution) (checked : Observes post errors execution) :
    Observes post' errors' execution := by
  cases execution with
  | suspended => trivial
  | finished result state => cases result with
    | ok value => exact hp value state checked
    | error fault => exact he fault state checked

/-- A continuation is entered only when the isolated callee has finished.
The premise also covers a callee that never returns and one that fails after
writing to caller memory. -/
theorem Ensures.attach (resources : ResourcePolicy) (callers : List Caller)
    (first : Execution) (consistent : Uses resources first)
    (checked : Ensures program first
      (fun value state => Ensures program (attach resources callers (.finished (.ok value) state)) post errors)
      (fun fault state => Ensures program (attach resources callers (.finished (.error fault) state)) post errors)) :
    Ensures program (attach resources callers first) post errors := by
  intro fuel
  induction fuel generalizing first with
  | zero =>
    cases first with
    | suspended => trivial
    | finished result state => cases result <;> exact checked 0 0
  | succ fuel ih =>
    cases first with
    | finished result state => cases result <;> exact checked 0 (fuel + 1)
    | suspended config =>
      have tail : Ensures program (step program config)
          (fun value state => Ensures program (MemoryCallMachine.attach resources callers (.finished (.ok value) state)) post errors)
          (fun fault state => Ensures program (MemoryCallMachine.attach resources callers (.finished (.error fault) state)) post errors) :=
        fun fuel => checked (fuel + 1)
      have nextUses : Uses resources (step program config) := by
        simpa only [Uses] using consistent ▸ uses_step program config
      change Observes post errors (advance program fuel
        (step program { config with callers := config.callers ++ callers }))
      rw [step_attach, consistent]
      exact ih _ nextUses tail

/-- A state-indexed machine entry point. This is a verification interface over
`advance`, not an alternative evaluator or a table of assumed callee effects. -/
structure Task where
  program : Program
  start : State → Execution

instance taskWP : WP Task Value (State → Prop) Exceptions where
  wpTrans task := ⟨fun post errors state => Ensures task.program (task.start state) post errors⟩
  wp_trans_monotone _task post post' errors errors' he hp _state checked fuel :=
    Observes.mono post post' errors errors' hp he _ (checked fuel)

theorem wp_task (task : Task) (post : Postcondition) (errors : Exceptions) (state : State) :
    wp task post errors state = Ensures task.program (task.start state) post errors := rfl

/-- A manual invariant can cover arbitrary control flow, loops and calls. This
rule shares finite reachability with `Safe`; it requires no termination bound. -/
theorem invariant_spec (task : Task) (invariant : Execution → Prop)
    (post : Postcondition) (errors : Exceptions)
    (closed : ∀ config, invariant (.suspended config) → invariant (step task.program config))
    (observed : ∀ execution, invariant execution → Observes post errors execution) :
    Triple task (fun state => invariant (task.start state)) post errors := by
  constructor
  intro state initial fuel
  exact observed _ ((advance_steps task.program fuel (task.start state)).preserves
    task.program invariant closed initial)

def invoke (program : Program) (root : Nat) (args : List Value)
    (resources : ResourcePolicy := .history) : Task :=
  ⟨program, fun state => start program root args state resources⟩

def finish (program : Program) (result : Except Fault Value) : Task :=
  ⟨program, fun state => .finished result state⟩

def within (resources : ResourcePolicy) (callers : List Caller) (task : Task) : Task :=
  ⟨task.program, fun state => attach resources callers (task.start state)⟩

@[spec] theorem finish_ok_spec (program : Program) (value : Value) (post : Postcondition) (errors : Exceptions) :
    Triple (finish program (.ok value)) (post value) post errors := by
  constructor
  intro state checked fuel
  simpa only [finish, advance_finished, Observes] using checked

@[spec] theorem finish_error_spec (program : Program) (fault : Fault) (post : Postcondition) (errors : Exceptions) :
    Triple (finish program (.error fault)) (errors fault) post errors := by
  constructor
  intro state checked fuel
  simpa only [finish, advance_finished, Observes] using checked

theorem within_spec (resources : ResourcePolicy) (callers : List Caller)
    (task : Task) (consistent : ∀ state, Uses resources (task.start state))
    (post : Postcondition) (errors : Exceptions) :
    Triple (within resources callers task)
      (wp task
        (fun value => wp (within resources callers (finish task.program (.ok value))) post errors)
        (fun fault => wp (within resources callers (finish task.program (.error fault))) post errors)) post errors :=
  ⟨fun state checked => Ensures.attach resources callers _ (consistent state) checked⟩

/-- A checked procedure contract is reusable through Std.WP. Exception
postconditions retain the reached state; they are not silently discarded. -/
theorem Contract.apply (contract : Contract program root resources) (args : List Value)
    (post : Postcondition) (errors : Exceptions) :
    Triple (invoke program root args resources)
      (fun state => ⌜contract.precondition args state⌝ ⊓
        ((⨅ value, ⨅ after, ⌜contract.postcondition args state value after⌝ ⇨ post value after) ⊓
         (⨅ fault, ⨅ after, ⌜contract.exceptions args state fault after⌝ ⇨ errors fault after))) post errors := by
  constructor
  intro state checked fuel
  simp only [meet_prop_eq_and, iInf_prop_eq_forall, himp_prop_eq_imp, ofProp_prop_eq] at checked
  exact Observes.mono _ _ _ _ checked.2.1 checked.2.2 _ (contract.checked args state checked.1 fuel)

/-- Every finite execution is covered. No native execution or termination claim
is introduced by registering this WP instance. -/
theorem sound (task : Task) (pre : State → Prop) (post : Postcondition) (errors : Exceptions)
    (checked : Triple task pre post errors) (state : State) (accepted : pre state) (fuel : Nat) :
    Observes post errors (advance task.program fuel (task.start state)) :=
  checked.le_wp state accepted fuel

theorem safe_of_spec (task : Task) (pre : State → Prop) (post : Postcondition) (errors : Exceptions)
    (checked : Triple task pre post errors) (state : State) (accepted : pre state)
    (allowed : ∀ fault after, errors fault after → fault = .outOfMemory) :
    Safe task.program (task.start state) := by
  apply (safe_iff_fuel task.program _).mpr
  intro fuel fault after reached
  have observed := sound task pre post errors checked state accepted fuel
  rw [reached] at observed
  exact allowed fault after observed

end Compiler.ZigAir.MemoryCallMachine
