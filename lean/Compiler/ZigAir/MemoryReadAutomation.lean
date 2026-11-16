/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.Verify.Core
import Compiler.ZigAir.MemoryReadView

/-! Optional rules for initialized readonly views. Contracts describe contents;
the generic verifier still checks every captured instruction and branch. -/
namespace Compiler.ZigAir.Memory

theorem slice_typed (writable : Bool) (child : Ty) (address : Address) (length : Nat) (width : length < addressLimit) :
    (Value.slice (.slice writable child) address length).hasType (.slice writable child) = true := by
  simpa [Value.hasType, Value.type, Value.valid] using width

theorem allocate_slice_fault (state : State) (write : Bool) (child : Ty) (fault : Fault)
    (valid : state.valid = true) (failed : allocate state (.slice write child) = .error fault) :
    fault = .outOfMemory := allocate_fault_of_layout state _ ⟨16, 8⟩ fault valid rfl failed

theorem fresh_slice_store_no_fault (state allocated : State) (writable : Bool) (child : Ty)
    (address : Address) (length : Nat) (pointer : Value) (fault : Fault)
    (width : length < addressLimit)
    (allocation : allocate state (.slice writable child) = .ok (pointer, allocated))
    (failed : store allocated pointer (.slice (.slice writable child) address length) = .error fault) : False := by
  have valid : (Value.slice (.slice writable child) address length).valid = true := by
    simpa [Value.valid] using width
  obtain ⟨after, stored⟩ := fresh_store_total state allocated
    (.slice (.slice writable child) address length) pointer ⟨16, 8⟩ valid rfl (by decide) allocation
  rw [stored] at failed
  contradiction

end Compiler.ZigAir.Memory

namespace Compiler.ZigAir.MemoryAir.Verify
open Memory

macro "air_read_finish" config:Lean.Parser.Tactic.optConfig
    "[" facts:Lean.Parser.Tactic.grindParam,* "]" : tactic => `(tactic|
  air_finish $config:optConfig [StackFrame.store_local,
    → ReadView.Represents.stack,
    ReadView.buffer, ReadView.slice, ReadView.pointer,
    slice_typed, allocate_slice_fault, fresh_slice_store_no_fault,
    load_after_allocate, load_other_after_store, → normalize_unsigned_valid,
    StackFrame.cleanup_heap, $facts,*])

end Compiler.ZigAir.MemoryAir.Verify
