/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Buffer.V1.Generated
import Compiler.Tutorial.Buffer.V2.Generated
import Compiler.ZigAir.MemoryWordArrayTypes

namespace Compiler.Tutorial.Buffer
open Compiler.ZigAir Compiler.ZigAir.Memory Compiler.ZigAir.MemoryAir Memory.WordArray

inductive Version where | v1 | v2

def program : Version → Program
  | .v1 => V1.Generated.fn_replace
  | .v2 => V2.Generated.fn_replace

def size (n : Nat) : Value := .scalar (.int false 64 n)

def arguments (view : View) (index : Nat) (value : BitVec 32) : List Value :=
  [view.buffer, size view.length, size index, number value]

end Compiler.Tutorial.Buffer
