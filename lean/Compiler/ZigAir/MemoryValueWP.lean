/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryReferenceWP

namespace Compiler.ZigAir.MemoryAir.Verify
open Memory Std.WP Lean.Order

structure ReadMemory where
  operation : State → Except Fault Value

instance readMemoryWP : WP ReadMemory Value (State → Prop) FaultCondition where
  wpTrans read := ⟨fun post errors state => match read.operation state with
    | .ok value => post value state | .error fault => errors fault state⟩
  wp_trans_monotone read post post' errors errors' he hp state h := by
    dsimp only at h ⊢
    cases evaluated : read.operation state with
    | ok value => exact hp value state (by simpa only [evaluated] using h)
    | error fault => exact he fault state (by simpa only [evaluated] using h)

theorem wp_readMemory (operation : State → Except Fault Value) (post : Postcondition)
    (errors : FaultCondition) (state : State) :
    wp (ReadMemory.mk operation) post errors state = match operation state with
      | .ok value => post value state | .error fault => errors fault state := rfl

@[spec] theorem readMemory_spec (operation : State → Except Fault Value) (post : Postcondition)
    (errors : FaultCondition) :
    Triple (ReadMemory.mk operation)
      (fun state => (⨅ value, ⌜operation state = .ok value⌝ ⇨ post value state) ⊓
        (⨅ fault, ⌜operation state = .error fault⌝ ⇨ errors fault state)) post errors := by
  constructor
  intro state h
  simp only [meet_prop_eq_and, iInf_prop_eq_forall, himp_prop_eq_imp, ofProp_prop_eq] at h
  rw [wp_readMemory]
  cases evaluated : operation state with
  | ok value => exact h.1 value evaluated
  | error fault => exact h.2 fault evaluated

def naturalValue : Value → Except Fault Nat
  | .scalar (.int false 64 number) => .ok number.toNat
  | _ => .error .malformed

structure NaturalValue where
  value : Value

instance naturalValueWP : WP NaturalValue Nat (State → Prop) FaultCondition where
  wpTrans read := ⟨fun post errors state => match naturalValue read.value with
    | .ok number => post number state | .error fault => errors fault state⟩
  wp_trans_monotone read post post' errors errors' he hp state h := by
    dsimp only at h ⊢
    cases evaluated : naturalValue read.value with
    | ok number => exact hp number state (by simpa only [evaluated] using h)
    | error fault => exact he fault state (by simpa only [evaluated] using h)

theorem wp_naturalValue (value : Value) (post : Nat → State → Prop) (errors : FaultCondition) (state : State) :
    wp (NaturalValue.mk value) post errors state = match naturalValue value with
      | .ok number => post number state | .error fault => errors fault state := rfl

@[spec] theorem naturalValue_spec (value : Value) (post : Nat → State → Prop) (errors : FaultCondition) :
    Triple (NaturalValue.mk value)
      (fun state => (⨅ number, ⌜naturalValue value = .ok number⌝ ⇨ post number state) ⊓
        (⨅ fault, ⌜naturalValue value = .error fault⌝ ⇨ errors fault state)) post errors := by
  constructor
  intro state h
  simp only [meet_prop_eq_and, iInf_prop_eq_forall, himp_prop_eq_imp, ofProp_prop_eq] at h
  rw [wp_naturalValue]
  cases evaluated : naturalValue value with
  | ok number => exact h.1 number evaluated
  | error fault => exact h.2 fault evaluated

theorem Ref.natural_value (ref : Ref) (env : Env) : ref.natural env = ref.eval env >>= naturalValue := by
  rw [Ref.natural_eq]
  cases ref.eval env <;> rfl

end Compiler.ZigAir.MemoryAir.Verify
