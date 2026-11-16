/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryVerification
import Compiler.ZigAir.MemoryAirLaws

namespace Compiler.ZigAir.MemoryAir.Verify
open Memory Std.WP Lean.Order

/-- Reference evaluation is pure but still checks initialization of SSA locals
and validity of the stored value. -/
structure ReadReference where
  ref : Ref
  env : Env

instance referenceWP : WP ReadReference Value (State → Prop) FaultCondition where
  wpTrans read := ⟨fun post errors state => match read.ref.eval read.env with
    | .ok value => post value state
    | .error fault => errors fault state⟩
  wp_trans_monotone read post post' errors errors' he hp state h := by
    dsimp only at h ⊢
    cases evaluated : read.ref.eval read.env with
    | ok value => exact hp value state (by simpa only [evaluated] using h)
    | error fault => exact he fault state (by simpa only [evaluated] using h)

theorem wp_reference (ref : Ref) (env : Env) (post : Postcondition) (errors : FaultCondition) (state : State) :
    wp (ReadReference.mk ref env) post errors state = match ref.eval env with
      | .ok value => post value state | .error fault => errors fault state := rfl

@[spec] theorem read_constant_spec (value : Value) (env : Env) (post : Postcondition) (errors : FaultCondition) :
    Triple (ReadReference.mk (.constant value) env)
      (fun state => (⌜value.valid = true⌝ ⇨ post value state) ⊓
        (⌜value.valid ≠ true⌝ ⇨ errors .malformed state)) post errors := by
  constructor
  intro state h
  simp only [meet_prop_eq_and, himp_prop_eq_imp, ofProp_prop_eq] at h
  rw [wp_reference, Ref.eval_constant]
  by_cases valid : value.valid = true
  · simpa only [valid, ↓reduceIte] using h.1 valid
  · simpa only [valid, Bool.false_eq_true, ↓reduceIte] using h.2 valid

@[spec] theorem read_local_spec (id : Nat) (env : Env) (post : Postcondition) (errors : FaultCondition) :
    Triple (ReadReference.mk (.local id) env)
      (fun state =>
        (⨅ value, ⌜env id = some value⌝ ⇨ wp (ReadReference.mk (.constant value) env) post errors state) ⊓
        (⌜env id = none⌝ ⇨ errors .malformed state)) post errors := by
  constructor
  intro state h
  simp only [meet_prop_eq_and, iInf_prop_eq_forall, himp_prop_eq_imp, ofProp_prop_eq] at h
  rw [wp_reference, Ref.eval_local]
  cases found : env id with
  | none => exact h.2 found
  | some value => simpa only [wp_reference, Ref.eval_constant] using h.1 value found

theorem Ref.eval_valid (ref : Ref) (env : Env) (value : Value) (read : ref.eval env = .ok value) :
    value.valid = true := by
  cases ref with
  | constant contents =>
    rw [Ref.eval_constant] at read
    split at read
    · cases Except.ok.inj read; assumption
    · contradiction
  | «local» id =>
    rw [Ref.eval_local] at read
    cases found : env id with
    | none => simp [found] at read
    | some contents =>
      simp only [found] at read
      split at read
      · cases Except.ok.inj read; assumption
      · contradiction

end Compiler.ZigAir.MemoryAir.Verify
