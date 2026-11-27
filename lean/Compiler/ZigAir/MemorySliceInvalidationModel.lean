/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryInvalidationModel

namespace Compiler.ZigAir.Memory

namespace SliceInvalidation

/-- A bulk undefined fill forgets each declared element in order. If access
fails, the result retains the invalidations that have already succeeded. -/
def runElements (state : State) (child : Ty) (address : Address) (stride index : Nat) :
    Nat → Except Fault Unit × State
  | 0 => (.ok (), state)
  | count + 1 =>
    let element := { address with offset := address.offset + index * stride }
    match invalidate state true child element with
    | .error fault => (.error fault, state)
    | .ok after => runElements after child address stride (index + 1) count

def run (state : State) (target : Value) : Except Fault Unit × State :=
  match target with
  | .slice (.slice true child) address count =>
    if !target.valid then (.error .malformed, state)
    else
      match child.layout with
      | none => (.error .unsupported, state)
      | some layout =>
        if layout.bytes = 0 then (.error .unsupported, state)
        else runElements state child address layout.bytes 0 count
  | .slice (.slice false _) _ _ => (.error .readOnly, state)
  | _ => (.error .malformed, state)

section
variable (invariant : State → Prop)
variable (erase : ∀ {before after : State} {child : Ty} {address : Address}, invariant before →
  invalidate before true child address = .ok after → invariant after)
include erase

theorem elements_preserve (state : State) (child : Ty) (address : Address) (stride index count : Nat)
    (initial : invariant state) : invariant (runElements state child address stride index count).2 := by
  induction count generalizing state index with
  | zero => exact initial
  | succ count ih =>
    rw [runElements]
    cases reached : invalidate state true child { address with offset := address.offset + index * stride } with
    | error fault => exact initial
    | ok after => exact ih after (index + 1) (erase initial reached)

theorem preserves (state : State) (target : Value) (initial : invariant state) :
    invariant (run state target).2 := by
  unfold run
  split
  · split
    · exact initial
    · split
      · exact initial
      · split
        · exact initial
        · exact elements_preserve invariant erase _ _ _ _ _ _ initial
  · exact initial
  · exact initial

end

end SliceInvalidation
end Compiler.ZigAir.Memory
