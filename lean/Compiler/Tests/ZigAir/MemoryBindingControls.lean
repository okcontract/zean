/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryBindings

namespace Compiler.Tests.ZigAir.MemoryBindingControls
open Compiler.ZigAir Compiler.ZigAir.Memory MemoryAir
def ending : Code := .ret (.constant (.scalar .unit))
def original : Code := .bind 40 usize (.argument 2) ending
def inserted : Code := .bind 7 usize (.argument 1) (.bind 99 usize (.argument 2) ending)
def ambiguous : Code := .bind 40 usize (.argument 2) (.bind 99 usize (.argument 2) ending)

theorem original_binding : Bindings.argument original 2 = some ⟨40, usize⟩ := rfl
theorem renumbered_binding : Bindings.argument inserted 2 = some ⟨99, usize⟩ := rfl
theorem ambiguous_rejects : Bindings.argument ambiguous 2 = none := rfl
theorem absent_rejects : Bindings.argument inserted 3 = none := rfl

def twoSlots : Code := .bind 10 (.pointer true false usize) (.alloc usize)
  (.bind 11 (.pointer true false usize) (.alloc usize) ending)
theorem ambiguous_storage_rejects : Bindings.allocationOfType twoSlots usize = none := rfl
end Compiler.Tests.ZigAir.MemoryBindingControls
