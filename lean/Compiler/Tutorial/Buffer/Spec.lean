/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryWordCallFrame

/-! Handwritten contracts. The logical buffer may be a subview of a larger
allocation. Its length is a caller obligation, not evidence of live storage. -/
namespace Compiler.Tutorial.Buffer.Spec
open Compiler.ZigAir Compiler.ZigAir.Memory Compiler.ZigAir.Memory.WordArray

def contents (items : List (BitVec 32)) (index : Nat) (value : BitVec 32) : List (BitVec 32) :=
  items.set index value

/-- The three allowed outcomes include modeled stack exhaustion. A successful
write changes exactly one caller word; all other outcomes retain the whole heap. -/
inductive Effect (before : State) (view : View) (index : Nat) (value : BitVec 32) :
    Except Fault Value → State → Prop where
  | exhausted (after : State) (heap : after.heap = before.heap) :
      Effect before view index value (.error .outOfMemory) after
  | rejected (after : State) (outside : view.length ≤ index) (heap : after.heap = before.heap) :
      Effect before view index value (.ok (.scalar (.bool false))) after
  | replaced (after direct : State) (inside : index < view.length)
      (stored : store before (view.pointer index) (number value) = .ok direct)
      (heap : after.heap = direct.heap) :
      Effect before view index value (.ok (.scalar (.bool true))) after

structure SafeResult (before : State) (view : View) (index : Nat) (value : BitVec 32)
    (result : Except Fault Value) (after : State) : Prop where
  valid : after.valid = true
  writable : Writable after view
  frame : HeapFrame view before after
  effect : Effect before view index value result after

end Compiler.Tutorial.Buffer.Spec
