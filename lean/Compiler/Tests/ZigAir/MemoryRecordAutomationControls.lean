/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.Verify.Records
import Compiler.ZigAir.Verify.Bytes
import Compiler.ZigAir.MemoryByteSubviewAutomation

namespace Compiler.Tests.ZigAir.MemoryRecordAutomationControls
open Compiler.ZigAir Compiler.ZigAir.Memory MemoryAir.Verify

example (state : State) (mark : Nat) (valid : state.valid = true) :
    if (Value.scalar .unit).hasType (.scalar .unit) = true then
      Value.scalar .unit = Value.scalar .unit ∧ (cleanup mark state).valid = true
    else False := by
  air_byte_finish (verbose := false) []

example (state : State) (child : Ty) (address : Address) (value : Value)
    (loaded : LoadStep state (.pointer (.pointer false false child) address) value) :
    LoadStep state (.pointer (.pointer true false child) address) value := by
  air_record_prepare
  assumption

open Memory.ByteArray in
example (state : State) (view : View) (index : Nat) (result : Value)
    (valid : state.valid = true) (cap : Region state view true) (inside : index < view.length)
    (selected : offsetPointer state false (.pointer (.pointer true true byte) view.address) index = .ok result) :
    result = view.pointer true true index := by
  air_byte_subviews
  assumption

open Memory.ByteArray in
example (state : State) (view : View) (count : Nat) (result : Value)
    (valid : state.valid = true) (cap : Region state view true) (inside : count ≤ view.length)
    (selected : makeSlice state (.slice true byte) (.pointer (.pointer true true byte) view.address) count = .ok result) :
    result = .slice (.slice true byte) view.address count := by
  air_byte_subviews
  assumption

end Compiler.Tests.ZigAir.MemoryRecordAutomationControls

open Compiler.ZigAir Compiler.ZigAir.Memory MemoryAir.Verify Memory.ByteArray in
example (state : State) (view : View) (index : Nat) (fault : Fault)
    (valid : state.valid = true) (cap : Region state view true) (inside : index < view.length)
    (failed : offsetPointer state false (.pointer (.pointer true true byte)
      ⟨view.address.allocation, view.address.offset⟩) index = .error fault) : False := by
  air_byte_subviews
  air_byte_reduce

open Compiler.ZigAir Compiler.ZigAir.Memory MemoryAir.Verify Memory.ByteArray in
example (initial before after : State) (target : View) (source : Address) (value : Value)
    (valid : initial.valid = true) (region : Region initial target true)
    (loaded : LoadStep before (.pointer (.pointer false false usize) ⟨initial.nextId, 0⟩) value)
    (copied : ByteRange.copy before (target.slice true) (.pointer (.pointer false true byte) source) = (.ok (), after)) :
    LoadStep after (.pointer (.pointer false false usize) ⟨initial.nextId, 0⟩) value := by
  simp only [View.slice] at copied
  air_byte_prepare
  air_record_prepare
  assumption

open Compiler.ZigAir Compiler.ZigAir.Memory MemoryAir.Verify Memory.ByteArray in
example (view : View) (start count : Nat)
    (bound : (count : Int) ≤ (view.length : Int) - start) :
    count ≤ Nat.sub view.length start := by
  air_arithmetic

open Compiler.ZigAir Compiler.ZigAir.Memory MemoryAir.Verify Memory.ByteArray in
example (state : State) (view : View) (start count : Nat) (result : Value)
    (valid : state.valid = true) (cap : Region state (view.suffix start) true)
    (selected : (do
      let _ ← if count ≤ view.length - start then (Except.ok () : Except Fault Unit) else .error .sourceBounds
      makeSlice state (.slice true byte) (.pointer (.pointer true true byte) (view.at start)) count) = .ok result) :
    result = .slice (.slice true byte) (view.at start) count := by
  air_byte_reduce
  air_byte_subviews
  assumption

open Compiler.ZigAir Compiler.ZigAir.Memory MemoryAir.Verify Memory.ByteArray in
example (view : View) (_same : view.address = view.at 0) : view.at 0 = view.address := by
  air_byte_reduce

open Compiler.ZigAir Compiler.ZigAir.Memory MemoryAir.Verify Memory.ByteArray in
example (view : View) (start count : Nat)
    (bound : (count : Int) ≤ (view.length : Int) - start) :
    count ≤ (view.suffix start).length := by
  air_arithmetic

open Compiler.ZigAir Compiler.ZigAir.Memory MemoryAir.Verify Memory.ByteArray in
example (state : State) (view : View) (start count : Nat) (result : Value)
    (valid : state.valid = true) (cap : Region state (view.suffix start) true)
    (bound : (count : Int) ≤ (view.length : Int) - start)
    (selected : makeSlice state (.slice true byte) (.pointer (.pointer true true byte) (view.at start)) count = .ok result) :
    result = .slice (.slice true byte) (view.at start) count := by
  air_byte_reduce
  air_byte_subviews
  assumption
