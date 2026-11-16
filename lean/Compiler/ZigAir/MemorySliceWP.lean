/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryPrimitiveWP
import Compiler.ZigAir.MemorySliceLaws

namespace Compiler.ZigAir.MemoryAir
open Memory

namespace Verify
open Std.WP Lean.Order Control.Verification

@[spec] theorem slice_length_spec (view : Ref) (args : List Value) (env : Env)
    (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) (.sliceLen view) env)
      (fun state => (⨅ value, ⌜(view.eval env >>= sliceLength) = .ok value⌝ ⇨ post value state) ⊓
        (⨅ fault, ⌜(view.eval env >>= sliceLength) = .error fault⌝ ⇨ errors fault state)) post errors :=
  readonly_spec (.sliceLen view) args env (fun _ => view.eval env >>= sliceLength)
    (Prim.eval_slice_length view args env) post errors

@[spec] theorem slice_element_spec (view index : Ref) (args : List Value) (env : Env)
    (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) (.sliceElementPointer view index) env)
      (fun state =>
        (⨅ value, ⌜(do sliceElementPointer state (← view.eval env) (← index.natural env)) = .ok value⌝ ⇨ post value state) ⊓
        (⨅ fault, ⌜(do sliceElementPointer state (← view.eval env) (← index.natural env)) = .error fault⌝ ⇨ errors fault state)) post errors :=
  readonly_spec (.sliceElementPointer view index) args env
    (fun state => do sliceElementPointer state (← view.eval env) (← index.natural env))
    (Prim.eval_slice_element view index args env) post errors

end Verify
end Compiler.ZigAir.MemoryAir
