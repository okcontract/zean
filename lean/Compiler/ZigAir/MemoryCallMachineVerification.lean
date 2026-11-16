/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryCallMachineEmbedding
import Compiler.ZigAir.MemoryVerification

namespace Compiler.ZigAir.MemoryCallMachine
open Memory MemoryAir.Verify Std.WP

def Observes (post : Value → State → Prop) (errors : Fault → State → Prop) : Execution → Prop
  | .finished (.ok value) state => post value state
  | .finished (.error fault) state => errors fault state
  | .suspended _ => True

/-- A specification covers every finite observation, including faults inside
callees. It cannot permit a continuation after suspension. -/
structure Contract (program : Program) (root : Nat) (resources : ResourcePolicy := .history) where
  precondition : List Value → State → Prop
  postcondition : List Value → State → Value → State → Prop
  exceptions : List Value → State → Fault → State → Prop
  checked : ∀ args before, precondition args before → ∀ fuel,
    Observes (postcondition args before) (exceptions args before)
      (run program fuel root args before resources)

theorem Contract.safe (contract : Contract program root resources) (args : List Value) (before : State)
    (pre : contract.precondition args before)
    (allowed : ∀ fault after, contract.exceptions args before fault after → fault = .outOfMemory) :
    Safe program (start program root args before resources) := by
  apply (safe_iff_fuel _ _).mpr
  intro fuel fault after reached
  have observation := contract.checked args before pre fuel
  change Observes _ _ (advance program fuel (start program root args before resources)) at observation
  rw [reached] at observation
  exact allowed fault after observation

def FaultFree (program : Program) (first : Execution) : Prop :=
  ∀ fault after, ¬Steps program first (.finished (.error fault) after)

def Terminates (program : Program) (first : Execution) : Prop :=
  ∃ result after, Steps program first (.finished result after)

def Completes (program : Program) (first : Execution) : Prop :=
  ∃ value after, Steps program first (.finished (.ok value) after)

theorem completes_of_terminates (terminates : Terminates program first) (faultFree : FaultFree program first) :
    Completes program first := by
  obtain ⟨result, after, reached⟩ := terminates
  cases result with
  | ok value => exact ⟨value, after, reached⟩
  | error fault => exact False.elim (faultFree fault after reached)

/-- Transfer arbitrary existing Std.WP/vcgen contracts through the exact
intraprocedural adapter. This retains historical resource accounting. Reuse
and interprocedural contracts need their own specifications. -/
theorem ofMemory_contract (program : MemoryAir.Program true) (args : List Value)
    (invariants : MemoryAir.Verify.Invariants) (precondition : State → Prop)
    (post : Postcondition) (errors : FaultCondition)
    (checked : Triple (MemoryAir.Verify.Invocation.mk program args invariants) precondition post errors)
    (before : State) (accepted : precondition before) (fuel : Nat) :
    Observes post errors (run [Function.ofMemory program] fuel 0 args before) := by
  rw [ofMemory_run]
  have observed := MemoryAir.Verify.sound _ _ _ _ checked before accepted fuel
  change MemoryAir.Verify.Observes post errors (program.runFuel fuel args before) at observed
  generalize program.runFuel fuel args before = invocation at observed ⊢
  cases invocation with
  | suspended => trivial
  | finished result after => cases result <;> exact observed

theorem ofMemory_contract_at (table : Program) (root : Nat) (program : MemoryAir.Program true)
    (found : table[root]? = some (Function.ofMemory program))
    (args : List Value) (invariants : MemoryAir.Verify.Invariants) (precondition : State → Prop)
    (post : Postcondition) (errors : FaultCondition)
    (checked : Triple (MemoryAir.Verify.Invocation.mk program args invariants) precondition post errors)
    (before : State) (accepted : precondition before) (fuel : Nat) :
    Observes post errors (run table fuel root args before) := by
  rw [ofMemory_run_at table root program found]
  have observed := ofMemory_contract program args invariants precondition post errors checked before accepted fuel
  rwa [ofMemory_run] at observed

end Compiler.ZigAir.MemoryCallMachine
