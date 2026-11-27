/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
namespace Compiler.ZigAir

/-- Decide whether an execution returned a particular value. Clients need
    equality only on the observed result, even when faults carry extra data. -/
instance resultIsOk [DecidableEq α] (result : Except ε α) (expected : α) :
    Decidable (result = .ok expected) :=
  match result with
  | .ok value => decidable_of_iff (value = expected) (by simp)
  | .error _ => isFalse (by intro h; cases h)

/-- The corresponding observation for a particular fault needs equality only
    on faults. Neither instance imposes equality on an entire machine state. -/
instance resultIsError [DecidableEq ε] (result : Except ε α) (expected : ε) :
    Decidable (result = .error expected) :=
  match result with
  | .error fault => decidable_of_iff (fault = expected) (by simp)
  | .ok _ => isFalse (by intro h; cases h)

end Compiler.ZigAir
