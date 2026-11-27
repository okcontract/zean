/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
Generated from admitted AIR; do not edit.
Source validity and native refinement require separate evidence.
-/
-- Source SHA-256: 5b3d397a1d4eba02c8d2396a8d4ed79592b9554738de28b43c73d8a5e90f5e58
-- Capture report SHA-256: 230eac78d358101d65d15af43163581d154e0f7ca1b20d086ee8c0cdf5c5fa6d
import Compiler.ZigAir.MemoryExecution

namespace «Compiler».«Tutorial».«Copy».«Generated»
open Compiler.ZigAir.MemoryAir

-- AIR SHA-256: 1e6e5e26377344b430be6ee9ee142f88772a21da3deb54f6989f9293dbe81732
def fn_copy : Program true :=
  { parameters := [(.pointer true true (.scalar (.int false 32))), (.pointer false true (.scalar (.int false 32))), (.scalar (.int false 64))],
    returnType := (.scalar .unit),
    body :=
      .bind 0 (.pointer true true (.scalar (.int false 32))) (.argument 0) <|
      .bind 1 (.pointer false true (.scalar (.int false 32))) (.argument 1) <|
      .bind 2 (.scalar (.int false 64)) (.argument 2) <|
      .bind 3 (.pointer true false (.pointer true true (.scalar (.int false 32)))) (.alloc (.pointer true true (.scalar (.int false 32)))) <|
      .bind 4 (.scalar .unit) (.store (.local 3) (.local 0)) <|
      .bind 5 (.pointer false false (.pointer true true (.scalar (.int false 32)))) (.pointerCast (.pointer false false (.pointer true true (.scalar (.int false 32)))) (.local 3)) <|
      .bind 6 (.pointer true false (.pointer false true (.scalar (.int false 32)))) (.alloc (.pointer false true (.scalar (.int false 32)))) <|
      .bind 7 (.scalar .unit) (.store (.local 6) (.local 1)) <|
      .bind 8 (.pointer false false (.pointer false true (.scalar (.int false 32)))) (.pointerCast (.pointer false false (.pointer false true (.scalar (.int false 32)))) (.local 6)) <|
      .bind 9 (.pointer true false (.scalar (.int false 64))) (.alloc (.scalar (.int false 64))) <|
      .bind 10 (.scalar .unit) (.store (.local 9) (.constant (.scalar (.int false 64 (0))))) <|
      .block 11 (.scalar .unit) (
        .loop rfl 12 <|
        .block 13 (.scalar .unit) (
          .bind 14 (.scalar (.int false 64)) (.load (.local 9)) <|
          .bind 15 (.scalar (.int false 64)) (.scalar (.cast .bitcast (.int false 64) (.local 14))) <|
          .bind 16 (.scalar (.int false 64)) (.scalar (.cast .bitcast (.int false 64) (.local 2))) <|
          .bind 17 (.scalar .bool) (.scalar (.comparison .lt (.local 15) (.local 16))) <|
          .branch (.local 17)
            (
              .bind 19 (.scalar (.int false 64)) (.load (.local 9)) <|
              .bind 20 (.pointer true true (.scalar (.int false 32))) (.load (.local 5)) <|
              .bind 21 (.pointer true false (.scalar (.int false 32))) (.elementPointer (.local 20) (.local 19)) <|
              .bind 22 (.scalar (.int false 64)) (.load (.local 9)) <|
              .bind 23 (.pointer false true (.scalar (.int false 32))) (.load (.local 8)) <|
              .bind 24 (.pointer false false (.scalar (.int false 32))) (.elementPointer (.local 23) (.local 22)) <|
              .bind 26 (.scalar (.int false 32)) (.load (.local 24)) <|
              .bind 27 (.scalar .unit) (.store (.local 21) (.local 26)) <|
              .bind 30 (.scalar (.int false 64)) (.load (.local 9)) <|
              .bind 31 (.scalar (.int false 64)) (.scalar (.arithmetic .add .unchecked (.local 30) (.constant (.int false 64 (1))))) <|
              .bind 32 (.scalar .unit) (.store (.local 9) (.local 31)) <|
              (.jump 13 (.constant (.scalar .unit)))
            )
            (
              (.jump 11 (.constant (.scalar .unit)))
            )
        ) <|
        (.repeat rfl 12)
      ) <|
      (.ret (.constant (.scalar .unit)))
  }

-- AIR SHA-256: 66f2df04d5f208cc22b611a102480153798e27cdf55cb69211726775b5200b18
def fn_copy_word : Program true :=
  { parameters := [(.pointer true false (.scalar (.int false 32))), (.pointer false false (.scalar (.int false 32)))],
    returnType := (.scalar .unit),
    body :=
      .bind 0 (.pointer true false (.scalar (.int false 32))) (.argument 0) <|
      .bind 1 (.pointer false false (.scalar (.int false 32))) (.argument 1) <|
      .bind 3 (.scalar (.int false 32)) (.load (.local 1)) <|
      .bind 4 (.scalar .unit) (.store (.local 0) (.local 3)) <|
      (.ret (.constant (.scalar .unit)))
  }

end «Compiler».«Tutorial».«Copy».«Generated»
