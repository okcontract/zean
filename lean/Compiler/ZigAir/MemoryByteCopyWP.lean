/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryPrimitiveWP
import Compiler.ZigAir.MemoryByteArray

namespace Compiler.ZigAir.MemoryAir.Verify
open Memory Std.WP Lean.Order Control.Verification

/-- This effect exposes the actual heap on both success and partial-copy fault. -/
def copyEffect (target source : Value) : EStateM Fault State Value := fun state =>
  match ByteRange.copy state target source with
  | (.ok (), after) => .ok (.scalar .unit) after
  | (.error fault, after) => .error fault after

@[spec] theorem copyEffect_spec (target source : Value) (post : Postcondition) (errors : FaultCondition) :
    Triple (copyEffect target source)
      (fun state =>
        (⨅ after, ⌜ByteRange.copy state target source = (.ok (), after)⌝ ⇨ post (.scalar .unit) after) ⊓
        (⨅ fault, ⨅ after, ⌜ByteRange.copy state target source = (.error fault, after)⌝ ⇨ errors fault after))
      post errors := by
  constructor
  intro state h
  simp only [meet_prop_eq_and, iInf_prop_eq_forall, himp_prop_eq_imp, ofProp_prop_eq] at h
  cases copied : ByteRange.copy state target source with
  | mk result after =>
    cases result with
    | ok value => cases value; simpa only [wp, WP.wpTrans, copyEffect, copied] using h.1 after copied
    | error fault => simpa only [wp, WP.wpTrans, copyEffect, copied] using h.2 fault after copied

@[spec] theorem copyBytes_spec (target source : Ref) (args : List Value) (env : Env)
    (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) (.copyBytes target source) env)
      (wp (ReadReference.mk target env) (fun target =>
        wp (ReadReference.mk source env) (fun source => wp (copyEffect target source) post errors) errors) errors)
      post errors := by
  constructor
  intro state h
  rw [wp_atomic]
  simp only [semantics, Prim.eval, evalByteTransfer]
  rw [wp_reference] at h
  cases targetRead : target.eval env with
  | error fault => simpa only [targetRead] using h
  | ok destination =>
    simp only [targetRead] at h
    rw [wp_reference] at h
    cases sourceRead : source.eval env with
    | error fault => simpa only [targetRead, sourceRead] using h
    | ok input =>
      simp only [sourceRead] at h
      cases copied : ByteRange.copy state destination input with
      | mk result after =>
        cases result with
        | ok value => cases value; simpa only [wp, WP.wpTrans, copyEffect, targetRead, sourceRead, copied, Except.map] using h
        | error fault => simpa only [wp, WP.wpTrans, copyEffect, targetRead, sourceRead, copied, Except.map] using h

end Compiler.ZigAir.MemoryAir.Verify
