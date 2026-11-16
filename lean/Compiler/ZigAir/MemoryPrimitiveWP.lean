/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryVerification
import Compiler.ZigAir.MemoryReferenceWP
import Compiler.ZigAir.MemoryValueWP
import Compiler.ZigAir.MemoryAirLaws

namespace Compiler.ZigAir.MemoryAir.Verify
open Memory Std.WP Lean.Order Control.Verification

@[spec high] theorem return_constant_spec (value : Value) (env : Env) (args : List Value)
    (invariants : Invariants) (post : Control.Verification.Post Value State) (errors : FaultCondition) :
    Triple (Task.code (.ret (.constant value)) env : Task semantics args invariants)
      (fun state => (⌜value.valid = true⌝ ⇨ post (.returned value) state) ⊓
        (⌜value.valid ≠ true⌝ ⇨ errors .malformed state)) post errors := by
  constructor
  intro state h
  simp only [meet_prop_eq_and, himp_prop_eq_imp, ofProp_prop_eq] at h
  rw [wp_code]
  simp only [pre, semantics, Ref.eval_constant]
  by_cases valid : value.valid = true
  · simpa only [valid, ↓reduceIte] using h.1 valid
  · simpa only [valid, Bool.false_eq_true, ↓reduceIte] using h.2 valid

@[spec high] theorem argument_zero_spec (value : Value) (rest : List Value) (env : Env)
    (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := value :: rest) (.argument 0) env)
      (post value) post errors := ⟨fun _ h => h⟩

@[spec high] theorem argument_succ_spec (index : Nat) (value : Value) (rest : List Value) (env : Env)
    (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := value :: rest) (.argument (index + 1)) env)
      (wp (Atomic.mk (sem := semantics) (args := rest) (.argument index) env) post errors)
      post errors := ⟨fun _ h => h⟩

/-- Arguments are pure: VC generation need not invent a new heap or SSA value. -/
@[spec] theorem argument_spec (index : Nat) (args : List Value) (env : Env)
    (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) (.argument index) env)
      (wp (match args[index]? with
        | some value => (pure value : EStateM Fault State Value)
        | none => throw Fault.malformed) post errors) post errors := by
  constructor
  intro state h
  rw [wp_atomic]
  rw [show semantics.evalPrim (.argument index) args env state =
    (Prim.argument index).eval args env state from rfl, Prim.eval_argument]
  cases found : args[index]? <;> simp only [found] at h ⊢ <;> exact h

/-- Allocation exposes both success and exhaustion. No resource assumption is
silently added, and the success branch retains the actual returned heap. -/
@[spec] theorem allocation_spec (child : Ty) (args : List Value) (env : Env)
    (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) (.alloc child) env)
      (fun state =>
        (⨅ value, ⨅ after, ⌜allocate state child = .ok (value, after)⌝ ⇨ post value after) ⊓
        (⨅ fault, ⌜allocate state child = .error fault⌝ ⇨ errors fault state)) post errors := by
  constructor
  intro state h
  simp only [meet_prop_eq_and, iInf_prop_eq_forall, himp_prop_eq_imp, ofProp_prop_eq] at h
  rw [wp_atomic]
  cases allocated : allocate state child with
  | error fault =>
    simpa only [semantics, Prim.eval, Prim.transition, allocated] using h.2 fault allocated
  | ok pair =>
    obtain ⟨value, after⟩ := pair
    simpa only [semantics, Prim.eval, Prim.transition, allocated] using h.1 value after allocated

/-- A read-only primitive returns the original state on both paths. -/
theorem readonly_spec (prim : Prim) (args : List Value) (env : Env)
    (operation : State → Except Fault Value)
    (equation : ∀ state, prim.eval args env state = (operation state, state))
    (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) prim env)
      (fun state =>
        (⨅ value, ⌜operation state = .ok value⌝ ⇨ post value state) ⊓
        (⨅ fault, ⌜operation state = .error fault⌝ ⇨ errors fault state)) post errors := by
  constructor
  intro state h
  simp only [meet_prop_eq_and, iInf_prop_eq_forall, himp_prop_eq_imp, ofProp_prop_eq] at h
  rw [wp_atomic]
  simp only [semantics]
  rw [equation]
  cases result : operation state with
  | ok value => exact h.1 value result
  | error fault => exact h.2 fault result

/-- A source-bound check produces unit and leaves memory unchanged. Exposing
that exact result here avoids introducing an arbitrary SSA value whose type
would have to be recovered later from a nested successful check. Both success
and every reference/bounds failure remain obligations. -/
@[spec] theorem bounds_spec (start finish : Ref) (upper : Bound) (args : List Value) (env : Env)
    (post : Postcondition) (errors : FaultCondition) :
    let checked : Except Fault Unit := do
      checkSliceBounds (← start.natural env) (← finish.natural env) (← upper.eval env)
    Triple (Atomic.mk (sem := semantics) (args := args) (.checkBounds start finish upper) env)
      (fun state => (⌜checked = .ok ()⌝ ⇨ post (.scalar .unit) state) ⊓
        (⨅ fault, ⌜checked = .error fault⌝ ⇨ errors fault state)) post errors := by
  dsimp only
  constructor
  intro state h
  simp only [meet_prop_eq_and, iInf_prop_eq_forall, himp_prop_eq_imp, ofProp_prop_eq] at h
  rw [wp_atomic]
  simp only [semantics, Prim.eval_bounds]
  cases a : start.natural env <;> cases b : finish.natural env <;> cases c : upper.eval env <;>
    simp only [a, b, c, bind, Except.bind] at h ⊢
  all_goals try solve | exact h.2 _ rfl
  rename_i first last limit
  cases checked : checkSliceBounds first last limit <;>
    simp only [checked, pure, Except.pure] at h ⊢
  · exact h.2 _ rfl
  · exact h.1 trivial

@[spec] theorem load_spec (pointer : Ref) (args : List Value) (env : Env)
    (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) (.load pointer) env)
      (fun state => (⨅ value, ⌜(pointer.eval env >>= load state) = .ok value⌝ ⇨ post value state) ⊓
        (⨅ fault, ⌜(pointer.eval env >>= load state) = .error fault⌝ ⇨ errors fault state)) post errors :=
  readonly_spec (.load pointer) args env (fun state => pointer.eval env >>= load state)
    (Prim.eval_load pointer args env) post errors

@[spec] theorem pointerCast_spec (target : Ty) (pointer : Ref) (args : List Value) (env : Env)
    (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) (.pointerCast target pointer) env)
      (fun state => (⨅ value, ⌜(pointer.eval env >>= pointerCast state target) = .ok value⌝ ⇨ post value state) ⊓
        (⨅ fault, ⌜(pointer.eval env >>= pointerCast state target) = .error fault⌝ ⇨ errors fault state)) post errors :=
  readonly_spec (.pointerCast target pointer) args env (fun state => pointer.eval env >>= pointerCast state target)
    (Prim.eval_cast target pointer args env) post errors

@[spec low] theorem element_spec (pointer index : Ref) (args : List Value) (env : Env)
    (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) (.elementPointer pointer index) env)
      (fun state =>
        (⨅ value, ⌜(do elementPointer state (← pointer.eval env) (← index.natural env)) = .ok value⌝ ⇨ post value state) ⊓
        (⨅ fault, ⌜(do elementPointer state (← pointer.eval env) (← index.natural env)) = .error fault⌝ ⇨ errors fault state)) post errors :=
  readonly_spec (.elementPointer pointer index) args env
    (fun state => do elementPointer state (← pointer.eval env) (← index.natural env))
    (Prim.eval_element pointer index args env) post errors

@[spec low] theorem scalar_spec (operation : Scalar.Prim) (args : List Value) (env : Env)
    (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) (.scalar operation) env)
      (fun state =>
        (⨅ value, ⌜(match operation.eval [] (scalarEnv env) with
          | .ok value => (Except.ok (.scalar value) : Except Fault Value)
          | .error fault => .error (.scalar fault)) = .ok value⌝ ⇨ post value state) ⊓
        (⨅ fault, ⌜(match operation.eval [] (scalarEnv env) with
          | .ok value => (Except.ok (.scalar value) : Except Fault Value)
          | .error fault => .error (.scalar fault)) = .error fault⌝ ⇨ errors fault state)) post errors :=
  readonly_spec (.scalar operation) args env
    (fun _ => match operation.eval [] (scalarEnv env) with
      | .ok value => .ok (.scalar value) | .error fault => .error (.scalar fault))
    (Prim.eval_scalar operation args env) post errors

@[spec low] theorem store_spec (pointer contents : Ref) (args : List Value) (env : Env)
    (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) (.store pointer contents) env)
      (fun state =>
        (⨅ after, ⌜(do store state (← pointer.eval env) (← contents.eval env)) = .ok after⌝ ⇨
          post (.scalar .unit) after) ⊓
        (⨅ fault, ⌜(do store state (← pointer.eval env) (← contents.eval env)) = .error fault⌝ ⇨
          errors fault state)) post errors := by
  constructor
  intro state h
  simp only [meet_prop_eq_and, iInf_prop_eq_forall, himp_prop_eq_imp, ofProp_prop_eq] at h
  rw [wp_atomic]
  simp only [semantics]
  rw [Prim.eval_store]
  cases result : (do store state (← pointer.eval env) (← contents.eval env)) with
  | ok after => exact h.1 after result
  | error fault => exact h.2 fault result

@[spec high] theorem store_constants_spec (pointer value : Value) (args : List Value) (env : Env)
    (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) (.store (.constant pointer) (.constant value)) env)
      (fun state =>
        (⌜pointer.valid = true ∧ value.valid = true⌝ ⇨
          ((⨅ after, ⌜store state pointer value = .ok after⌝ ⇨ post (.scalar .unit) after) ⊓
           (⨅ fault, ⌜store state pointer value = .error fault⌝ ⇨ errors fault state))) ⊓
        (⌜pointer.valid ≠ true ∨ value.valid ≠ true⌝ ⇨ errors .malformed state)) post errors := by
  constructor
  intro state h
  simp only [meet_prop_eq_and, iInf_prop_eq_forall, himp_prop_eq_imp, ofProp_prop_eq] at h
  rw [wp_atomic]
  simp only [semantics, Prim.eval_store, Ref.eval_constant]
  by_cases hp : pointer.valid = true
  · by_cases hv : value.valid = true
    · simp only [hp, hv, ↓reduceIte, bind, Except.bind]
      cases stored : store state pointer value with
      | ok after => exact (h.1 ⟨hp, hv⟩).1 after stored
      | error fault => exact (h.1 ⟨hp, hv⟩).2 fault stored
    · simpa only [hp, hv, Bool.false_eq_true, ↓reduceIte, bind, Except.bind] using h.2 (Or.inr hv)
  · simpa only [hp, Bool.false_eq_true, ↓reduceIte, bind, Except.bind] using h.2 (Or.inl hp)

@[spec] theorem store_references_spec (pointer contents : Ref) (args : List Value) (env : Env)
    (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) (.store pointer contents) env)
      (wp (ReadReference.mk pointer env) (fun address =>
        wp (ReadReference.mk contents env) (fun value =>
          wp (Atomic.mk (sem := semantics) (args := args) (.store (.constant address) (.constant value)) env)
            post errors) errors) errors) post errors := by
  constructor
  intro state h
  rw [wp_atomic]
  simp only [semantics, Prim.eval_store]
  rw [wp_reference] at h
  cases pointerRead : pointer.eval env with
  | error fault =>
    simpa only [pointerRead, bind, Except.bind] using h
  | ok address =>
    have hp := Ref.eval_valid pointer env address pointerRead
    simp only [pointerRead] at h
    rw [wp_reference] at h
    cases valueRead : contents.eval env with
    | error fault =>
      simpa only [pointerRead, valueRead, bind, Except.bind] using h
    | ok value =>
      have hv := Ref.eval_valid contents env value valueRead
      simp only [valueRead] at h
      rw [wp_atomic] at h
      simpa only [pointerRead, valueRead, semantics, Prim.eval_store,
        Ref.eval_constant, hp, hv, ↓reduceIte, bind, Except.bind] using h

@[spec] theorem element_references_spec (pointer index : Ref) (args : List Value) (env : Env)
    (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) (.elementPointer pointer index) env)
      (wp (ReadReference.mk pointer env) (fun address =>
        wp (ReadReference.mk index env) (fun value =>
          wp (NaturalValue.mk value) (fun number =>
            wp (ReadMemory.mk (fun state => elementPointer state address number)) post errors) errors) errors) errors)
      post errors := by
  constructor
  intro state h
  rw [wp_atomic]
  simp only [semantics, Prim.eval_element, Ref.natural_value]
  rw [wp_reference] at h
  cases pointerRead : pointer.eval env with
  | error fault => simpa only [pointerRead, bind, Except.bind] using h
  | ok address =>
    simp only [pointerRead] at h
    rw [wp_reference] at h
    cases indexRead : index.eval env with
    | error fault => simpa only [pointerRead, indexRead, bind, Except.bind] using h
    | ok value =>
      simp only [indexRead] at h
      rw [wp_naturalValue] at h
      cases natural : naturalValue value with
      | error fault => simpa only [pointerRead, indexRead, natural, bind, Except.bind] using h
      | ok number =>
        simp only [natural] at h
        rw [wp_readMemory] at h
        simp only [natural, bind, Except.bind]
        cases operated : elementPointer state address number with
        | ok value => simpa only [operated] using h
        | error fault => simpa only [operated] using h

@[spec high] theorem load_references_spec (pointer : Ref) (args : List Value) (env : Env)
    (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) (.load pointer) env)
      (wp (ReadReference.mk pointer env) (fun address =>
        wp (ReadMemory.mk (fun state => load state address)) post errors) errors) post errors := by
  constructor
  intro state h
  rw [wp_atomic]
  simp only [semantics, Prim.eval_load]
  rw [wp_reference] at h
  cases reference : pointer.eval env with
  | error fault => simpa only [reference, bind, Except.bind] using h
  | ok address =>
    simp only [reference] at h
    rw [wp_readMemory] at h
    simp only [bind, Except.bind]
    cases operated : load state address <;> simpa only [operated] using h

@[spec high] theorem cast_references_spec (target : Ty) (pointer : Ref) (args : List Value) (env : Env)
    (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) (.pointerCast target pointer) env)
      (wp (ReadReference.mk pointer env) (fun address =>
        wp (ReadMemory.mk (fun state => pointerCast state target address)) post errors) errors) post errors := by
  constructor
  intro state h
  rw [wp_atomic]
  simp only [semantics, Prim.eval_cast]
  rw [wp_reference] at h
  cases reference : pointer.eval env with
  | error fault => simpa only [reference, bind, Except.bind] using h
  | ok address =>
    simp only [reference] at h
    rw [wp_readMemory] at h
    simp only [bind, Except.bind]
    cases operated : pointerCast state target address <;> simpa only [operated] using h

@[spec] theorem boolean_not_spec (reference : Ref) (args : List Value) (env : Env)
    (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) (.booleanNot reference) env)
      (fun state =>
        (⨅ value, ⌜(reference.eval env >>= booleanNot) = .ok value⌝ ⇨ post value state) ⊓
        (⨅ fault, ⌜(reference.eval env >>= booleanNot) = .error fault⌝ ⇨ errors fault state)) post errors :=
  readonly_spec (.booleanNot reference) args env (fun _ => reference.eval env >>= booleanNot)
    (Prim.eval_boolean_not reference args env) post errors

/-- Reached `unreachable` is a failed safety obligation, including ReleaseFast
assertions. It cannot establish a postcondition by silently ending execution. -/
@[spec] theorem unreachable_spec (args : List Value) (env : Env)
    (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) .unreachable env)
      (errors (.scalar .illegalBehavior)) post errors := ⟨fun _ h => h⟩

end Compiler.ZigAir.MemoryAir.Verify
