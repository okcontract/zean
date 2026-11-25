/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.Memory

namespace Compiler.ZigAir.Memory

def testError (nonError : Bool) : Value → Except Fault Value
  | .errorValue .result _ name => .ok (.scalar (.bool (name.isSome != nonError)))
  | .errorScalar _ _ (.inl _) => .ok (.scalar (.bool (!nonError)))
  | .errorScalar _ _ (.inr _) => .ok (.scalar (.bool nonError))
  | _ => .error .malformed

/-- Extracting the absent component faults for either kind of error union. -/
def unwrapError (payload : Bool) : Value → Except Fault Value
  | .errorValue .result _ none =>
    if payload then .ok (.scalar .unit) else .error (.scalar .illegalBehavior)
  | .errorValue .result allowed (some name) =>
    if payload then .error (.scalar .illegalBehavior) else .ok (.errorValue .tag allowed (some name))
  | .errorScalar _ allowed (.inl name) =>
    if payload then .error (.scalar .illegalBehavior) else .ok (.errorValue .tag allowed (some name))
  | .errorScalar _ _ (.inr value) =>
    if payload then .ok (.scalar value) else .error (.scalar .illegalBehavior)
  | _ => .error .malformed

def wrapError (allowed : List String) : Value → Except Fault Value
  | .scalar .unit => .ok (.errorValue .result allowed none)
  | .errorValue .tag source (some name) =>
    if allowed.contains name && source.all allowed.contains then
      .ok (.errorValue .result allowed (some name))
    else .error .malformed
  | _ => .error .malformed

def wrapScalarError (child : Scalar.Ty) (allowed : List String) : Value → Except Fault Value
  | .scalar value =>
    if value.hasType child then .ok (.errorScalar child allowed (.inr value)) else .error .malformed
  | .errorValue .tag source (some name) =>
    if allowed.contains name && source.all allowed.contains then
      .ok (.errorScalar child allowed (.inl name))
    else .error .malformed
  | _ => .error .malformed

end Compiler.ZigAir.Memory
