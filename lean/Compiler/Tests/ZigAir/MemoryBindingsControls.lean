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

end Compiler.ZigAir.MemoryAir.Bindings.Controls
