/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryByteCopyWP
import Compiler.ZigAir.MemoryByteCopyContracts
import Compiler.ZigAir.MemoryByteArrayGeometry
import Compiler.ZigAir.MemorySliceProjectionWP
import Compiler.ZigAir.MemorySliceSlotReads
import Compiler.ZigAir.MemoryReadAutomation
import Compiler.ZigAir.MemoryLocalInitialization
import Compiler.ZigAir.MemoryProofSearch

attribute [air_simps] Compiler.ZigAir.MemoryAir.sliceLength Compiler.ZigAir.MemoryAir.slicePointer
  Compiler.ZigAir.Memory.pointerField Compiler.ZigAir.MemoryAir.sliceCast
  Compiler.ZigAir.Memory.ScalarBytes.arrayToSlice

namespace Compiler.ZigAir.Memory
variable {id : Nat}

theorem LoadStep.slice_length (cap : RootWritable state (.slice writable child) id)
    (valid : state.valid = true)
    (loaded : LoadStep state (.pointer (.pointer readWritable readMany (.slice writable child)) ⟨id, 0⟩)
      (.slice (.slice writable child) data length)) :
    LoadStep state (.pointer (.pointer false false usize) ⟨id, 8⟩) (.scalar (.int false 64 length)) :=
  ⟨cap.slice_length valid loaded.equation⟩

grind_pattern LoadStep.slice_length => RootWritable state (.slice writable child) id,
  LoadStep state (.pointer (.pointer readWritable readMany (.slice writable child)) ⟨id, 0⟩)
    (.slice (.slice writable child) data length)

theorem ByteRange.result_valid {source target : Value} (valid : state.valid = true)
    (copied : ByteRange.copy state target source = (result, after)) : after.valid = true := by
  simpa only [copied] using ByteRange.copy_valid state target source valid

theorem RootWritable.usize_zero_store_no_fault (valid : state.valid = true)
    (cap : RootWritable state usize id)
    (failed : store state (.pointer (.pointer true false usize) ⟨id, 0⟩)
      (.scalar (.int false 64 0)) = .error fault) : False :=
  RootWritable.usize_store_no_fault state id _ fault valid cap (MemoryAir.Verify.unsigned_zero_typed 64) failed

end Compiler.ZigAir.Memory

namespace Compiler.ZigAir.MemoryAir.Verify
open Memory

elab "air_byte_prepare" : tactic => Lean.Elab.Tactic.liftMetaTactic fun goal =>
  saturateFacts goal #[``store_preserves_valid, ``RootWritable.allocated, ``RootWritable.stored, ``RootWritable.after_allocate,
    ``RootWritable.older,
    ``StackFrame.initialized_local, ``StackFrame.trans, ``StackFrame.valid,
    ``StackFrame.cleanup_valid, ``StackFrame.cleanup_heap, ``LoadStep.stack, ``LoadStep.stored_other,
    ``LoadStep.slice_length, ``LoadStep.equation,
    ``ByteArray.Region.stack, ``ByteArray.Represents.stack, ``ByteArray.Region.width, ``ByteArray.Region.older,
    ``ByteArray.Region.offset_start] 6

/-- Generate the standard VCs and expose saved slice values before scalar
reasoning. All inference is through the reusable memory laws above. -/
macro "air_byte_vcgen" : tactic => `(tactic| (
  air_vcgen_prepare []
  air_reduce
  all_goals air_byte_prepare
  air_reduce
  all_goals air_byte_prepare
  air_reduce
  all_goals simp (disch := omega) only [usize, ByteArray.byte, addressLimit,
    normalize_unsigned, Int.max_eq_left] at *
  air_reduce
  all_goals try solve | simp_all))

/-- Resolve local counter-store failures while their explicit typing facts are
still available, before arithmetic simplification expands those predicates. -/
elab "air_byte_faults" : tactic => Lean.Elab.Tactic.liftMetaTactic fun goal =>
  saturateFacts goal #[``RootWritable.usize_store_no_fault, ``RootWritable.usize_zero_store_no_fault] 1

/-- Optional proof rules for byte-array contracts. The obligations and the
discharge procedure are independent of function names and instruction IDs. -/
macro "air_byte_finish" config:Lean.Parser.Tactic.optConfig
    "[" facts:Lean.Parser.Tactic.grindParam,* "]" : tactic => `(tactic| (
  all_goals air_byte_faults
  all_goals air_false
  all_goals try simp only [Scalar.Ty.contains, Scalar.Ty.lower, Scalar.Ty.upper] at *
  all_goals air_arithmetic
  air_read_finish $config:optConfig [
    → ByteArray.Region.stack, → ByteArray.Represents.stack,
    → ByteArray.Region.width, → ByteArray.Region.readable,
    → ByteArray.Region.offset_start,
    ByteArray.copy_no_fault, ByteArray.copy_post, → ByteRange.result_valid,
    → RootWritable.allocated, → RootWritable.stored, → RootWritable.after_allocate,
    ByteArray.View.pointer, ByteArray.View.at, usize,
    → normalize_unsigned_valid, Scalar.Ty.contains, Scalar.Ty.lower, Scalar.Ty.upper, addressLimit,
    $facts,*]))

end Compiler.ZigAir.MemoryAir.Verify
