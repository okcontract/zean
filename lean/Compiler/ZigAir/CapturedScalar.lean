/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.Captured

/-! Independent scalar AIR interpretation. Reuse the inert data readers and
structured opcode interpretation, then require a complete scalar projection.
No reached memory operation, guard, type or reference can be erased by this
projection. Scalar programs do not depend on a pointer layout or target ABI.
Native admission and source/export/JSON/native assumptions remain separate. -/
namespace Compiler.ZigAir.CapturedScalar
open Captured

def scalarType : Memory.Ty → Option Scalar.Ty
  | .scalar type => some type
  | _ => none

def scalarRef : MemoryAir.Ref → Option Scalar.Ref
  | .local id => some (.local id)
  | .constant (.scalar value) => some (.constant value)
  | _ => none

def scalarPrim : MemoryAir.Prim → Option Scalar.Prim
  | .argument index => some (.argument index)
  | .scalar operation => some operation
  | .booleanNot ref => return .booleanNot (← scalarRef ref)
  | _ => none

def scalarCode : Control.Code Memory.Ty MemoryAir.Prim MemoryAir.Ref → Option Scalar.Code
  | .bind id type operation next => do
    return .bind id (← scalarType type) (← scalarPrim operation) (← scalarCode next)
  | .branch condition yes no => do
    return .branch (← scalarRef condition) (← scalarCode yes) (← scalarCode no)
  | .block id type body next => do
    return .block id (← scalarType type) (← scalarCode body) (← scalarCode next)
  | .jump target value => do return .jump target (← scalarRef value)
  | .ret value => do return .ret (← scalarRef value)
  | .loop enabled _ _ | .repeat enabled _ => nomatch enabled

private def typeOf (raw : Raw) : Option Scalar.Ty := do
  scalarType (← Captured.typeOf 17 raw)

/-- Decode the scalar profile without inferring source safety. The whole
structured body is interpreted before projection; unused results are retained.
The bounded parser fuel is distinct from program execution and EVM gas. -/
def decode (raw : Raw) : Option Scalar.Program := do
  require ((← raw.textAt "schema") == "oksolc.fresh-air.v3" &&
    (← raw.textAt "capturePoint") == "after-sema-before-legalize" &&
    (← raw.textAt "bodyTraversal") == "supported-structured-containers-only" &&
    !(← raw.boolAt "sourceValidityConditionsPreserved"))
  let configuration ← raw.get "configuration"
  require ((← configuration.textAt "optimize") == "ReleaseFast" &&
    (← configuration.boolAt "useLlvm") && !(← configuration.boolAt "isTest"))
  let signature ← raw.get "signature"
  require (!(← signature.boolAt "genericInstance") && !(← signature.boolAt "varArgs") &&
    (← signature.natAt "noaliasBits") == 0 && (raw.get "specialization").isNone)
  let parameters ← (← signature.listAt "parameters").mapM typeOf
  let returnType ← typeOf (← signature.get "returnType")
  let validity ← raw.get "sourceValidity"
  require ((← validity.textAt "schema") == "oksolc.source-validity.v1" &&
    (← validity.textAt "coverage") == "runtime-slice-results" &&
    !(← validity.boolAt "complete") && (← validity.listAt "slices").isEmpty)
  let table ← raw.listAt "instructions"
  require (table.length > 0 && table.length ≤ 512)
  Captured.checkCopyCoverage raw validity table
  let code ← Captured.body false (List.range parameters.length) table [] 1024 (← raw.listAt "body")
  pure ⟨parameters, returnType, ← scalarCode code⟩

theorem interpretation_eq (raw : Raw) (program other : Scalar.Program)
    (certificate : decode raw = some program) (decoded : decode raw = some other) :
    other = program := Option.some.inj (decoded.symm.trans certificate)

end Compiler.ZigAir.CapturedScalar
