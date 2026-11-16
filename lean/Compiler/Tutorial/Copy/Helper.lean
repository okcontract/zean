/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Copy.Generated
import Compiler.ZigAir.Verify.Words

/-! A contract for the inline helper, parameterized by its compiler-assigned
registers. The contract can be composed with any continuation. -/
namespace Compiler.Tutorial.Copy
open Compiler.ZigAir Compiler.ZigAir.Memory Compiler.ZigAir.MemoryAir MemoryAir.Verify
open Memory.WordArray Control.Verification Std.WP
set_option maxRecDepth 4096
set_option maxHeartbeats 1000000

def wordInstructions (readId writeId destinationId sourceId : Nat) : List (Instruction Ty Prim) :=
  [⟨readId, word, .load (.local sourceId)⟩,
   ⟨writeId, .scalar .unit, .store (.local destinationId) (.local readId)⟩]

theorem word_contract (args : List Value) (env : Env) (readId writeId destinationId sourceId : Nat)
    (state : State) (target : View) (index : Nat) (source : Address) (value : BitVec 32)
    (separate : readId ≠ destinationId)
    (destinationRef : env destinationId = some (target.pointer index))
    (sourceRef : env sourceId = some (.pointer (.pointer false false word) source))
    (valid : state.valid = true) (cap : Writable state target) (inside : index < target.length)
    (initialized : load state (.pointer (.pointer false false word) source) = .ok (number value)) :
    Triple (Fragment.mk (sem := semantics) (args := args)
      (wordInstructions readId writeId destinationId sourceId) env)
      (fun before => before = state)
      (fun locals after => locals = (env.set readId (number value)).set writeId (.scalar .unit) ∧
        store state (target.pointer index) (number value) = .ok after ∧ after.valid = true)
      (fun _ _ => False) := by
  unfold wordInstructions
  air_vcgen
  air_word_finish

/-- A caller can reuse the proved memory effect before any continuation;
its proof need not unfold or reverify the helper's load and store. -/
theorem word_then_contract (args : List Value) (env : Env) (readId writeId destinationId sourceId : Nat)
    (state : State) (target : View) (index : Nat) (source : Address) (value : BitVec 32)
    (separate : readId ≠ destinationId)
    (destinationRef : env destinationId = some (target.pointer index))
    (sourceRef : env sourceId = some (.pointer (.pointer false false word) source))
    (valid : state.valid = true) (cap : Writable state target) (inside : index < target.length)
    (initialized : load state (.pointer (.pointer false false word) source) = .ok (number value))
    (invariants : Control.Verification.Invariants Value State)
    (next : Control.Code Ty Prim Ref true) (post : Post Value State)
    (continuation : ∀ locals, Triple (Task.code next locals : Task semantics args invariants)
      (fun after => locals = (env.set readId (number value)).set writeId (.scalar .unit) ∧
        store state (target.pointer index) (number value) = .ok after ∧ after.valid = true)
      post (fun _ _ => False)) :
    Triple (Task.code (prependCode (wordInstructions readId writeId destinationId sourceId) next) env :
      Task semantics args invariants) (fun before => before = state) post (fun _ _ => False) :=
  prefix_contract semantics args invariants _ next env _ _ post _
    (word_contract args env readId writeId destinationId sourceId state target index source value
      separate destinationRef sourceRef valid cap inside initialized) continuation

/-- The separately exported helper is checked against the same memory effect.
The source may alias the destination because its read precedes the write. -/
theorem copy_word_contract (state : State) (target : View) (index : Nat) (source : Address) (value : BitVec 32)
    (valid : state.valid = true) (cap : Writable state target) (inside : index < target.length)
    (initialized : load state (.pointer (.pointer false false word) source) = .ok (number value)) :
    Triple (Verify.Invocation.mk Generated.fn_copy_word
      [target.pointer index, .pointer (.pointer false false word) source] (fun _ _ _ => False))
      (fun before => before = state)
      (fun result after => result = .scalar .unit ∧
        store state (target.pointer index) (number value) = .ok after ∧ after.valid = true)
      (fun _ _ => False) := by
  unfold Generated.fn_copy_word
  air_vcgen
  air_word_finish [store_keeps_counters]

end Compiler.Tutorial.Copy
