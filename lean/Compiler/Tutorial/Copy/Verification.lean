/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Copy.Contracts
import Compiler.ZigAir.Verify.Words

namespace Compiler.Tutorial.Copy
open Compiler.ZigAir Compiler.ZigAir.Memory Compiler.ZigAir.MemoryAir MemoryAir.Verify
open Memory.WordArray Memory.WordCopy Control.Verification Std.WP
set_option maxRecDepth 4096
set_option maxHeartbeats 4000000

theorem copy_contract (initial : State) (target source : View) (items : List (BitVec 32))
    (valid : initial.valid = true) (writable : Writable initial target) (readable : Readable initial source)
    (original : Represents initial source items) (length : source.length = target.length)
    (apart : disjoint source target = true) :
    Triple (Verify.Invocation.mk Generated.fn_copy (arguments target source)
      (loopInvariant initial target source items))
      (fun before => before = initial) (Completed initial target source items)
      (Exhausted initial target source items) := by
  have initialFrame := StackFrame.refl initial valid
  have targetBound := view_width initial target valid writable
  have targetOlder := view_older initial target valid writable
  have sourceOlder := readable.older valid
  have itemsLength := original.1
  dsimp only [Generated.fn_copy, arguments, size]
  air_vcgen [loopInvariant, size, lengthBinding, targetBinding, sourceBinding, indexBinding,
    copyLoop, Bindings.checked, Bindings.Binding.Saved, usize, View.readBuffer]
  air_word_finish (verbose := false) (gen := 20) (ematch := 10) (instances := 3000) [exhausted, completed]

end Compiler.Tutorial.Copy
