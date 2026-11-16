/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import ByteScan.Generated
import Compiler.ZigAir.Verify.Machine
import Compiler.ZigAir.Verify.Bytes

namespace ByteScan
open Compiler.ZigAir Compiler.ZigAir.Memory MemoryCallMachine Std.WP Lean.Order
open MemoryAir.Verify
set_option maxRecDepth 8192
set_option maxHeartbeats 4000000

def byte : Ty := .scalar (.int false 8)
def size (value : Int) : Value := .scalar (.int false 64 value)
def byteView (address : Address) (length : Nat) : ReadView :=
  ⟨byte, ⟨1, 1⟩, rfl, by decide, address, length⟩
def arguments (address : Address) (length : Nat) : List Value :=
  [(byteView address length).buffer, size length]

theorem nonzero_checked (state : State) (value : Int) (valid : state.valid = true)
    (low : 0 ≤ value) (high : value < 256) :
    Triple (invoke Generated.functions Generated.FunctionId.fn_nonzero [.scalar (.int false 8 value)])
      (fun before => before = state)
      (fun result after => result = .scalar (.bool (decide (value ≠ 0))) ∧
        result.hasType (.scalar .bool) = true ∧ after = state) (fun _ _ => False) := by
  have typed := unsigned_typed_int 8 value low high
  dsimp only [Generated.functions, Generated.FunctionId.fn_nonzero, Generated.fn_nonzero]
  machine_vcgen
  machine_normalize
  air_reduce
  air_finish (verbose := false) [Value.valid, Scalar.Value.valid,
    Scalar.Ty.contains, Scalar.Ty.lower, Scalar.Ty.upper]

def nonzeroContract : MemoryCallMachine.Contract Generated.functions Generated.FunctionId.fn_nonzero where
  precondition := fun args state => state.valid = true ∧ ∃ value,
    args = [value] ∧ value.hasType byte = true
  postcondition := fun _ before result after => result.hasType (.scalar .bool) = true ∧ after = before
  exceptions := fun _ _ _ _ => False
  checked := by
    intro args state pre fuel
    obtain ⟨valid, value, rfl, typed⟩ := pre
    obtain ⟨value, rfl, low, high⟩ := value.unsigned_value 8 typed
    have observed := sound _ _ _ _ (nonzero_checked state value valid low high) state rfl fuel
    exact Observes.mono _ _ _ _ (fun _ _ h => h.2) (fun _ _ h => h) _ observed

theorem nonzero_spec (args : List Value) (post : MemoryCallMachine.Postcondition) (errors : Exceptions) :
    Triple (invoke Generated.functions Generated.FunctionId.fn_nonzero args)
      (fun state => ⌜nonzeroContract.precondition args state⌝ ⊓
        ((⨅ value, ⨅ after, ⌜nonzeroContract.postcondition args state value after⌝ ⇨ post value after) ⊓
        (⨅ fault, ⨅ after, ⌜nonzeroContract.exceptions args state fault after⌝ ⇨ errors fault after))) post errors :=
  nonzeroContract.apply args post errors

def lengthBinding : MemoryAir.Bindings.Binding := air_binding%
  (Bindings.argument Generated.fn_all_nonzero.body 1).get (by decide)
def pointerBinding : MemoryAir.Bindings.Binding := air_binding%
  (Bindings.castToType Generated.fn_all_nonzero.body (.pointer false false (.pointer false true byte))).get (by decide)
def indexBinding : MemoryAir.Bindings.Binding := air_binding%
  (Bindings.allocationOfType Generated.fn_all_nonzero.body usize).get (by decide)
def loopLabel : Nat := air_binding% (Bindings.singleLoop Generated.fn_all_nonzero.body).get (by decide)

def invariant (initial : State) (address : Address) (length : Nat) : VC.Invariants := fun label env state =>
  label = loopLabel ∧
  env lengthBinding.register = some (size length) ∧
  pointerBinding.Saved initial.nextId env state (byteView address length).buffer ∧
  StackFrame initial state ∧ ∃ index : Int,
    0 ≤ index ∧ index ≤ length ∧ indexBinding.Saved (initial.nextId + 1) env state (size index)

def Completed (initial : State) (result : Value) (after : State) : Prop :=
  result.hasType (.scalar .bool) = true ∧ after.valid = true ∧ after.heap = initial.heap
def Exhausted (initial : State) (fault : Fault) (after : State) : Prop :=
  fault = .outOfMemory ∧ after.valid = true ∧ after.heap = initial.heap

attribute [local irreducible] Generated.fn_nonzero

theorem checked (initial : State) (address : Address) (length : Nat) (values : Nat → Value)
    (valid : initial.valid = true) (width : length < addressLimit)
    (readable : ReadView.Represents initial (byteView address length) values) :
    Triple (verify Generated.functions Generated.FunctionId.fn_all_nonzero (arguments address length)
      (invariant initial address length))
      (fun before => before = initial) (Completed initial) (Exhausted initial) := by
  have initialFrame := StackFrame.refl initial valid
  have helperRule := nonzero_spec
  dsimp only [Generated.functions, Generated.FunctionId.fn_all_nonzero, Generated.fn_all_nonzero,
    Generated.FunctionId.fn_nonzero, arguments] at helperRule ⊢
  machine_vcgen [helperRule]
  all_goals clear helperRule
  machine_normalize [invariant, nonzeroContract, lengthBinding, pointerBinding, indexBinding,
    loopLabel, MemoryAir.Bindings.checked, MemoryAir.Bindings.Binding.Saved, size, byteView, byte, usize]
  all_goals air_arithmetic
  all_goals air_byte_prepare
  air_reduce
  all_goals air_byte_prepare
  all_goals air_byte_reads
  air_reduce
  all_goals air_nat_equalities
  all_goals air_witnesses
  air_byte_finish (verbose := false) (gen := 20) (ematch := 10)
    [Completed, Exhausted, ReadView.Represents.element, ReadView.Represents.read,
      ReadView.Represents.typed, RootWritable.usize_store_no_fault, allocate_usize_fault,
      StackFrame.valid, byteView, size, byte, Int.toNat_of_nonneg,
      Value.hasType, Value.type, Value.valid, Scalar.Value.type, Scalar.Value.valid]

theorem safe (initial : State) (address : Address) (length : Nat) (values : Nat → Value)
    (valid : initial.valid = true) (width : length < addressLimit)
    (readable : ReadView.Represents initial (byteView address length) values) :
    Safe Generated.functions (start Generated.functions Generated.FunctionId.fn_all_nonzero
      (arguments address length) initial) :=
  safe_of_spec _ _ _ _ (checked initial address length values valid width readable) initial rfl
    (fun _ _ h => h.1)

end ByteScan
