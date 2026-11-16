/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.Verify.Machine
import Compiler.ZigAir.Verify.Words
import Compiler.Tests.ZigAir.MemoryCallMachineControls

namespace Compiler.Tests.ZigAir.MemoryCallMachineWPControls
open Compiler.ZigAir Compiler.ZigAir.Memory MemoryCallMachine Std.WP
open MemoryAir.Verify
open Lean.Order


def callee : Function := ⟨[], .scalar .unit, .ret (.constant (.scalar .unit))⟩
def caller : Function := ⟨[], .scalar .unit,
  .bind 9 (.scalar .unit) (.call 0 []) (.ret (.local 9))⟩
abbrev functions : Program := [callee, caller]

theorem callee_checked (state : State) (valid : state.valid = true) :
    Triple (invoke functions 0 []) (fun before => before = state)
      (fun value after => value = .scalar .unit ∧ after = state) (fun _ _ => False) := by
  dsimp only [functions, callee]
  machine_vcgen
  all_goals simp_all [Function.accepts, unit_typed, ResourcePolicy.cleanup, cleanup_initial]

def calleeContract : MemoryCallMachine.Contract functions 0 where
  precondition := fun args state => args = [] ∧ state.valid = true
  postcondition := fun _ before value after => value = .scalar .unit ∧ after = before
  exceptions := fun _ _ _ _ => False
  checked := by
    intro args before pre fuel
    obtain ⟨rfl, valid⟩ := pre
    exact sound _ _ _ _ (callee_checked before valid) before rfl fuel

@[spec high] theorem callee_spec (post : MemoryCallMachine.Postcondition) (errors : Exceptions) :
    Triple (invoke functions 0 [])
      (fun state => ⌜calleeContract.precondition [] state⌝ ⊓
        ((⨅ value, ⨅ after, ⌜calleeContract.postcondition [] state value after⌝ ⇨ post value after) ⊓
        (⨅ fault, ⨅ after, ⌜calleeContract.exceptions [] state fault after⌝ ⇨ errors fault after))) post errors :=
  calleeContract.apply [] post errors

attribute [local irreducible] callee
/-- The caller uses a checked summary. The callee's body is not unfolded here. -/
theorem caller_checked (state : State) (valid : state.valid = true) :
    Triple (invoke functions 1 []) (fun before => before = state)
      (fun value after => value = .scalar .unit ∧ after = state) (fun _ _ => False) := by
  have helper := callee_spec
  dsimp only [functions, caller] at helper ⊢
  machine_vcgen [helper]
  all_goals clear helper
  all_goals try simp only [calleeContract, Control.Env.set, ite_true, Option.some.injEq] at *
  all_goals air_split
  all_goals air_subst
  all_goals simp_all [Function.accepts, unit_typed, ResourcePolicy.cleanup, cleanup_initial]

/- Synthetic memory client: the same library rules accept a different body,
arguments and contract without instruction-specific verifier logic. -/
namespace Write
open WordArray

def put : Function := ⟨[.pointer true false word, word], .scalar .unit,
  .bind 0 (.pointer true false word) (.memory (.argument 0)) <|
  .bind 1 word (.memory (.argument 1)) <|
  .bind 2 (.scalar .unit) (.memory (.store (.local 0) (.local 1))) <|
  .ret (.constant (.scalar .unit))⟩

def update : Function := ⟨[.pointer true false word, word], .scalar .unit,
  .bind 5 (.pointer true false word) (.memory (.argument 0)) <|
  .bind 8 word (.memory (.argument 1)) <|
  .bind 11 (.scalar .unit) (.call 0 [.local 5, .local 8]) <|
  .ret (.constant (.scalar .unit))⟩

abbrev functions : Program := [put, update]

theorem put_checked (state : State) (view : View) (value : BitVec 32)
    (valid : state.valid = true) (writable : Writable state view) (nonempty : 0 < view.length) :
    Triple (invoke functions 0 [view.pointer 0, number value]) (fun before => before = state)
      (fun result after => result = .scalar .unit ∧ after.valid = true) (fun _ _ => False) := by
  dsimp only [functions, put]
  machine_vcgen
  all_goals try simp only [Function.accepts, ResourcePolicy.cleanup, MemoryCallMachine.Observes, unwind] at *
  air_normalize
  air_reduce
  air_reduce
  air_word_finish

def putContract : MemoryCallMachine.Contract functions 0 where
  precondition := fun args state => ∃ view value,
    args = [view.pointer 0, number value] ∧ state.valid = true ∧ Writable state view ∧ 0 < view.length
  postcondition := fun _ _ result after => result = .scalar .unit ∧ after.valid = true
  exceptions := fun _ _ _ _ => False
  checked := by
    intro args before pre fuel
    obtain ⟨view, value, rfl, valid, writable, nonempty⟩ := pre
    exact sound _ _ _ _ (put_checked before view value valid writable nonempty) before rfl fuel

theorem put_spec (args : List Value) (post : MemoryCallMachine.Postcondition) (errors : Exceptions) :
    Triple (invoke functions 0 args)
      (fun state => ⌜putContract.precondition args state⌝ ⊓
        ((⨅ value, ⨅ after, ⌜putContract.postcondition args state value after⌝ ⇨ post value after) ⊓
        (⨅ fault, ⨅ after, ⌜putContract.exceptions args state fault after⌝ ⇨ errors fault after))) post errors :=
  putContract.apply args post errors

attribute [local irreducible] put

theorem update_checked (state : State) (view : View) (value : BitVec 32)
    (valid : state.valid = true) (writable : Writable state view) (nonempty : 0 < view.length) :
    Triple (invoke functions 1 [view.pointer 0, number value]) (fun before => before = state)
      (fun result after => result = .scalar .unit ∧ after.valid = true) (fun _ _ => False) := by
  have ready : putContract.precondition [view.pointer 0, number value] state :=
    ⟨view, value, rfl, valid, writable, nonempty⟩
  have helper := put_spec
  dsimp only [functions, update] at helper ⊢
  machine_vcgen [helper]
  all_goals clear helper
  all_goals try simp only [putContract, Function.accepts,
    ResourcePolicy.cleanup, MemoryCallMachine.Observes, unwind] at *
  air_normalize
  air_reduce
  air_reduce
  air_word_finish

theorem update_safe (state : State) (view : View) (value : BitVec 32)
    (valid : state.valid = true) (writable : Writable state view) (nonempty : 0 < view.length) :
    Safe functions (start functions 1 [view.pointer 0, number value] state) :=
  safe_of_spec _ _ _ _ (update_checked state view value valid writable nonempty) state rfl
    (fun _ _ impossible => False.elim impossible)

end Write

open MemoryCallMachineControls in
/-- A dangling-pointer execution cannot acquire a fault-free WP certificate. -/
theorem dangling_contract_rejected :
    ¬Triple (invoke dangling 0 []) (fun state => state = {})
      (fun _ _ => True) (fun _ _ => False) := by
  intro checked
  have observed := sound _ _ _ _ checked {} rfl 4
  change MemoryCallMachine.Observes _ _ (run dangling 4 0 [] {}) at observed
  rw [dangling_return_fault] at observed
  exact observed

def wrongResult : Program := [
  ⟨[], .scalar .bool, .ret (.constant (.scalar (.bool true)))⟩,
  ⟨[], .scalar .unit, .bind 0 (.scalar .unit) (.call 0 []) (.ret (.constant (.scalar .unit)))⟩]

theorem wrong_result_fault :
    run wrongResult 2 1 [] {} = .finished (.error .malformed) {} := rfl

theorem wrong_result_contract_rejected :
    ¬Triple (invoke wrongResult 1 []) (fun state => state = {})
      (fun _ _ => True) (fun _ _ => False) := by
  intro checked
  have observed := sound _ _ _ _ checked {} rfl 2
  change MemoryCallMachine.Observes _ _ (run wrongResult 2 1 [] {}) at observed
  rw [wrong_result_fault] at observed
  exact observed

end Compiler.Tests.ZigAir.MemoryCallMachineWPControls
