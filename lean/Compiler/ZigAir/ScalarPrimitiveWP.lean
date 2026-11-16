/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryPrimitiveWP
import Compiler.ZigAir.ScalarReferenceWP

namespace Compiler.ZigAir.MemoryAir.Verify
open Memory Std.WP Lean.Order Control.Verification

/-- Value-level equations below are connected to `Scalar.Prim.eval` by the
primitive rules. They do not replace the interpreter's checks. -/
def castValue (operation : Scalar.Cast) (destination : Scalar.Ty) : Scalar.Value → Scalar.Result
  | .int s n x => match destination with
    | .int t m => match operation with
      | .unchecked => Scalar.integer t m x .unchecked
      | .checked => Scalar.integer t m x .checked
      | .bitcast => if n = m then Scalar.integer t m x .wrapping else .error .malformed
      | .trunc => if s = t ∧ m ≤ n then Scalar.integer t m x .wrapping else .error .malformed
    | _ => .error .malformed
  | _ => .error .malformed

def compareValues (operation : Scalar.Comparison) : Scalar.Value → Scalar.Value → Scalar.Result
  | .int s n x, .int t m y => if s = t ∧ n = m then .ok (.bool (operation.eval x y)) else .error .malformed
  | _, _ => .error .malformed

def extremumValues (maximum : Bool) : Scalar.Value → Scalar.Value → Scalar.Result
  | .int s n x, .int t m y =>
    if s = t ∧ n = m then .ok (.int s n (if maximum then max x y else min x y))
    else .error .malformed
  | _, _ => .error .malformed

def arithmeticValues (operation : Scalar.Arithmetic) (mode : Scalar.Overflow) :
    Scalar.Value → Scalar.Value → Scalar.Result
  | .int s n x, .int t m y => if s = t ∧ n = m then Scalar.integer s n (operation.eval x y) mode else .error .malformed
  | _, _ => .error .malformed

theorem Scalar.Ref.only_malformed (ref : Scalar.Ref) (env : Scalar.Env) (fault : Scalar.Fault)
    (failed : ref.eval env = .error fault) : fault = .malformed := by
  cases ref with
  | constant value =>
    simp only [Scalar.Ref.eval] at failed
    split at failed
    · contradiction
    · exact (Except.error.inj failed).symm
  | «local» id =>
    simp only [Scalar.Ref.eval] at failed
    cases found : env id with
    | none => simpa only [found, Except.error.injEq] using failed.symm
    | some value =>
      simp only [found] at failed
      split at failed
      · contradiction
      · exact (Except.error.inj failed).symm

@[spec] theorem scalar_cast_spec (operation : Scalar.Cast) (destination : Scalar.Ty) (operand : Scalar.Ref)
    (args : List Value) (env : Env) (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) (.scalar (.cast operation destination operand)) env)
      (wp (ReadScalar.mk operand (scalarEnv env))
        (fun value => wp (ScalarResult.mk (castValue operation destination value)) post errors) errors) post errors := by
  constructor
  intro state h
  rw [wp_atomic]
  simp only [semantics, Prim.eval_scalar]
  rw [wp_readScalar] at h
  cases read : operand.eval (scalarEnv env) with
  | error fault => simpa only [read, Scalar.Prim.eval, bind, Except.bind] using h
  | ok value =>
    simp only [read] at h
    rw [wp_scalarResult] at h
    have equation : (Scalar.Prim.cast operation destination operand).eval [] (scalarEnv env) =
        castValue operation destination value := by
      simp only [Scalar.Prim.eval, read, bind, Except.bind]
      cases value <;> rfl
    rw [equation]
    cases evaluated : castValue operation destination value <;> simpa only [evaluated] using h

@[spec] theorem scalar_comparison_spec (operation : Scalar.Comparison) (left right : Scalar.Ref)
    (args : List Value) (env : Env) (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) (.scalar (.comparison operation left right)) env)
      (wp (ReadScalar.mk left (scalarEnv env)) (fun a =>
        wp (ReadScalar.mk right (scalarEnv env)) (fun b =>
          wp (ScalarResult.mk (compareValues operation a b)) post errors) errors) errors) post errors := by
  constructor
  intro state h
  rw [wp_atomic]
  simp only [semantics, Prim.eval_scalar]
  rw [wp_readScalar] at h
  cases leftRead : left.eval (scalarEnv env) with
  | error fault => simpa only [leftRead, Scalar.Prim.eval, bind, Except.bind] using h
  | ok a =>
    simp only [leftRead] at h
    rw [wp_readScalar] at h
    cases rightRead : right.eval (scalarEnv env) with
    | error fault =>
      have malformed := Scalar.Ref.only_malformed right _ fault rightRead
      subst fault
      cases a <;> simpa only [leftRead, rightRead, Scalar.Prim.eval, bind, Except.bind] using h
    | ok b =>
      simp only [rightRead] at h
      rw [wp_scalarResult] at h
      have equation : (Scalar.Prim.comparison operation left right).eval [] (scalarEnv env) =
          compareValues operation a b := by
        simp only [Scalar.Prim.eval, leftRead, bind, Except.bind]
        cases a <;> simp only [rightRead] <;> cases b <;> rfl
      rw [equation]
      cases evaluated : compareValues operation a b <;> simpa only [evaluated] using h

@[spec] theorem scalar_arithmetic_spec (operation : Scalar.Arithmetic) (mode : Scalar.Overflow)
    (left right : Scalar.Ref) (args : List Value) (env : Env) (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) (.scalar (.arithmetic operation mode left right)) env)
      (wp (ReadScalar.mk left (scalarEnv env)) (fun a =>
        wp (ReadScalar.mk right (scalarEnv env)) (fun b =>
          wp (ScalarResult.mk (arithmeticValues operation mode a b)) post errors) errors) errors) post errors := by
  constructor
  intro state h
  rw [wp_atomic]
  simp only [semantics, Prim.eval_scalar]
  rw [wp_readScalar] at h
  cases leftRead : left.eval (scalarEnv env) with
  | error fault => simpa only [leftRead, Scalar.Prim.eval, bind, Except.bind] using h
  | ok a =>
    simp only [leftRead] at h
    rw [wp_readScalar] at h
    cases rightRead : right.eval (scalarEnv env) with
    | error fault =>
      have malformed := Scalar.Ref.only_malformed right _ fault rightRead
      subst fault
      cases a <;> simpa only [leftRead, rightRead, Scalar.Prim.eval, bind, Except.bind] using h
    | ok b =>
      simp only [rightRead] at h
      rw [wp_scalarResult] at h
      have equation : (Scalar.Prim.arithmetic operation mode left right).eval [] (scalarEnv env) =
          arithmeticValues operation mode a b := by
        simp only [Scalar.Prim.eval, leftRead, bind, Except.bind]
        cases a <;> simp only [rightRead] <;> cases b <;> rfl
      rw [equation]
      cases evaluated : arithmeticValues operation mode a b <;> simpa only [evaluated] using h

@[spec] theorem scalar_extremum_spec (operation : Bool) (left right : Scalar.Ref)
    (args : List Value) (env : Env) (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) (.scalar (.extremum operation left right)) env)
      (wp (ReadScalar.mk left (scalarEnv env)) (fun a =>
        wp (ReadScalar.mk right (scalarEnv env)) (fun b =>
          wp (ScalarResult.mk (extremumValues operation a b)) post errors) errors) errors) post errors := by
  constructor
  intro state h
  rw [wp_atomic]
  simp only [semantics, Prim.eval_scalar]
  rw [wp_readScalar] at h
  cases leftRead : left.eval (scalarEnv env) with
  | error fault => simpa only [leftRead, Scalar.Prim.eval, bind, Except.bind] using h
  | ok a =>
    simp only [leftRead] at h
    rw [wp_readScalar] at h
    cases rightRead : right.eval (scalarEnv env) with
    | error fault =>
      have malformed := Scalar.Ref.only_malformed right _ fault rightRead
      subst fault
      cases a <;> simpa only [leftRead, rightRead, Scalar.Prim.eval, bind, Except.bind] using h
    | ok b =>
      simp only [rightRead] at h
      rw [wp_scalarResult] at h
      have equation : (Scalar.Prim.extremum operation left right).eval [] (scalarEnv env) =
          extremumValues operation a b := by
        simp only [Scalar.Prim.eval, leftRead, bind, Except.bind]
        cases a <;> simp only [rightRead] <;> cases b <;> rfl
      rw [equation]
      cases evaluated : extremumValues operation a b <;> simpa only [evaluated] using h


end Compiler.ZigAir.MemoryAir.Verify
