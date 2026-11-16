/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Buffer.Inputs
import Compiler.ZigAir.MemoryAirLaws
import Compiler.ZigAir.MemoryStackPrefix
import Compiler.ZigAir.MemoryWordCopyFrame

/-! Symbolic execution of the two captured implementations. Memory operations
remain in the generated programs; these lemmas expose their actual effects. -/
namespace Compiler.Tutorial.Buffer
open Compiler.ZigAir Compiler.ZigAir.Memory Compiler.ZigAir.MemoryAir
open Compiler.ZigAir.Memory.WordArray

abbrev pointerType : Ty := .pointer true true word
def slot (id : Nat) : Value := .pointer (.pointer true false pointerType) ⟨id, 0⟩
def readonly (id : Nat) : Value := .pointer (.pointer false false pointerType) ⟨id, 0⟩
theorem size_valid (n : Nat) (bounded : n < addressLimit) : (size n).valid = true := by
  simp [size, Value.valid, Scalar.Value.valid, Scalar.Ty.contains, Scalar.Ty.lower,
    Scalar.Ty.upper, addressLimit] at *
  omega

theorem size_typed (n : Nat) (bounded : n < addressLimit) : (size n).hasType (.scalar (.int false 64)) = true := by
  simpa [Value.hasType, size, Value.type, Scalar.Value.type, usize] using size_valid n bounded

theorem normalize_size (n : Nat) (bound : n < addressLimit) : Scalar.normalize false 64 n = n := by
  have bound' : (n : Int) < 2^64 := by exact_mod_cast bound
  simp only [Scalar.normalize, Bool.false_and, Bool.false_eq_true, ↓reduceIte]
  exact Int.emod_eq_of_lt (Int.natCast_nonneg n) bound'

theorem pointer_valid (writable many : Bool) (child : Ty) (address : Address) :
    (Value.pointer (.pointer writable many child) address).valid = true := rfl

theorem pointer_typed (writable many : Bool) (child : Ty) (address : Address) :
    (Value.pointer (.pointer writable many child) address).hasType (.pointer writable many child) = true := by
  simp [Value.hasType, Value.type, Value.valid]

theorem bool_typed (flag : Bool) : (Value.scalar (.bool flag)).hasType (.scalar .bool) = true := rfl
theorem bool_valid (flag : Bool) : (Value.scalar (.bool flag)).valid = true := rfl
theorem unit_typed : (Value.scalar .unit).hasType (.scalar .unit) = true := rfl
theorem unit_valid : (Value.scalar .unit).valid = true := rfl

theorem accepts (version : Version) (state : State) (view : View) (index : Nat) (value : BitVec 32)
    (initial : state.valid = true) (lengthBound : view.length < addressLimit) (indexBound : index < addressLimit) :
    (program version).accepts (arguments view index value) state = true := by
  cases version <;> simp [program, V1.Generated.fn_replace, V2.Generated.fn_replace,
    Program.accepts, arguments, initial, View.buffer, pointer_typed,
    size_typed _ lengthBound, size_typed _ indexBound, number_typed]

attribute [local simp] pointer_valid pointer_typed bool_valid bool_typed unit_valid unit_typed
  number_valid number_typed

-- Small applied equations keep kernel checking independent of the size of the
-- continuation. Each captured body is checked against this decomposition by rfl.
def writeCode (id : Nat) : Code :=
  .bind id pointerType (.load (.local 6))
    (.bind (id + 1) (.pointer true false word) (.elementPointer (.local id) (.local 2))
      (.bind (id + 2) (.scalar .unit) (.store (.local (id + 1)) (.local 3))
        (.ret (.constant (.scalar (.bool true))))))

def condition (comparison : Scalar.Comparison) (yes no : Code) : Code :=
  .bind 8 usize (.scalar (.cast .bitcast (.int false 64) (.local 2)))
    (.bind 9 usize (.scalar (.cast .bitcast (.int false 64) (.local 1)))
      (.bind 10 (.scalar .bool) (.scalar (.comparison comparison (.local 8) (.local 9)))
        (.branch (.local 10) yes no)))

def guardedCode : Version → Code
  | .v1 => .block 7 (.scalar .unit)
      (condition .lt (writeCode 11) (.jump 7 (.constant (.scalar .unit))))
      (.ret (.constant (.scalar (.bool false))))
  | .v2 => .block 7 (.scalar .unit)
      (condition .ge (.ret (.constant (.scalar (.bool false)))) (.jump 7 (.constant (.scalar .unit))))
      (writeCode 14)

def saveCode (version : Version) : Code :=
  .bind 5 (.scalar .unit) (.store (.local 4) (.local 0))
    (.bind 6 (.pointer false false pointerType) (.pointerCast (.pointer false false pointerType) (.local 4))
      (guardedCode version))

def allocateCode (version : Version) : Code :=
  .bind 4 (.pointer true false pointerType) (.alloc pointerType) (saveCode version)

def head (next : Code) : Code :=
  .bind 0 pointerType (.argument 0) (.bind 1 usize (.argument 1)
    (.bind 2 usize (.argument 2) (.bind 3 word (.argument 3) next)))

def inputEnv (view : View) (index : Nat) (value : BitVec 32) : Env :=
  (((Control.Env.set (fun _ => none) 0 view.buffer).set 1 (size view.length)).set 2 (size index)).set 3 (number value)

def preparedEnv (view : View) (index : Nat) (value : BitVec 32) (id : Nat) : Env :=
  (((inputEnv view index value).set 4 (slot id)).set 5 (.scalar .unit)).set 6 (readonly id)

def conditionEnv (env : Env) (length index : Nat) (comparison : Scalar.Comparison) : Env :=
  ((env.set 8 (size index)).set 9 (size length)).set 10 (.scalar (.bool (comparison.eval index length)))

theorem scalar_read_size (env : Env) (id n : Nat) (bounded : n < addressLimit)
    (found : env id = some (size n)) :
    (Scalar.Ref.local id).eval (scalarEnv env) = .ok (.int false 64 n) := by
  have valid := size_valid n bounded
  change (Scalar.Value.int false 64 n).valid = true at valid
  simp [Scalar.Ref.eval, scalarEnv, found, size, valid]

theorem cast_size_eval (ref : Scalar.Ref) (args : List Value) (env : Env) (state : State)
    (n : Nat) (bounded : n < addressLimit)
    (read : ref.eval (scalarEnv env) = .ok (.int false 64 n)) :
    (Prim.scalar (.cast .bitcast (.int false 64) ref)).eval args env state = (.ok (size n), state) := by
  rw [Prim.eval_scalar]
  simp only [Scalar.Prim.eval, read, bind, Except.bind, Scalar.integer,
    ↓reduceIte, normalize_size n bounded]
  rfl

theorem compare_size_eval (comparison : Scalar.Comparison) (args : List Value) (env : Env) (state : State)
    (a b : Nat) (left : (Scalar.Ref.local 8).eval (scalarEnv env) = .ok (.int false 64 a))
    (right : (Scalar.Ref.local 9).eval (scalarEnv env) = .ok (.int false 64 b)) :
    (Prim.scalar (.comparison comparison (.local 8) (.local 9))).eval args env state =
      (.ok (.scalar (.bool (comparison.eval a b))), state) := by
  rw [Prim.eval_scalar]
  simp only [Scalar.Prim.eval, left, right, bind, Except.bind, and_self, ↓reduceIte]

theorem condition_eval (comparison : Scalar.Comparison) (yes no : Code) (args : List Value)
    (env : Env) (state : State) (length index : Nat)
    (h1 : env 1 = some (size length)) (h2 : env 2 = some (size index))
    (lengthBound : length < addressLimit) (indexBound : index < addressLimit) :
    (condition comparison yes no).eval semantics args env state =
      (if comparison.eval index length then yes else no).eval semantics args
        (conditionEnv env length index comparison) state := by
  have castI := cast_size_eval (.local 2) args env state index indexBound
    (scalar_read_size env 2 index indexBound h2)
  have castL := cast_size_eval (.local 1) args (env.set 8 (size index)) state length lengthBound
    (scalar_read_size _ 1 length lengthBound (by simp [Control.Env.set, h1]))
  have compared := compare_size_eval comparison args ((env.set 8 (size index)).set 9 (size length)) state index length
    (scalar_read_size _ 8 index indexBound (by simp [Control.Env.set]))
    (scalar_read_size _ 9 length lengthBound (by simp [Control.Env.set]))
  simp only [condition, usize]
  rw [Code.eval_bind_ok castI (size_typed _ indexBound),
    Code.eval_bind_ok castL (size_typed _ lengthBound), Code.eval_bind_ok compared (bool_typed _)]
  apply Code.eval_branch_bool
  simp [Ref.eval_local, Control.Env.set]

theorem prepare_eval (version : Version) (state allocated saved : State) (view : View)
    (index : Nat) (value : BitVec 32)
    (allocation : allocate state pointerType = .ok (slot state.nextId, allocated))
    (savedPointer : store allocated (slot state.nextId) view.buffer = .ok saved) :
    (allocateCode version).eval semantics (arguments view index value) (inputEnv view index value) state =
      (guardedCode version).eval semantics (arguments view index value)
        (preparedEnv view index value state.nextId) saved := by
  have cast := pointerCast_readonly_of_load saved true false pointerType ⟨state.nextId, 0⟩ view.buffer
    (load_after_store allocated _ _ saved savedPointer)
  simp only [slot, View.buffer] at savedPointer
  simp [allocateCode, saveCode, Code.eval_bind, Prim.eval_alloc_ok _ _ _ _ _ _ allocation,
    Prim.eval_store, Prim.eval_cast, Ref.eval_local, inputEnv, preparedEnv, Control.Env.set,
    slot, readonly, View.buffer, savedPointer, cast, bind, Except.bind]

theorem write_eval (id : Nat) (args : List Value) (env : Env) (saved updated : State) (view : View)
    (index : Nat) (value : BitVec 32) (mark : Nat) (fresh : 10 < id)
    (h2 : env 2 = some (size index)) (h3 : env 3 = some (number value)) (h6 : env 6 = some (readonly mark))
    (indexBound : index < addressLimit)
    (read : load saved (readonly mark) = .ok view.buffer)
    (element : elementPointer saved view.buffer index = .ok (view.pointer index))
    (written : store saved (view.pointer index) (number value) = .ok updated) :
    (writeCode id).eval semantics args env saved = .returned (.scalar (.bool true)) updated := by
  have ne2 : 2 ≠ id := by omega
  have ne3 : 3 ≠ id := by omega
  have ne3next : 3 ≠ id + 1 := by omega
  have width := size_valid index indexBound
  simp only [size] at width
  simp only [readonly] at read
  simp only [View.buffer, View.pointer] at element written read
  simp [writeCode, Code.eval_bind, Code.eval_ret, Prim.eval_load, Prim.eval_element, Prim.eval_store,
    Ref.eval_local, Ref.eval_constant, Ref.natural_eq, h2, h3, h6, Control.Env.set,
    ne2, ne3, ne3next, readonly, read, width, size,
    element, written, bind, Except.bind]

theorem body_shape (version : Version) : (program version).body = head (allocateCode version) := by
  cases version <;> rfl

theorem head_eval (next : Code) (state : State) (view : View) (index : Nat) (value : BitVec 32)
    (lengthBound : view.length < addressLimit) (indexBound : index < addressLimit) :
    (head next).eval semantics (arguments view index value) (fun _ => none) state =
      next.eval semantics (arguments view index value) (inputEnv view index value) state := by
  simp [head, Code.eval_bind, Prim.eval_argument, arguments, inputEnv, View.buffer,
    size_typed _ lengthBound, size_typed _ indexBound, usize]

theorem run_head (version : Version) (state : State) (view : View) (index : Nat) (value : BitVec 32)
    (initial : state.valid = true) (lengthBound : view.length < addressLimit) (indexBound : index < addressLimit) :
    (program version).run (arguments view index value) state =
      Program.finish (.scalar .bool) state.nextId
        ((allocateCode version).eval semantics (arguments view index value) (inputEnv view index value) state) := by
  rw [Program.run, ite_eq_left (accepts version state view index value initial lengthBound indexBound),
    body_shape, head_eval _ _ _ _ _ lengthBound indexBound]
  cases version <;> rfl

theorem run_exhausted (version : Version) (state : State) (view : View) (index : Nat) (value : BitVec 32)
    (initial : state.valid = true) (lengthBound : view.length < addressLimit) (indexBound : index < addressLimit)
    (allocation : allocate state pointerType = .error .outOfMemory) :
    (program version).run (arguments view index value) state = (.error .outOfMemory, state) := by
  rw [run_head _ _ _ _ _ initial lengthBound indexBound]
  simp [allocateCode, Code.eval_bind,
    Prim.eval_alloc_fault _ _ _ _ _ allocation, Program.finish, cleanup_initial state initial]

theorem block_eval (id : Nat) (type : Ty) (body next : Code) (args : List Value) (env : Env) (state : State) :
    (Control.Code.block id type body next).eval semantics args env state =
      match body.eval semantics args env state with
      | .jumped target value afterEnv after =>
        if target = id then
          if value.hasType type then next.eval semantics args (afterEnv.set id value) after
          else .fault .malformed after
        else .jumped target value afterEnv after
      | other => other := by
  rw [Control.Code.eval]
  cases body.eval semantics args env state <;> rfl

theorem run_written (version : Version) (state allocated saved updated : State) (view : View)
    (index : Nat) (value : BitVec 32)
    (initial : state.valid = true) (lengthBound : view.length < addressLimit) (indexBound : index < addressLimit)
    (inside : index < view.length)
    (allocation : allocate state pointerType = .ok (slot state.nextId, allocated))
    (savedPointer : store allocated (slot state.nextId) view.buffer = .ok saved)
    (element : elementPointer saved view.buffer index = .ok (view.pointer index))
    (written : store saved (view.pointer index) (number value) = .ok updated) :
    (program version).run (arguments view index value) state =
      (.ok (.scalar (.bool true)), cleanup state.nextId updated) := by
  have read := load_alias_after_store allocated true false pointerType ⟨state.nextId, 0⟩ view.buffer saved
    false false savedPointer
  have guard (comparison : Scalar.Comparison) (yes no : Code) :=
    condition_eval comparison yes no (arguments view index value) (preparedEnv view index value state.nextId)
      saved view.length index (by simp [preparedEnv, inputEnv, Control.Env.set])
      (by simp [preparedEnv, inputEnv, Control.Env.set]) lengthBound indexBound
  rw [run_head _ _ _ _ _ initial lengthBound indexBound, prepare_eval _ _ _ _ _ _ _ allocation savedPointer]
  cases version <;>
    simp only [guardedCode, block_eval, guard, Scalar.Comparison.eval, Int.ofNat_lt, Int.ofNat_le,
      inside, Nat.not_le_of_lt inside, decide_true, decide_false, Bool.false_eq_true, ↓reduceIte,
      Code.eval_jump, Ref.eval_constant, unit_valid, unit_typed]
  all_goals
    rw [write_eval _ _ _ saved updated view index value state.nextId (by decide)
      (by simp [conditionEnv, preparedEnv, inputEnv, Control.Env.set])
      (by simp [conditionEnv, preparedEnv, inputEnv, Control.Env.set])
      (by simp [conditionEnv, preparedEnv, Control.Env.set]) indexBound read element written]
    rfl

theorem run_rejected (version : Version) (state allocated saved : State) (view : View)
    (index : Nat) (value : BitVec 32)
    (initial : state.valid = true) (lengthBound : view.length < addressLimit) (indexBound : index < addressLimit)
    (outside : view.length ≤ index)
    (allocation : allocate state pointerType = .ok (slot state.nextId, allocated))
    (savedPointer : store allocated (slot state.nextId) view.buffer = .ok saved) :
    (program version).run (arguments view index value) state =
      (.ok (.scalar (.bool false)), cleanup state.nextId saved) := by
  have guard (comparison : Scalar.Comparison) (yes no : Code) :=
    condition_eval comparison yes no (arguments view index value) (preparedEnv view index value state.nextId)
      saved view.length index (by simp [preparedEnv, inputEnv, Control.Env.set])
      (by simp [preparedEnv, inputEnv, Control.Env.set]) lengthBound indexBound
  rw [run_head _ _ _ _ _ initial lengthBound indexBound, prepare_eval _ _ _ _ _ _ _ allocation savedPointer]
  cases version <;>
    simp only [guardedCode, block_eval, guard, Scalar.Comparison.eval, Int.ofNat_lt, Int.ofNat_le,
      outside, Nat.not_lt_of_ge outside, decide_true, decide_false, Bool.false_eq_true, ↓reduceIte,
      Code.eval_jump, Code.eval_ret, Ref.eval_constant, unit_valid, unit_typed, bool_valid]
  all_goals rfl

end Compiler.Tutorial.Buffer
