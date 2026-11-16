/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Copy.Helper
import Compiler.ZigAir.MemoryBorrowedWords
import Compiler.ZigAir.MemoryBindings

namespace Compiler.Tutorial.Copy
open Compiler.ZigAir Compiler.ZigAir.Memory Compiler.ZigAir.MemoryAir MemoryAir.Verify
open Memory.WordArray Memory.WordCopy

def size (n : Nat) : Value := .scalar (.int false 64 n)

-- Selection is evaluated from the generated program. Bounds are checked by
-- Lean, so a missing local/loop fails here instead of selecting a default ID.
def lengthBinding : Bindings.Binding := air_binding% (Bindings.argument Generated.fn_copy.body 2).get (by decide)
def targetBinding : Bindings.Binding := air_binding% (Bindings.castToType Generated.fn_copy.body
  (.pointer false false (.pointer true true word))).get (by decide)
def sourceBinding : Bindings.Binding := air_binding% (Bindings.castToType Generated.fn_copy.body
  (.pointer false false (.pointer false true word))).get (by decide)
def indexBinding : Bindings.Binding := air_binding% (Bindings.allocationOfType Generated.fn_copy.body usize).get (by decide)
def copyLoop : Nat := air_binding% (Bindings.unique (Bindings.loops Generated.fn_copy.body)).get (by decide)

def arguments (target source : View) : List Value := [target.buffer, source.readBuffer, size source.length]

/-- The mathematical invariant is a copied prefix, with the original source
preserved. Register bindings identify the live parameters and the mutable
counter in this capture; the verifier itself knows none of these identities. -/
def loopInvariant (initial : State) (target source : View) (items : List (BitVec 32)) : Invariants :=
  fun label env state => label = copyLoop ∧ ∃ index,
    index ≤ items.length ∧
    env lengthBinding.register = some (size source.length) ∧
    targetBinding.Saved initial.nextId env state target.buffer ∧
    sourceBinding.Saved (initial.nextId + 1) env state source.readBuffer ∧
    indexBinding.Saved (initial.nextId + 2) env state (size index) ∧
    state.valid = true ∧ Writable state target ∧ Readable state source ∧
    BorrowedFrame target initial state ∧ Prefix state target items index

def Completed (initial : State) (target source : View) (items : List (BitVec 32))
    (result : Value) (after : State) : Prop :=
  result = .scalar .unit ∧ after.valid = true ∧ Writable after target ∧
  Represents after target items ∧ Represents after source items ∧ HeapFrame target initial after

def Exhausted (initial : State) (target source : View) (items : List (BitVec 32))
    (fault : Fault) (after : State) : Prop :=
  fault = .outOfMemory ∧ after.valid = true ∧ Writable after target ∧
  Represents after source items ∧ HeapFrame target initial after

theorem completed (initial state : State) (target source : View) (items : List (BitVec 32)) (index : Nat)
    (cap : Writable state target) (frame : BorrowedFrame target initial state)
    (original : Represents initial source items) (apart : disjoint source target = true)
    (length : items.length = target.length) (older : target.allocation < initial.nextId)
    (copied : Prefix state target items index) (finished : items.length ≤ index) :
    Completed initial target source items (.scalar .unit) (cleanup initial.nextId state) := by
  have heap := frame.cleanup
  refine ⟨rfl, cleanup_preserves_valid _ _ frame.valid, ?_,
    (copied.cleanup initial.nextId older).complete length finished,
    source_frame initial _ source target items original apart heap, heap⟩
  obtain ⟨extent, cell, found, typed, writable, bound⟩ := cap
  exact ⟨extent, cell, (cleanup_lookup_older state initial.nextId target.allocation older).trans found,
    typed, writable, bound⟩

theorem exhausted (initial state : State) (target source : View) (items : List (BitVec 32))
    (frame : StackFrame initial state) (cap : Writable initial target)
    (original : Represents initial source items) :
    Exhausted initial target source items .outOfMemory (cleanup initial.nextId state) :=
  ⟨rfl, frame.cleanup_valid, writable_heap_eq initial _ target frame.cleanup_heap cap,
    represents_heap_eq initial _ source items frame.cleanup_heap original,
    (HeapFrame.refl target initial).heap_eq frame.cleanup_heap⟩

end Compiler.Tutorial.Copy
