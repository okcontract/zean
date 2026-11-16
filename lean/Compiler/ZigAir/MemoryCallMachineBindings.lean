/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryCallMachine
import Compiler.ZigAir.MemoryBindings

/-! Checked semantic selectors for call-machine invariants. They inspect
ordinary program data, reject ambiguous matches, and never change execution. -/
namespace Compiler.ZigAir.MemoryCallMachine.Bindings
open MemoryAir.Bindings

def memory (code : Code) : List (Binding × MemoryAir.Prim) :=
  (primitives code).filterMap fun (binding, operation) => match operation with
    | .memory primitive => some (binding, primitive)
    | .call .. => none

def argument (code : Code) (index : Nat) : Option Binding :=
  unique ((memory code).filterMap fun (binding, operation) => match operation with
    | .argument actual => if actual = index then some binding else none
    | _ => none)

def allocationOfType (code : Code) (type : Memory.Ty) : Option Binding :=
  unique ((memory code).filterMap fun (binding, operation) => match operation with
    | .alloc actual => if actual = type then some binding else none
    | _ => none)

def castToType (code : Code) (type : Memory.Ty) : Option Binding :=
  unique ((memory code).filterMap fun (binding, operation) => match operation with
    | .pointerCast actual _ => if actual = type then some binding else none
    | _ => none)

def singleLoop (code : Code) : Option Nat := unique (MemoryAir.Bindings.loops code)

/-- Enumerations remain available when a client needs several values of the
same kind. A client must prove its chosen position exists. -/
def arguments (code : Code) : List Binding :=
  (memory code).filterMap fun (binding, operation) => match operation with
    | .argument _ => some binding
    | _ => none

def allocations (code : Code) : List Binding :=
  (memory code).filterMap fun (binding, operation) => match operation with
    | .alloc _ => some binding
    | _ => none

def casts (code : Code) : List Binding :=
  (memory code).filterMap fun (binding, operation) => match operation with
    | .pointerCast .. => some binding
    | _ => none

def sliceLengths (code : Code) : List Binding :=
  (memory code).filterMap fun (binding, operation) => match operation with
    | .sliceLen _ => some binding
    | _ => none

def slices (code : Code) : List Binding :=
  (memory code).filterMap fun (binding, operation) => match operation with
    | .slice .. => some binding
    | _ => none

def calls (code : Code) : List Binding :=
  (primitives code).filterMap fun (binding, operation) => match operation with
    | .call .. => some binding
    | _ => none

end Compiler.ZigAir.MemoryCallMachine.Bindings
