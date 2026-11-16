/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryAutomation
import Compiler.ZigAir.MemoryBorrowedWords

/-! Optional array and frame facts for word-buffer verification. These rules
describe memory operations independently of any program or loop invariant. -/
attribute [air_simps] Compiler.ZigAir.Memory.WordArray.View.buffer
  Compiler.ZigAir.Memory.WordArray.View.pointer Compiler.ZigAir.Memory.WordArray.number_valid
  Compiler.ZigAir.Memory.WordArray.number_typed

namespace Compiler.ZigAir.MemoryAir.Verify
open Memory Memory.WordArray Memory.WordCopy

macro "air_word_finish" config:Lean.Parser.Tactic.optConfig
    "[" facts:Lean.Parser.Tactic.grindParam,* "]" : tactic => `(tactic|
  air_finish $config:optConfig [WordArray.number_valid, WordArray.number_typed,
    → WordArray.writable_allocate, → WordArray.writable_store,
    WordArray.write_no_fault, → WordArray.view_width,
    WordArray.View.buffer, WordArray.View.pointer, WordArray.View.address, → WordArray.view_older,
    usize, View.readBuffer, readPointer,
    BorrowedFrame.stack, Prefix.zero, Represents.read, → normalize_unsigned_valid,
    → prefix_after_store, Scalar.Ty.contains, Scalar.Ty.lower, Scalar.Ty.upper, addressLimit,
    → RootWritable.allocated, → RootWritable.stored, → RootWritable.after_allocate,
    RootWritable.usize_store_no_fault, allocate_usize_fault,
    → Readable.allocated, → Readable.stored,
    → BorrowedFrame.source, load_after_allocate, load_other_after_store, $facts,*])

macro "air_word_finish" : tactic => `(tactic| air_word_finish (verbose := false) [])

end Compiler.ZigAir.MemoryAir.Verify
