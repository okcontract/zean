/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
Generated from admitted AIR; do not edit.
Source validity and native refinement require separate evidence.
-/
-- Source SHA-256: cccf21d843a55cbc8f14793ef1d80be76d56000ce34ccf76a357394931bc5c51
-- Capture report SHA-256: a25c17dd6b841143e1ca50cc7a306a1a9d47b6c92b7f58aa49588ea57ea18405
import Compiler.ZigAir.MemoryCallMachine

namespace «Compiler».«Tutorial».«Calls».«Generated»
open Compiler.ZigAir.MemoryCallMachine

-- Zig declaration: calls.inside
def FunctionId.fn_inside : Nat := 0

-- AIR SHA-256: c31822edd23d287e22a56a608229e0abf817c6c9de50aec157dbb0a665f56057
def fn_inside : Function :=
  { parameters := [(.scalar (.int false 64)), (.scalar (.int false 64))],
    returnType := (.scalar .bool),
    body :=
      .bind 0 (.scalar (.int false 64)) (.memory (.argument 0)) <|
      .bind 1 (.scalar (.int false 64)) (.memory (.argument 1)) <|
      .bind 2 (.scalar (.int false 64)) (.memory (.scalar (.cast .bitcast (.int false 64) (.local 0)))) <|
      .bind 3 (.scalar (.int false 64)) (.memory (.scalar (.cast .bitcast (.int false 64) (.local 1)))) <|
      .bind 4 (.scalar .bool) (.memory (.scalar (.comparison .lt (.local 2) (.local 3)))) <|
      (.ret (.local 4))
  }

-- Zig declaration: calls.replace
def FunctionId.fn_replace : Nat := 1

-- AIR SHA-256: 06bbbd3957a237f64a4ada81720d6d33280a15d13792f54385576c8329edb745
def fn_replace : Function :=
  { parameters := [(.pointer true true (.scalar (.int false 32))), (.scalar (.int false 64)), (.scalar (.int false 64)), (.scalar (.int false 32))],
    returnType := (.scalar .bool),
    body :=
      .bind 0 (.pointer true true (.scalar (.int false 32))) (.memory (.argument 0)) <|
      .bind 1 (.scalar (.int false 64)) (.memory (.argument 1)) <|
      .bind 2 (.scalar (.int false 64)) (.memory (.argument 2)) <|
      .bind 3 (.scalar (.int false 32)) (.memory (.argument 3)) <|
      .bind 4 (.pointer true false (.pointer true true (.scalar (.int false 32)))) (.memory (.alloc (.pointer true true (.scalar (.int false 32))))) <|
      .bind 5 (.scalar .unit) (.memory (.store (.local 4) (.local 0))) <|
      .bind 6 (.pointer false false (.pointer true true (.scalar (.int false 32)))) (.memory (.pointerCast (.pointer false false (.pointer true true (.scalar (.int false 32)))) (.local 4))) <|
      .block 7 (.scalar .unit) (
        .bind 8 (.scalar .bool) (.call FunctionId.fn_inside [(.local 2), (.local 1)]) <|
        .branch (.local 8)
          (
            .bind 9 (.pointer true true (.scalar (.int false 32))) (.memory (.load (.local 6))) <|
            .bind 10 (.pointer true false (.scalar (.int false 32))) (.memory (.elementPointer (.local 9) (.local 2))) <|
            .bind 11 (.scalar .unit) (.memory (.store (.local 10) (.local 3))) <|
            (.ret (.constant (.scalar (.bool true))))
          )
          (
            (.jump 7 (.constant (.scalar .unit)))
          )
      ) <|
      (.ret (.constant (.scalar (.bool false))))
  }

-- Zig declaration: calls.update
def FunctionId.fn_update : Nat := 2

-- AIR SHA-256: c61e968fc55614b5044b6d2c11a382c987944ec7e50a81f98c858d964da70ade
def fn_update : Function :=
  { parameters := [(.pointer true true (.scalar (.int false 32))), (.scalar (.int false 64)), (.scalar (.int false 64)), (.scalar (.int false 32))],
    returnType := (.scalar .bool),
    body :=
      .bind 0 (.pointer true true (.scalar (.int false 32))) (.memory (.argument 0)) <|
      .bind 1 (.scalar (.int false 64)) (.memory (.argument 1)) <|
      .bind 2 (.scalar (.int false 64)) (.memory (.argument 2)) <|
      .bind 3 (.scalar (.int false 32)) (.memory (.argument 3)) <|
      .bind 4 (.scalar .bool) (.call FunctionId.fn_replace [(.local 0), (.local 1), (.local 2), (.local 3)]) <|
      (.ret (.local 4))
  }

def functions : Program := [fn_inside, fn_replace, fn_update]

end «Compiler».«Tutorial».«Calls».«Generated»
