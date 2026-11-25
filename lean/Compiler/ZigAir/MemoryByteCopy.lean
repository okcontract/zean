/-
// Copyright (C) 2026 OKcontract Pte. Ltd.
// SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryScalarByteModel
import Compiler.ZigAir.MemoryInvalidationModel

/-! Byte-range operations for captured AIR. Reads resolve the original typed
integer leaves; padding and undefined storage never acquire invented bytes.
Initialized writes use the ordinary byte store; undefined bytes erase the
destination's initialization. A failed copy retains its completed prefix.
The caller's slice checks and the non-overlap requirement remain explicit. -/
namespace Compiler.ZigAir.Memory.ByteRange

def byte : Ty := .scalar (.int false 8)

def read (state : State) (address : Address) (count : Nat) : Except Fault (List (BitVec 8)) :=
  (List.range count).mapM fun index => ScalarBytes.readAt state
    { address with offset := address.offset + index }

def copyByte (state : State) (source target : Address) (index : Nat) : Except Fault State :=
  match ScalarBytes.readAt state { source with offset := source.offset + index } with
  | .error .uninitialized => invalidate state true byte { target with offset := target.offset + index }
  | .error fault => .error fault
  | .ok bits => store state (.pointer (.pointer true false byte)
      { target with offset := target.offset + index }) (.scalar (.int false 8 bits.toNat))

theorem copyByte_initialized (read : ScalarBytes.readAt state { source with offset := source.offset + index } = .ok bits) :
    copyByte state source target index = store state (.pointer (.pointer true false byte)
      { target with offset := target.offset + index }) (.scalar (.int false 8 bits.toNat)) := by
  simp only [copyByte, read]

/-- Successful transport either writes a known byte or forgets exactly the
destination byte. Undefinedness is preserved, never replaced by an invented value. -/
theorem copyByte_success (copied : copyByte state source target index = .ok after) :
    (∃ bits, ScalarBytes.readAt state { source with offset := source.offset + index } = .ok bits ∧
      store state (.pointer (.pointer true false byte) { target with offset := target.offset + index })
        (.scalar (.int false 8 bits.toNat)) = .ok after) ∨
    (ScalarBytes.readAt state { source with offset := source.offset + index } = .error .uninitialized ∧
      invalidate state true byte { target with offset := target.offset + index } = .ok after) := by
  cases read : ScalarBytes.readAt state { source with offset := source.offset + index } with
  | ok bits => exact .inl ⟨bits, rfl, by simpa only [copyByte, read] using copied⟩
  | error fault =>
    cases fault <;> simp_all [copyByte]

def copyLoop (state : State) (source target : Address) (index : Nat) :
    Nat → Except Fault Unit × State
  | 0 => (.ok (), state)
  | count + 1 =>
    match copyByte state source target index with
    | .error fault => (.error fault, state)
    | .ok after => copyLoop after source target (index + 1) count

def copyBackward (state : State) (source target : Address) :
    Nat → Except Fault Unit × State
  | 0 => (.ok (), state)
  | count + 1 =>
    match copyByte state source target count with
    | .error fault => (.error fault, state)
    | .ok after => copyBackward after source target count

def destination : Value → Except Fault (Address × Nat)
  | .slice (.slice true (.scalar (.int false 8))) address count => .ok (address, count)
  | .pointer (.pointer true false (.array count (.scalar (.int false 8)))) address => .ok (address, count)
  | .slice (.slice false _) _ _ | .pointer (.pointer false _ _) _ => .error .readOnly
  | _ => .error .unsupported

def source (value : Value) (count : Nat) : Except Fault Address := do
  match value with
  | .pointer (.pointer _ true (.scalar (.int false 8))) address => .ok address
  | .pointer (.pointer _ false (.array length (.scalar (.int false 8)))) address
  | .slice (.slice _ (.scalar (.int false 8))) address length =>
    if count = length then .ok address else .error .sourceBounds
  | _ => .error .unsupported

def copy (state : State) (target input : Value) : Except Fault Unit × State :=
  match destination target with
  | .error fault => (.error fault, state)
  | .ok (dest, count) =>
    match source input count with
    | .error fault => (.error fault, state)
    | .ok src =>
      if count > 0 ∧ src.allocation = dest.allocation ∧
          src.offset < dest.offset + count ∧ dest.offset < src.offset + count then
        (.error .memoryValidity, state)
      else copyLoop state src dest 0 count

/-- A rightward overlapping move reads high offsets first. For every
other move, low offsets are safe to read first. Both paths transport
initialization and retain the writes reached before a fault. -/
def move (state : State) (target input : Value) : Except Fault Unit × State :=
  match destination target with
  | .error fault => (.error fault, state)
  | .ok (dest, count) =>
    match source input count with
    | .error fault => (.error fault, state)
    | .ok src =>
      if src.allocation = dest.allocation ∧ src.offset < dest.offset ∧
          dest.offset < src.offset + count then
        copyBackward state src dest count
      else copyLoop state src dest 0 count

section
variable (invariant : State → Prop)
variable (transport : ∀ {before after source target index}, invariant before →
  copyByte before source target index = .ok after → invariant after)
include transport

/-- A per-byte invariant holds at every stopping point, including a fault
after a completed prefix. -/
theorem copyLoop_preserves (state : State) (source target : Address) (index count : Nat)
    (initial : invariant state) : invariant (copyLoop state source target index count).2 := by
  induction count generalizing state index with
  | zero => exact initial
  | succ count ih =>
    rw [copyLoop]
    cases copied : copyByte state source target index with
    | error fault => exact initial
    | ok after => exact ih after (index + 1) (transport initial copied)

theorem copyBackward_preserves (state : State) (source target : Address) (count : Nat)
    (initial : invariant state) : invariant (copyBackward state source target count).2 := by
  induction count generalizing state with
  | zero => exact initial
  | succ count ih =>
    rw [copyBackward]
    cases copied : copyByte state source target count with
    | error fault => exact initial
    | ok after => exact ih after (transport initial copied)

theorem copy_preserves (state : State) (target input : Value) (initial : invariant state) :
    invariant (copy state target input).2 := by
  unfold copy
  split
  · exact initial
  · split
    · exact initial
    · split
      · exact initial
      · exact copyLoop_preserves invariant transport _ _ _ _ _ initial

theorem move_preserves (state : State) (target input : Value) (initial : invariant state) :
    invariant (move state target input).2 := by
  unfold move
  split
  · exact initial
  · split
    · exact initial
    · split
      · exact copyBackward_preserves invariant transport _ _ _ _ initial
      · exact copyLoop_preserves invariant transport _ _ _ _ _ initial

end

end Compiler.ZigAir.Memory.ByteRange
