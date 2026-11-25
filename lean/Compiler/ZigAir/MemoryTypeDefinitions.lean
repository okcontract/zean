/-
// Copyright (C) 2026 OKcontract Pte. Ltd.
// SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.Scalar
import Compiler.ZigAir.Target

namespace Compiler.ZigAir.Memory

def addressLimit : Nat := 2 ^ 64

theorem addressLimit_target : addressLimit = 2 ^ Target.pointerBits := rfl

structure Layout where
  bytes : Nat
  alignment : Nat
  deriving DecidableEq, Repr

inductive ErrorValueKind where
  | tag
  | result
  deriving DecidableEq, Repr

mutual
/-- The closed field vocabulary of native Expression descriptors and their
representative-list headers. Pointer and record-slice targets retain their
captured nominal identity; a checked view resolves a complete record's fields.
It is immutable type metadata, not another allocation/value representation. -/
inductive Field where
  | scalar (type : Scalar.Ty)
  | pointer (writable : Bool) (identity : String) (layout : Layout)
  | slice (writable : Bool) (child : Scalar.Ty)
  | recordSlice (writable : Bool) (identity : String) (layout : Layout)
  /-- A complete immutable declared subobject. Direct whole-object heap loads/stores remain unsupported. -/
  | object (child : Ty)
  deriving Repr

inductive Ty where
  | scalar (type : Scalar.Ty)
  /-- By-value concrete error sets and error unions with void payload.
  No ABI storage or numeric discriminant is supplied by this type. -/
  | errorValue (kind : ErrorValueKind) (allowed : List String)
  /-- Atomic typed optional scalar. Its captured extent gives no rule for
  projecting payload/discriminator bytes; only admitted children have layouts. -/
  | optionalScalar (child : Scalar.Ty)
  /-- A captured optional slice/record. The complete child declaration and
  optional extent are metadata; no payload/discriminator byte view is admitted. -/
  | optionalObject (child : Ty) (layout : Layout)
  | pointer (writable many : Bool) (child : Ty)
  | slice (writable : Bool) (child : Ty)
  | array (length : Nat) (child : Ty)
  /-- Nominal allocation metadata only. Field loads/stores are unsupported;
  clients must bind the identity and extent to a captured native layout. -/
  | record (identity : String) (layout : Layout)
  /-- A captured struct with complete scalar/pointer/slice fields in increasing
  byte-offset order. Field objects may be nested; direct whole-struct heap reads stay unsupported.
  Complete subobjects refine typed leaves in the existing heap, not a second object store. -/
  | aggregate (identity : String) (layout : Layout) (fields : List (Nat × Field))
  deriving Repr
end


end Compiler.ZigAir.Memory
