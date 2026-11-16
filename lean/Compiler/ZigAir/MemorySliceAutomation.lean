/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryInitializedWords
import Compiler.ZigAir.MemoryWordAutomation

namespace Compiler.ZigAir.MemoryAir.Verify
open Memory.WordArray

/-- Normalize pointers returned by slice selection using the operation's checked
equation. No safety assumption or successful operation is invented. -/
elab "air_slice_forward" : tactic => Lean.Elab.Tactic.liftMetaTactic fun goal =>
  forwardFacts goal #[``slice_selected, ``loaded_word]

macro "air_slice_reduce" : tactic => `(tactic| (
  all_goals air_slice_forward
  all_goals air_subst
  all_goals air_slice_forward
  all_goals air_split
  all_goals air_subst
  all_goals try simp only [number] at *
  air_reduce))

/-- Optional discharge rules for initialized writable word slices. The client
supplies its invariant and mathematical postconditions; program structure and
primitive outcomes continue to come from VC generation. -/
macro "air_slice_finish" config:Lean.Parser.Tactic.optConfig
    "[" facts:Lean.Parser.Tactic.grindParam,* "]" : tactic => `(tactic| (
  air_slice_reduce
  air_word_finish $config:optConfig [slice_element, Initialized.read_slice, number,
    → Memory.Value.word_value, write_value_no_fault, scalar_word_typed, usize_successor,
    → Initialized.allocated, → Initialized.store_other, Initialized.store_value,
    BorrowedFrame.store_value, → BorrowedFrame.store_local, $facts,*]))

macro "air_slice_finish" : tactic => `(tactic| air_slice_finish (verbose := false) [])

end Compiler.ZigAir.MemoryAir.Verify
