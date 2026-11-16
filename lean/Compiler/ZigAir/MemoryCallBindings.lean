/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryBindings
import Compiler.ZigAir.MemoryCall

namespace Compiler.ZigAir.MemoryCall.Bindings
open MemoryAir

def memory (code : Control.Code Memory.Ty MemoryCall.Prim Ref loops) : List (MemoryAir.Bindings.Binding × MemoryAir.Prim) :=
  (MemoryAir.Bindings.primitives code).filterMap fun (binding, operation) => match operation with
    | .memory primitive => some (binding, primitive)
    | .call .. => none

def arguments (code : Control.Code Memory.Ty MemoryCall.Prim Ref loops) : List MemoryAir.Bindings.Binding :=
  (memory code).filterMap fun (binding, operation) => match operation with
    | .argument _ => some binding
    | _ => none

def allocations (code : Control.Code Memory.Ty MemoryCall.Prim Ref loops) : List MemoryAir.Bindings.Binding :=
  (memory code).filterMap fun (binding, operation) => match operation with
    | .alloc _ => some binding
    | _ => none

def casts (code : Control.Code Memory.Ty MemoryCall.Prim Ref loops) : List MemoryAir.Bindings.Binding :=
  (memory code).filterMap fun (binding, operation) => match operation with
    | .pointerCast .. => some binding
    | _ => none

def sliceLengths (code : Control.Code Memory.Ty MemoryCall.Prim Ref loops) : List MemoryAir.Bindings.Binding :=
  (memory code).filterMap fun (binding, operation) => match operation with
    | .sliceLen _ => some binding
    | _ => none

def slices (code : Control.Code Memory.Ty MemoryCall.Prim Ref loops) : List MemoryAir.Bindings.Binding :=
  (memory code).filterMap fun (binding, operation) => match operation with
    | .slice .. => some binding
    | _ => none

def calls (code : Control.Code Memory.Ty MemoryCall.Prim Ref loops) : List MemoryAir.Bindings.Binding :=
  (MemoryAir.Bindings.primitives code).filterMap fun (binding, operation) => match operation with
    | .call .. => some binding
    | _ => none

end Compiler.ZigAir.MemoryCall.Bindings
