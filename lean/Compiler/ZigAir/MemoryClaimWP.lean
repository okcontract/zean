/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryClaims
import Compiler.ZigAir.MemoryPrimitiveWP

namespace Compiler.ZigAir.Memory.Resources
open Std.WP

/-- Effects include exceptional exits. A successful-result-only frame would
silently lose the guarantees needed when a helper fails after a write. -/
def Effects (action : EStateM Fault State Value) (writes : Footprint) (precondition : State → Prop) : Prop :=
  ∀ state, precondition state → match action state with
    | .ok _ after => Modifies writes state after
    | .error _ after => Modifies writes state after

theorem frame_contract (action : EStateM Fault State Value) (writes : Footprint)
    (precondition : State → Prop) (post : Value → State → Prop) (errors : Fault → State → Prop)
    (checked : Triple action precondition post errors)
    (effects : Effects action writes precondition) (claim : Claim)
    (apart : Disjoint claim.footprint writes) :
    Triple action (fun state => precondition state ∧ claim.holds state)
      (fun value state => post value state ∧ claim.holds state)
      (fun fault state => errors fault state ∧ claim.holds state) := by
  constructor
  intro state initial
  have specified := checked.le_wp state initial.1
  have changed := effects state initial.1
  simp only [wp, WP.wpTrans] at specified ⊢
  cases ran : action state with
  | ok value after =>
    rw [ran] at specified changed
    exact ⟨specified, claim.frame initial.2 changed apart⟩
  | error fault after =>
    rw [ran] at specified changed
    exact ⟨specified, claim.frame initial.2 changed apart⟩

end Compiler.ZigAir.Memory.Resources
