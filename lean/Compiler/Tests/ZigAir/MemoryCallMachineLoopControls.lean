/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.Verify.Machine

namespace Compiler.Tests.ZigAir.MemoryCallMachineLoopControls
open Compiler.ZigAir Compiler.ZigAir.Memory MemoryCallMachine Std.WP Lean.Order
open MemoryAir.Verify

def select : Function := ⟨[.scalar .bool], .scalar .bool,
  .bind 3 (.scalar .bool) (.memory (.argument 0)) <|
  .block 17 (.scalar .bool)
    (.branch (.local 3)
      (.jump 17 (.constant (.scalar (.bool true))))
      (.jump 17 (.constant (.scalar (.bool false))))) <|
  .ret (.local 17)⟩

/-- Both paths and a typed block result, for arbitrary input and valid memory. -/
theorem select_checked (state : State) (valid : state.valid = true) (flag : Bool) :
    Triple (verify [select] 0 [.scalar (.bool flag)] (fun _ _ _ => False))
      (fun before => before = state)
      (fun value after => value = .scalar (.bool flag) ∧ after = state) (fun _ _ => False) := by
  dsimp only [select]
  machine_vcgen
  machine_normalize
  air_reduce
  air_finish (verbose := false) [Value.hasType, Value.type, Value.valid, Scalar.Value.type, Scalar.Value.valid]

def helper : Function := ⟨[], .scalar .unit, .ret (.constant (.scalar .unit))⟩

def negation : Function := ⟨[.scalar .bool], .scalar .bool,
  .bind 4 (.scalar .bool) (.memory (.argument 0)) <|
  .bind 7 (.scalar .bool) (.memory (.booleanNot (.local 4))) <|
  .ret (.local 7)⟩

/-- Boolean control needs only the core verifier, with no record-field import. -/
theorem negation_checked (state : State) (valid : state.valid = true) (flag : Bool) :
    Triple (verify [negation] 0 [.scalar (.bool flag)] (fun _ _ _ => False))
      (fun before => before = state)
      (fun value after => value = .scalar (.bool (!flag)) ∧ after = state) (fun _ _ => False) := by
  dsimp only [negation]
  machine_vcgen
  machine_normalize
  air_reduce
  air_finish (verbose := false) [Value.hasType, Value.type, Value.valid, Scalar.Value.type, Scalar.Value.valid]

def spinning : Function := ⟨[.scalar .bool], .scalar .unit,
  .bind 8 (.scalar .bool) (.memory (.argument 0)) <|
  .loop rfl 23 <| .branch (.local 8)
    (.bind 91 (.scalar .unit) (.call 0 []) (.repeat rfl 23))
    (.ret (.constant (.scalar .unit)))⟩
abbrev functions : Program := [helper, spinning]

theorem helper_checked (state : State) (valid : state.valid = true) :
    Triple (invoke functions 0 []) (fun before => before = state)
      (fun value after => value = .scalar .unit ∧ after = state) (fun _ _ => False) := by
  dsimp only [functions, helper]
  machine_vcgen
  all_goals simp_all [Function.accepts, ResourcePolicy.cleanup, cleanup_initial]

def helperContract : MemoryCallMachine.Contract functions 0 where
  precondition := fun args state => args = [] ∧ state.valid = true
  postcondition := fun _ before value after => value = .scalar .unit ∧ after = before
  exceptions := fun _ _ _ _ => False
  checked := by
    intro args before pre fuel
    obtain ⟨rfl, valid⟩ := pre
    exact sound _ _ _ _ (helper_checked before valid) before rfl fuel

theorem helper_spec (post : MemoryCallMachine.Postcondition) (errors : Exceptions) :
    Triple (invoke functions 0 [])
      (fun state => ⌜helperContract.precondition [] state⌝ ⊓
        ((⨅ value, ⨅ after, ⌜helperContract.postcondition [] state value after⌝ ⇨ post value after) ⊓
        (⨅ fault, ⨅ after, ⌜helperContract.exceptions [] state fault after⌝ ⇨ errors fault after))) post errors :=
  helperContract.apply [] post errors

def invariant (flag : Bool) (initial : State) : VC.Invariants :=
  fun _ env state => env 8 = some (.scalar (.bool flag)) ∧ state = initial

attribute [local irreducible] helper

/-- A loop can be verified without termination. Its helper remains opaque and
the back edge must restore the assertion about both locals and memory. -/
theorem spinning_checked (state : State) (valid : state.valid = true) (flag : Bool) :
    Triple (verify functions 1 [.scalar (.bool flag)] (invariant flag state))
      (fun before => before = state)
      (fun value after => value = .scalar .unit ∧ after = state) (fun _ _ => False) := by
  have helperRule := helper_spec
  dsimp only [functions, spinning] at helperRule ⊢
  machine_vcgen [helperRule]
  all_goals clear helperRule
  machine_normalize [invariant, helperContract]
  air_reduce
  air_finish (verbose := false) [Value.hasType, Value.type, Value.valid, Scalar.Value.type, Scalar.Value.valid]

def nested : Function := ⟨[.scalar .bool, .scalar .bool], .scalar .unit,
  .bind 8 (.scalar .bool) (.memory (.argument 0)) <|
  .loop rfl 23 <|
    .block 17 (.scalar .unit)
      (.loop rfl 31 <| .branch (.local 8)
        (.bind 8 (.scalar .bool) (.memory (.argument 1)) (.repeat rfl 23))
        (.jump 17 (.constant (.scalar .unit))))
      (.ret (.constant (.scalar .unit)))⟩

def nestedInvariant (initial : State) : VC.Invariants :=
  fun _ env state => state = initial ∧ ∃ flag : Bool, env 8 = some (.scalar (.bool flag))

/-- A back edge can cross a block and an inner loop; a block exit can cross
the inner loop in the opposite branch. Both paths use the same generic rules. -/
theorem nested_checked (state : State) (valid : state.valid = true) (flag : Bool) :
    Triple (verify [nested] 0 [.scalar (.bool flag), .scalar (.bool false)] (nestedInvariant state))
      (fun before => before = state)
      (fun value after => value = .scalar .unit ∧ after = state) (fun _ _ => False) := by
  dsimp only [nested]
  machine_vcgen
  machine_normalize [nestedInvariant]
  air_reduce
  air_finish (verbose := false) [Value.hasType, Value.type, Value.valid, Scalar.Value.type, Scalar.Value.valid]

def lateFault : Program := [
  ⟨[], .scalar .unit, .bind 6 (.scalar .unit) (.memory .unreachable) (.ret (.constant (.scalar .unit)))⟩,
  ⟨[.scalar .bool, .scalar .bool], .scalar .unit,
    .bind 8 (.scalar .bool) (.memory (.argument 0)) <|
    .loop rfl 23 <| .branch (.local 8)
      (.bind 8 (.scalar .bool) (.memory (.argument 1)) (.repeat rfl 23))
      (.bind 91 (.scalar .unit) (.call 0 []) (.ret (.constant (.scalar .unit))))⟩]

/-- The fault occurs in the helper on the second iteration, after a back edge. -/
theorem late_fault_reached :
    run lateFault 8 1 [.scalar (.bool true), .scalar (.bool false)] {} =
      .finished (.error (.scalar .illegalBehavior)) {} := rfl

theorem no_invariant_can_hide_late_fault (invariants : VC.Invariants) :
    ¬Triple (verify lateFault 1 [.scalar (.bool true), .scalar (.bool false)] invariants)
      (fun state => state = {}) (fun _ _ => True) (fun _ _ => False) := by
  intro checked
  have observed := sound _ _ _ _ checked {} rfl 8
  change MemoryCallMachine.Observes _ _
    (run lateFault 8 1 [.scalar (.bool true), .scalar (.bool false)] {}) at observed
  rw [late_fault_reached] at observed
  exact observed

def malformedBodies : List Code := [
  .branch (.constant (.scalar .unit)) (.ret (.constant (.scalar .unit))) (.ret (.constant (.scalar .unit))),
  .repeat rfl 40,
  .loop rfl 40 (.jump 40 (.constant (.scalar .unit))),
  .block 40 (.scalar .bool) (.jump 40 (.constant (.scalar .unit))) (.ret (.constant (.scalar .unit)))]

/-- Ill-typed branch conditions, missing back edges, jumps to loops and wrong
block result types all remain faults in the executable control representation. -/
theorem malformed_controls_reached :
    malformedBodies.map (fun body => run [⟨[], .scalar .unit, body⟩] 2 0 [] {}) =
      List.replicate 4 (.finished (.error .malformed) {}) := rfl

theorem semantic_bindings_selected :
    Bindings.argument select.body 0 = some ⟨3, .scalar .bool⟩ ∧
    Bindings.singleLoop spinning.body = some 23 := by decide +kernel

theorem ambiguous_bindings_reject :
    Bindings.argument (.branch (.constant (.scalar (.bool true))) select.body negation.body) 0 = none ∧
    Bindings.singleLoop (.loop rfl 10 spinning.body) = none := ⟨rfl, rfl⟩

end Compiler.Tests.ZigAir.MemoryCallMachineLoopControls
