import ReservedAppend.Generated
import Compiler.ZigAir.MemoryCallMachine

namespace ReservedAppend
open Compiler.ZigAir Memory MemoryCallMachine

def byte : Ty := .scalar (.int false 8)
def usize : Ty := .scalar (.int false 64)
def byteValue (n : Nat) : Value := .scalar (.int false 8 n)
def sizeValue (n : Nat) : Value := .scalar (.int false 64 n)

def listType : Ty := .aggregate "array_list.Aligned(u8,null)" ⟨24, 8⟩
  [(0, .object (.slice true byte)), (16, .scalar (.int false 64))]

def caller (length capacity : Nat) : State :=
  let items := Value.slice (.slice true byte) ⟨1, 0⟩ length
  let initialized := (List.range length).map (fun index => (index, byteValue (10 + index)))
  ⟨[(1, ⟨32, .array 4 byte, initialized, true, false⟩),
    (0, ⟨8, listType, items.leaves ++ [(16, sizeValue capacity)], true, false⟩)], 2, 40⟩

def append (length capacity : Nat) : Option (Except Fault Value × State) :=
  match run Generated.functions 256 Generated.FunctionId.fn_append_reserved
      [.pointer (.pointer true false listType) ⟨0, 0⟩, byteValue 42] (caller length capacity) with
  | .finished result after => some (result, after)
  | .suspended _ => none

def numberAt (state : State) (address : Address) (type : Ty) : Option Nat :=
  match load state (.pointer (.pointer false false type) address) with
  | .ok (.scalar (.int false _ value)) => some value.toNat
  | _ => none

def afterAppend : Option (List Nat) := do
  let (.ok (.scalar .unit), after) ← append 1 2 | none
  pure [← numberAt after ⟨0, 8⟩ usize, ← numberAt after ⟨0, 16⟩ usize,
    ← numberAt after ⟨1, 0⟩ byte, ← numberAt after ⟨1, 1⟩ byte]

def rejectedWithHeapIntact : Bool :=
  match append 2 2 with
  | some (.error (.scalar .illegalBehavior), after) => decide (after.heap = (caller 2 2).heap)
  | _ => false

set_option maxRecDepth 8192 in
set_option maxHeartbeats 2000000 in
theorem append_with_room : afterAppend = some [2, 2, 10, 42] := by decide +kernel

set_option maxRecDepth 8192 in
set_option maxHeartbeats 2000000 in
theorem append_at_capacity :
    rejectedWithHeapIntact = true := by decide +kernel

end ReservedAppend
