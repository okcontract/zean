import Compiler.ZigAir.CapturedScalar

namespace Compiler.Tests.ZigAir.ScalarBooleanNot
open Compiler.ZigAir

example (b : Bool) : (Scalar.Prim.booleanNot (.constant (.bool b))).eval [] (fun _ => none) =
    .ok (.bool (!b)) := rfl
example : (Scalar.Prim.booleanNot (.constant (.int false 8 1))).eval [] (fun _ => none) =
    .error .malformed := rfl
example : CapturedScalar.scalarPrim (.booleanNot (.local 3)) = some (.booleanNot (.local 3)) := rfl

end Compiler.Tests.ZigAir.ScalarBooleanNot
