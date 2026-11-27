/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryBindings

namespace Compiler.ZigAir.MemoryAir.Bindings.Controls
open Memory

private def code (argument slot loopId : Nat) : Control.Code Ty Prim Ref true :=
  .bind argument usize (.argument 0)
    (.bind slot (.pointer true false usize) (.alloc usize)
      (.loop rfl loopId (.repeat rfl loopId)))

example (argument slot loopId : Nat) :
    (arguments (code argument slot loopId))[0]? = some ⟨argument, usize⟩ := rfl
example (argument slot loopId : Nat) :
    (allocations (code argument slot loopId))[0]? = some ⟨slot, .pointer true false usize⟩ := rfl
example (argument slot loopId : Nat) : (loops (code argument slot loopId))[0]? = some loopId := rfl
example (argument slot loopId : Nat) : (allocations (code argument slot loopId))[1]? = none := rfl

/-- Selection includes both branches and does not assume either allocation is
executed, nor that the two static ordinals denote different dynamic lifetimes. -/
example : (allocations (.branch (.constant (.scalar (.bool false)))
    (.bind 7 (.pointer true false usize) (.alloc usize) (.ret (.constant (.scalar .unit))))
    (.bind 11 (.pointer true false usize) (.alloc usize) (.ret (.constant (.scalar .unit)))) :
      Control.Code Ty Prim Ref)).map Binding.register = [7, 11] := rfl

private def difference (dest left right : Nat) (op : Scalar.Arithmetic) : Code :=
  .bind dest usize (.scalar (.arithmetic op .unchecked (.local left) (.local right)))
    (.ret (.local dest))

example (dest left right : Nat) :
    resultOf (difference dest left right .sub) usize (.scalar (.arithmetic .sub .unchecked
      (.local left) (.local right))) = some ⟨dest, usize⟩ := by
  simp [resultOf, primitives, difference, unique]

private def subtraction : Prim := .scalar (.arithmetic .sub .unchecked (.local 8) (.local 2))
example : resultOf (difference 37 8 2 .add) usize subtraction = none := by decide
example : resultOf (difference 37 2 8 .sub) usize subtraction = none := by decide
example : resultOf (difference 37 8 2 .sub) (.scalar .bool) subtraction = none := by decide
example : resultOf (.bind 18 usize subtraction (difference 37 8 2 .sub)) usize subtraction = none := by decide

end Compiler.ZigAir.MemoryAir.Bindings.Controls
