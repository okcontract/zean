/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Components.Replace.Generated
import Compiler.ZigAir.Verify.Slices

/-! An unchanged Zig standard-library specialization, verified as a client.
The contract is memory safety, initialization preservation and framing. It does
not yet specify the exact replacement list or termination/resource sufficiency. -/
namespace Compiler.Components.Replace
open Compiler.ZigAir Compiler.ZigAir.Memory Compiler.ZigAir.MemoryAir MemoryAir.Verify
open Memory.WordArray Control.Verification Std.WP
set_option maxRecDepth 4096
set_option maxHeartbeats 4000000

def size (n : Nat) : Value := .scalar (.int false 64 n)
def viewBinding : Bindings.Binding := air_binding% (Bindings.arguments Generated.fn_replaceScalar__func_0.body)[0]'(by decide)
def matchBinding : Bindings.Binding := air_binding% (Bindings.arguments Generated.fn_replaceScalar__func_0.body)[1]'(by decide)
def replacementBinding : Bindings.Binding := air_binding% (Bindings.arguments Generated.fn_replaceScalar__func_0.body)[2]'(by decide)
def indexBinding : Bindings.Binding := air_binding% (Bindings.allocations Generated.fn_replaceScalar__func_0.body)[0]'(by decide)
def replaceLoop : Nat := air_binding% (Bindings.loops Generated.fn_replaceScalar__func_0.body)[0]'(by decide)

-- The slice length is a derived immutable register. Its binding is selected by
-- the operation rather than a literal instruction number.
def lengthBinding : Bindings.Binding := air_binding%
  ((Bindings.primitives Generated.fn_replaceScalar__func_0.body).filterMap
    (fun (binding, operation) => match operation with | .sliceLen _ => some binding | _ => none))[0]'(by decide)

def invariant (initial : State) (view : View) (matchValue replacement : BitVec 32) : Invariants :=
  fun label env state => label = replaceLoop ∧ ∃ index,
    index ≤ view.length ∧
    env viewBinding.register = some view.slice ∧
    env matchBinding.register = some (number matchValue) ∧
    env replacementBinding.register = some (number replacement) ∧
    env lengthBinding.register = some (size view.length) ∧
    indexBinding.Saved initial.nextId env state (size index) ∧
    state.valid = true ∧ Writable state view ∧ Initialized state view ∧
    BorrowedFrame view initial state

def Preserved (initial : State) (view : View) (after : State) : Prop :=
  after.valid = true ∧ Writable after view ∧ Initialized after view ∧ HeapFrame view initial after

def Completed (initial : State) (view : View) (value : Value) (after : State) : Prop :=
  value = .scalar .unit ∧ Preserved initial view after

def Exhausted (initial : State) (view : View) (fault : Fault) (after : State) : Prop :=
  fault = .outOfMemory ∧ Preserved initial view after

theorem preserved (initial state : State) (view : View) (cap : Writable state view)
    (initialized : Initialized state view) (frame : BorrowedFrame view initial state)
    (older : view.allocation < initial.nextId) : Preserved initial view (cleanup initial.nextId state) := by
  refine ⟨cleanup_preserves_valid _ _ frame.valid, ?_, initialized.cleanup older, frame.cleanup⟩
  obtain ⟨extent, cell, found, typed, writable, bound⟩ := cap
  exact ⟨extent, cell, (cleanup_lookup_older state initial.nextId view.allocation older).trans found,
    typed, writable, bound⟩

theorem replace_contract (initial : State) (view : View) (matchValue replacement : BitVec 32)
    (valid : initial.valid = true) (cap : Writable initial view) (initialized : Initialized initial view) :
    Triple (Verify.Invocation.mk Generated.fn_replaceScalar__func_0
      [view.slice, number matchValue, number replacement] (invariant initial view matchValue replacement))
      (fun before => before = initial) (Completed initial view) (Exhausted initial view) := by
  have frame := StackFrame.refl initial valid
  have bound := view_width initial view valid cap
  have older := view_older initial view valid cap
  have sliceValid := View.slice_valid view bound
  have sliceTyped := View.slice_typed view bound
  dsimp only [Generated.fn_replaceScalar__func_0]
  air_vcgen [invariant, size, viewBinding, matchBinding, replacementBinding, indexBinding,
    lengthBinding, replaceLoop, Bindings.checked, Bindings.Binding.Saved, usize, sliceLength]
  air_slice_finish (verbose := false) (gen := 20) (ematch := 10) (instances := 3000)
    [Completed, Exhausted, preserved]

/-- Every reachable completed prefix is safe, with permitted allocation
exhaustion. Suspension leaves further execution to the same invariant. -/
theorem replace_safe (initial : State) (view : View) (matchValue replacement : BitVec 32)
    (valid : initial.valid = true) (cap : Writable initial view) (initialized : Initialized initial view)
    (fuel : Nat) :
    Verify.Observes (Completed initial view) (Exhausted initial view)
      (Generated.fn_replaceScalar__func_0.runFuel fuel [view.slice, number matchValue, number replacement] initial) :=
  Verify.sound _ _ _ _ (replace_contract initial view matchValue replacement valid cap initialized) initial rfl fuel

end Compiler.Components.Replace
