/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
Generated from admitted AIR; do not edit.
Source validity and native refinement require separate evidence.
-/
-- Source SHA-256: e393a881a64ea243558998c74269ead873cda48f9ebed0eca143cc0394b085c9
-- Capture report SHA-256: da3e3a1ce306608f9e9949e355f1fbb5024394fa0a8ccb7586d0b40acb8b8172
import Compiler.ZigAir.MemoryAir

namespace «Compiler».«Tutorial».«Buffer».«Broken».«Generated»
open Compiler.ZigAir.MemoryAir

-- AIR SHA-256: d07eaa3185da63f9ebd9989c08721189baf10f138c232393d1ae4613a326f07c
def fn_replace : Program :=
  { parameters := [(.pointer true true (.scalar (.int false 32))), (.scalar (.int false 64)), (.scalar (.int false 64)), (.scalar (.int false 32))],
    returnType := (.scalar .bool),
    body :=
      .bind 0 (.pointer true true (.scalar (.int false 32))) (.argument 0) <|
      .bind 1 (.scalar (.int false 64)) (.argument 1) <|
      .bind 2 (.scalar (.int false 64)) (.argument 2) <|
      .bind 3 (.scalar (.int false 32)) (.argument 3) <|
      .bind 4 (.pointer true false (.pointer true true (.scalar (.int false 32)))) (.alloc (.pointer true true (.scalar (.int false 32)))) <|
      .bind 5 (.scalar .unit) (.store (.local 4) (.local 0)) <|
      .bind 6 (.pointer false false (.pointer true true (.scalar (.int false 32)))) (.pointerCast (.pointer false false (.pointer true true (.scalar (.int false 32)))) (.local 4)) <|
      .block 7 (.scalar .unit) (
        .bind 8 (.scalar (.int false 64)) (.scalar (.cast .bitcast (.int false 64) (.local 2))) <|
        .bind 9 (.scalar (.int false 64)) (.scalar (.cast .bitcast (.int false 64) (.local 1))) <|
        .bind 10 (.scalar .bool) (.scalar (.comparison .le (.local 8) (.local 9))) <|
        .branch (.local 10)
          (
            .bind 11 (.pointer true true (.scalar (.int false 32))) (.load (.local 6)) <|
            .bind 12 (.pointer true false (.scalar (.int false 32))) (.elementPointer (.local 11) (.local 2)) <|
            .bind 13 (.scalar .unit) (.store (.local 12) (.local 3)) <|
            (.ret (.constant (.scalar (.bool true))))
          )
          (
            (.jump 7 (.constant (.scalar .unit)))
          )
      ) <|
      (.ret (.constant (.scalar (.bool false))))
  }

end «Compiler».«Tutorial».«Buffer».«Broken».«Generated»
