/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryPrimitiveWP

/-! Shared argument-reading rules. Reading references preserves memory and
reports malformed values before entering a callee in either call model. -/
namespace Compiler.ZigAir.MemoryCall
open Memory MemoryAir.Verify Std.WP

def readArguments (arguments : List MemoryAir.Ref) (env : MemoryAir.Env) : EStateM Fault State (List Value) :=
  fun state => match arguments.mapM (fun ref => ref.eval env) with
    | .ok values => .ok values state
    | .error fault => .error fault state

@[spec] theorem readArguments_nil (env : MemoryAir.Env) (post : List Value → State → Prop) (errors : FaultCondition) :
    Triple (readArguments [] env) (post []) post errors := ⟨fun _ h => h⟩

@[spec] theorem readArguments_cons (ref : MemoryAir.Ref) (rest : List MemoryAir.Ref) (env : MemoryAir.Env)
    (post : List Value → State → Prop) (errors : FaultCondition) :
    Triple (readArguments (ref :: rest) env)
      (wp (ReadReference.mk ref env) (fun value =>
        wp (readArguments rest env) (fun values => post (value :: values)) errors) errors) post errors := by
  constructor
  intro state h
  simp only [wp, WP.wpTrans] at h ⊢
  change (match ref.eval env with | .ok value => _ | .error fault => errors fault state) at h
  simp only [readArguments, List.mapM_cons, bind, Except.bind]
  cases evaluated : ref.eval env with
  | error fault => simpa only [evaluated] using h
  | ok value =>
    simp only [evaluated] at h ⊢
    simp only [readArguments] at h
    cases restResult : rest.mapM (fun ref => ref.eval env) with
    | error fault => simpa only [restResult] using h
    | ok values => simpa only [restResult, pure, Except.pure] using h

end Compiler.ZigAir.MemoryCall
