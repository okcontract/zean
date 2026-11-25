/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.Memory

namespace Compiler.ZigAir.Memory

def testError (nonError : Bool) : Value → Except Fault Value
  | .errorValue .result _ name => .ok (.scalar (.bool (name.isSome != nonError)))
  | _ => .error .malformed

/-- The admitted error union has a void payload. Extracting the absent
component takes the same illegal-behavior path as other unchecked AIR. -/
def unwrapError (payload : Bool) : Value → Except Fault Value
  | .errorValue .result _ none =>
    if payload then .ok (.scalar .unit) else .error (.scalar .illegalBehavior)
  | .errorValue .result allowed (some name) =>
    if payload then .error (.scalar .illegalBehavior) else .ok (.errorValue .tag allowed (some name))
  | _ => .error .malformed

def wrapError (allowed : List String) : Value → Except Fault Value
  | .scalar .unit => .ok (.errorValue .result allowed none)
  | .errorValue .tag source (some name) =>
    if allowed.contains name && source.all allowed.contains then
      .ok (.errorValue .result allowed (some name))
    else .error .malformed
  | _ => .error .malformed

end Compiler.ZigAir.Memory
