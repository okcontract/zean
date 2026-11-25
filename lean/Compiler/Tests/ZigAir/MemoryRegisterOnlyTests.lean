/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryRegisterOnly

namespace Compiler.Tests.ZigAir.MemoryRegisterOnly
open Compiler.ZigAir Compiler.ZigAir.Memory MemoryCallMachine

private def byteType : Ty := .scalar (.int false 8)
private def optionalType : Ty := .optionalScalar (.int false 8)
private def optionalByte (value : Option Scalar.Value) : Value := .optionalScalar (.int false 8) value

private def extract : Function :=
  ⟨[optionalType], byteType,
    .bind 0 optionalType (.memory (.argument 0)) <|
    .bind 1 byteType (.memory (.optionalPayload (.local 0))) <|
    .ret (.local 1)⟩

private def body : MemoryAir.Code := (projectFiniteMemory extract.body).get (by decide)

private def finite : MemoryAir.Program := ⟨extract.parameters, extract.returnType, body⟩

private theorem observed (args : List Value) (state : State) (valid : state.valid = true) :
    Steps [extract] (start [extract] 0 args state) (.finished (finite.run args {}).1 state) := by
  have ran := steps_finite_memory [extract] 0 extract body rfl rfl args state
  change Steps [extract] (start [extract] 0 args state)
    (.finished (finite.run args state).1 (finite.run args state).2) at ran
  rwa [finite.run_registerOnly rfl args state {} valid rfl] at ran

example (state : State) (valid : state.valid = true) :
    Steps [extract] (start [extract] 0 [optionalByte (some (.int false 8 0))] state)
      (.finished (.ok (.scalar (.int false 8 0))) state) :=
  observed _ state valid

example (state : State) (valid : state.valid = true) :
    Steps [extract] (start [extract] 0 [optionalByte none] state)
      (.finished (.error (.scalar .illegalBehavior)) state) :=
  observed _ state valid

example : projectFiniteMemory (.loop rfl 0 (.repeat rfl 0)) = none := rfl

example : projectFiniteMemory (.bind 0 byteType (.call 0 []) (.ret (.local 0))) = none := rfl

example : MemoryAir.Code.registerOnly
    (.bind 0 byteType (.load (.local 1)) (.ret (.local 0))) = false := rfl

end Compiler.Tests.ZigAir.MemoryRegisterOnly
