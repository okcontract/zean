/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
Generated from admitted AIR; do not edit.
Source validity and native refinement require separate evidence.
-/
-- Source SHA-256: 24a4d4c0db93626d66d168a2c40326a81688ed7207fec1ee85dff13239458bb4
-- Capture report SHA-256: 059a60b35c99dc79b9420e71a298a15aceec42db921a196185e93c3d2fa75fec
import Compiler.ZigAir.MemoryAir

namespace «Compiler».«Tutorial».«Buffer».«V1».«Generated»
open Compiler.ZigAir.MemoryAir

-- AIR SHA-256: b48bba65b490256c9712c5f457a2cf6f3904402ad7d1f7bea86e282028d59d29
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
        .bind 10 (.scalar .bool) (.scalar (.comparison .lt (.local 8) (.local 9))) <|
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

end «Compiler».«Tutorial».«Buffer».«V1».«Generated»
