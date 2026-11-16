/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryVerification

namespace Compiler.ZigAir.MemoryAir.Verify
open Memory Std.WP Lean.Order

structure ReadScalar where
  ref : Scalar.Ref
  env : Scalar.Env

instance readScalarWP : WP ReadScalar Scalar.Value (State → Prop) FaultCondition where
  wpTrans read := ⟨fun post errors state => match read.ref.eval read.env with
    | .ok value => post value state | .error fault => errors (.scalar fault) state⟩
  wp_trans_monotone read post post' errors errors' he hp state h := by
    dsimp only at h ⊢
    cases evaluated : read.ref.eval read.env with
    | ok value => exact hp value state (by simpa only [evaluated] using h)
    | error fault => exact he (.scalar fault) state (by simpa only [evaluated] using h)

theorem wp_readScalar (ref : Scalar.Ref) (env : Scalar.Env) (post : Scalar.Value → State → Prop)
    (errors : FaultCondition) (state : State) :
    wp (ReadScalar.mk ref env) post errors state = match ref.eval env with
      | .ok value => post value state | .error fault => errors (.scalar fault) state := rfl

@[spec] theorem readScalar_constant_spec (value : Scalar.Value) (env : Scalar.Env)
    (post : Scalar.Value → State → Prop) (errors : FaultCondition) :
    Triple (ReadScalar.mk (.constant value) env)
      (fun state => (⌜value.valid = true⌝ ⇨ post value state) ⊓
        (⌜value.valid ≠ true⌝ ⇨ errors (.scalar .malformed) state)) post errors := by
  constructor
  intro state h
  simp only [meet_prop_eq_and, himp_prop_eq_imp, ofProp_prop_eq] at h
  rw [wp_readScalar]
  simp only [Scalar.Ref.eval]
  by_cases valid : value.valid = true
  · simpa only [valid, ↓reduceIte] using h.1 valid
  · simpa only [valid, Bool.false_eq_true, ↓reduceIte] using h.2 valid

@[spec] theorem readScalar_local_spec (id : Nat) (env : Scalar.Env)
    (post : Scalar.Value → State → Prop) (errors : FaultCondition) :
    Triple (ReadScalar.mk (.local id) env)
      (fun state =>
        (⨅ value, ⌜env id = some value⌝ ⇨ wp (ReadScalar.mk (.constant value) env) post errors state) ⊓
        (⌜env id = none⌝ ⇨ errors (.scalar .malformed) state)) post errors := by
  constructor
  intro state h
  simp only [meet_prop_eq_and, iInf_prop_eq_forall, himp_prop_eq_imp, ofProp_prop_eq] at h
  rw [wp_readScalar]
  simp only [Scalar.Ref.eval]
  cases found : env id with
  | none => exact h.2 found
  | some value => simpa only [wp_readScalar, Scalar.Ref.eval] using h.1 value found

structure ScalarResult where
  result : Scalar.Result

instance scalarResultWP : WP ScalarResult Value (State → Prop) FaultCondition where
  wpTrans computation := ⟨fun post errors state => match computation.result with
    | .ok value => post (.scalar value) state | .error fault => errors (.scalar fault) state⟩
  wp_trans_monotone computation post post' errors errors' he hp state h := by
    dsimp only at h ⊢
    cases evaluated : computation.result with
    | ok value => exact hp (.scalar value) state (by simpa only [evaluated] using h)
    | error fault => exact he (.scalar fault) state (by simpa only [evaluated] using h)

theorem wp_scalarResult (result : Scalar.Result) (post : Postcondition) (errors : FaultCondition) (state : State) :
    wp (ScalarResult.mk result) post errors state = match result with
      | .ok value => post (.scalar value) state | .error fault => errors (.scalar fault) state := rfl

@[spec] theorem scalarResult_spec (result : Scalar.Result) (post : Postcondition) (errors : FaultCondition) :
    Triple (ScalarResult.mk result)
      (fun state => (⨅ value, ⌜result = .ok value⌝ ⇨ post (.scalar value) state) ⊓
        (⨅ fault, ⌜result = .error fault⌝ ⇨ errors (.scalar fault) state)) post errors := by
  constructor
  intro state h
  simp only [meet_prop_eq_and, iInf_prop_eq_forall, himp_prop_eq_imp, ofProp_prop_eq] at h
  rw [wp_scalarResult]
  cases result with
  | ok value => exact h.1 value rfl
  | error fault => exact h.2 fault rfl

end Compiler.ZigAir.MemoryAir.Verify
