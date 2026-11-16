/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.Verify.Bytes

namespace Compiler.Tests.ZigAir.MemoryByteAutomationControls
open Compiler.ZigAir Compiler.ZigAir.Memory MemoryAir.Verify Memory.ByteArray

/-- Forward rules can expose a pointer alias in both directions. These
definitional identities must not form a contextual rewrite cycle. -/
theorem pointer_aliases_do_not_cycle (state : State) (view : View) (index : Nat) (value : Value)
    (_forward : view.pointer true false index =
      .pointer (.pointer true false byte) ⟨view.address.allocation, view.address.offset + index⟩)
    (_backward : (.pointer (.pointer true false byte)
      ⟨view.address.allocation, view.address.offset + index⟩ : Value) = view.pointer true false index)
    (loaded : load state (view.pointer true false index) = .ok value) :
    load state (.pointer (.pointer true false byte)
      ⟨view.address.allocation, view.address.offset + index⟩) = .ok value := by
  air_simp
  exact loaded

theorem arithmetic_counter (index limit : Nat) (inside : index < limit) : index + 1 ≤ limit := by
  air_separate => air_arithmetic

example (_index : Nat) : True := by
  fail_if_success have impossible : _index < _index := by air_separate => air_arithmetic
  trivial

theorem counter_store (state : State) (slot : Nat) (value : Value) (fault : Fault)
    (valid : state.valid = true) (cap : RootWritable state (.scalar (.int false 64)) slot)
    (typed : value.hasType (.scalar (.int false 64)) = true)
    (failed : store state (.pointer (.pointer true false (.scalar (.int false 64))) ⟨slot, 0⟩) value = .error fault) :
    False := by
  air_byte_faults
  air_false

theorem zero_counter_store (state : State) (slot : Nat) (fault : Fault)
    (valid : state.valid = true) (cap : RootWritable state usize slot)
    (failed : store state (.pointer (.pointer true false usize) ⟨slot, 0⟩)
      (.scalar (.int false 64 0)) = .error fault) : False := by
  air_byte_faults
  air_false

theorem equal_length_read (state : State) (view : View) (contents : Nat → BitVec 8)
    (length index : Nat) (represented : Represents state view contents)
    (same : view.length = length) (width : length < addressLimit) (inside : index < length) :
    sliceElementPointer state (.slice (.slice false byte) view.address length) index =
      .ok (view.pointer false false index) ∧
    load state (view.pointer false false index) = .ok (number (contents index)) := by
  exact represented.select_length same width inside

theorem reached_slice_read (state : State) (view : View) (contents : Nat → BitVec 8)
    (length index : Nat) (outcome : Except Fault Value)
    (represented : Represents state view contents)
    (same : view.length = length) (width : length < addressLimit) (inside : index < length)
    (observed : sliceElementPointer state (.slice (.slice false byte) view.address length) index = outcome) :
    outcome = .ok (view.pointer false false index) := by
  air_byte_reads
  assumption

theorem successful_read_type (state : State) (pointer result : Value)
    (typed : pointer.hasType (.pointer false false byte) = true)
    (loaded : load state pointer = .ok result) : result.hasType byte = true := by
  air_byte_reads
  assumption

theorem successful_byte_pointer (state : State) (address : Address) (length index : Nat) (result : Value)
    (selected : sliceElementPointer state (.slice (.slice false byte) address length) index = .ok result) :
    result = .pointer (.pointer false false byte) ⟨address.allocation, address.offset + index⟩ := by
  air_byte_reads
  assumption

/-- Two same-typed counters must be distinguished by their environment binding,
not by whichever load equation occurs first in the local context. -/
theorem distinct_counters (state : State) (env : MemoryAir.Env) (first second : Nat)
    (a b : Int)
    (_firstRead : load state (.pointer (.pointer true false usize) ⟨first, 0⟩) = .ok (.scalar (.int false 64 a)))
    (secondRead : load state (.pointer (.pointer true false usize) ⟨second, 0⟩) = .ok (.scalar (.int false 64 b)))
    (bound : env 7 = some (.pointer (.pointer true false usize) ⟨second, 0⟩)) :
    ∃ (index : Int) (slot : Nat), env 7 = some (.pointer (.pointer true false usize) ⟨slot, 0⟩) ∧
      load state (.pointer (.pointer true false usize) ⟨slot, 0⟩) = .ok (.scalar (.int false 64 index)) ∧ index = b := by
  air_witnesses
  all_goals rfl

/-- Saved identities can be expressed through intermediate allocation counters.
Witness inference must use their proved equalities before matching a read. -/
theorem counter_identity (state : State) (initial middle slot : Nat) (value : Int)
    (first : middle = initial + 1) (second : slot = middle + 1)
    (loaded : load state (.pointer (.pointer true false usize) ⟨slot, 0⟩) = .ok (.scalar (.int false 64 value))) :
    ∃ index : Int, load state (.pointer (.pointer true false usize) ⟨initial + 2, 0⟩) =
      .ok (.scalar (.int false 64 index)) ∧ index = value := by
  air_nat_equalities
  air_witnesses
  all_goals rfl

/-- Simplifying a known read under an existential can leave only its payload
equality. The equality must still determine the counter witness. -/
theorem simplified_read (value : Int) (nonnegative : 0 ≤ value) :
    ∃ index : Int, 0 ≤ index ∧ value = index := by
  air_witnesses
  assumption

theorem checked_increment (index : Int) (result : Scalar.Value)
    (evaluated : (if (Scalar.Ty.int false 64).contains (index + 1) then
      Except.ok (Scalar.Value.int false 64 (index + 1)) else Except.error Scalar.Fault.illegalBehavior) = .ok result) :
    result = .int false 64 (index + 1) := by
  air_reduce

/-- Bounds on a containing buffer also bound a reached length update. Scalar
type bounds must reduce before the arithmetic solver sees the failure branch. -/
theorem bounded_length_add (used count capacity : Nat) (fault : Scalar.Fault)
    (fits : used + count ≤ capacity) (width : capacity < 2 ^ 32)
    (failed : (if (Scalar.Ty.int false 32).contains ((used : Int) + count) then
      Except.ok (Scalar.Value.int false 32 ((used : Int) + count))
      else Except.error Scalar.Fault.illegalBehavior) = .error fault) : False := by
  air_byte_finish (verbose := false) []

/-- VC generation may hide branch evidence from ordinary tactic enumeration.
Such evidence still determines the result of a successful bounds check. -/
theorem hidden_check_result (condition : Prop) [Decidable condition] (result : Value)
    (selected : (do
      let _ ← if condition then (Except.ok () : Except Fault Unit) else .error .sourceBounds
      pure (Value.scalar .unit)) = .ok result) : result = .scalar .unit := by
  run_tac
    let some fact := (← Lean.getLCtx).findFromUserName? `selected
      | throwError "missing control premise"
    (← Lean.Elab.Tactic.getMainGoal).setFVarKind fact.fvarId .implDetail
  air_byte_reduce

theorem dependent_check_result (condition : Prop) [Decidable condition] (result : Value)
    (selected : (do
      let _ ← if condition then (Except.ok () : Except Fault Unit) else .error .sourceBounds
      pure (Value.scalar .unit)) = .ok result) : result = .scalar .unit := by
  let _retained := selected
  air_byte_reduce

theorem checked_unit_type (condition : Prop) [Decidable condition] (result : Value)
    (selected : (match if condition then (Except.ok () : Except Fault Unit) else .error .sourceBounds with
      | .error fault => Except.error fault
      | .ok _ => Except.ok (Value.scalar .unit)) = .ok result)
    (malformed : result.hasType (.scalar .unit) = false) : False := by
  air_byte_finish (verbose := false) []

/-- Updating a newer counter preserves an older counter's read. Their lifetime
bound is sufficient; callers need not restate every pairwise disequality. -/
theorem counter_frame (before after : State) (older newer : Nat) (a b : Int)
    (separate : older + 1 ≤ newer)
    (loaded : LoadStep before (.pointer (.pointer true false usize) ⟨older, 0⟩) (.scalar (.int false 64 a)))
    (stored : StoreStep before (.pointer (.pointer true false usize) ⟨newer, 0⟩) (.scalar (.int false 64 b)) after) :
    load after (.pointer (.pointer true false usize) ⟨older, 0⟩) = .ok (.scalar (.int false 64 a)) := by
  air_byte_prepare
  assumption

end Compiler.Tests.ZigAir.MemoryByteAutomationControls
