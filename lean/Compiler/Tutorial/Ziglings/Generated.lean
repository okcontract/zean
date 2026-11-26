/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
Generated from admitted AIR; do not edit.
Source validity and native refinement require separate evidence.
-/
-- Source SHA-256: 3ee6c27240c06ff711c0d5879697326273c6e92df641eac03a147874e00dd1ef
-- Capture report SHA-256: 6a0b0f1a0e39a63d200ed1cbcb67b7207bfc3701112ee29379156bccaedc4525
import Compiler.ZigAir.MemoryAir

namespace «Compiler».«Tutorial».«Ziglings».«Generated»
open Compiler.ZigAir.MemoryAir

-- AIR SHA-256: f27a456018f122d0ae1c9f7c36386b10f81be3d8317c6999da4c99d6e6bc3d5d
def fn_initialize_pair : Program :=
  { parameters := [(.pointer true true (.scalar (.int false 32))), (.scalar (.int false 32)), (.scalar (.int false 32)), (.scalar (.int false 64))],
    returnType := (.scalar (.int false 32)),
    body :=
      .bind 0 (.pointer true true (.scalar (.int false 32))) (.argument 0) <|
      .bind 1 (.scalar (.int false 32)) (.argument 1) <|
      .bind 2 (.scalar (.int false 32)) (.argument 2) <|
      .bind 3 (.scalar (.int false 64)) (.argument 3) <|
      .bind 4 (.pointer true false (.pointer true true (.scalar (.int false 32)))) (.alloc (.pointer true true (.scalar (.int false 32)))) <|
      .bind 5 (.scalar .unit) (.store (.local 4) (.local 0)) <|
      .bind 6 (.pointer false false (.pointer true true (.scalar (.int false 32)))) (.pointerCast (.pointer false false (.pointer true true (.scalar (.int false 32)))) (.local 4)) <|
      .bind 7 (.pointer true true (.scalar (.int false 32))) (.load (.local 6)) <|
      .bind 8 (.pointer true false (.scalar (.int false 32))) (.elementPointer (.local 7) (.constant (.scalar (.int false 64 (0))))) <|
      .bind 9 (.scalar .unit) (.store (.local 8) (.local 1)) <|
      .bind 10 (.pointer true true (.scalar (.int false 32))) (.load (.local 6)) <|
      .bind 11 (.pointer true false (.scalar (.int false 32))) (.elementPointer (.local 10) (.constant (.scalar (.int false 64 (1))))) <|
      .bind 12 (.scalar .unit) (.store (.local 11) (.local 2)) <|
      .bind 13 (.pointer true true (.scalar (.int false 32))) (.load (.local 6)) <|
      .bind 14 (.pointer true false (.scalar (.int false 32))) (.elementPointer (.local 13) (.local 3)) <|
      .bind 15 (.scalar (.int false 32)) (.load (.local 14)) <|
      (.ret (.local 15))
  }

-- AIR SHA-256: 3b4a6d461f437ecb8ac9dc1d920350620a082bd7c47999ec2824c908c3c92a5c
def fn_missing_character : Program :=
  { parameters := [(.pointer true true (.scalar (.int false 32))), (.scalar (.int false 32)), (.scalar (.int false 32)), (.scalar (.int false 64))],
    returnType := (.scalar (.int false 32)),
    body :=
      .bind 0 (.pointer true true (.scalar (.int false 32))) (.argument 0) <|
      .bind 1 (.scalar (.int false 32)) (.argument 1) <|
      .bind 2 (.scalar (.int false 32)) (.argument 2) <|
      .bind 3 (.scalar (.int false 64)) (.argument 3) <|
      .bind 4 (.pointer true false (.pointer true true (.scalar (.int false 32)))) (.alloc (.pointer true true (.scalar (.int false 32)))) <|
      .bind 5 (.scalar .unit) (.store (.local 4) (.local 0)) <|
      .bind 6 (.pointer false false (.pointer true true (.scalar (.int false 32)))) (.pointerCast (.pointer false false (.pointer true true (.scalar (.int false 32)))) (.local 4)) <|
      .bind 7 (.pointer true true (.scalar (.int false 32))) (.load (.local 6)) <|
      .bind 8 (.pointer true false (.scalar (.int false 32))) (.elementPointer (.local 7) (.constant (.scalar (.int false 64 (0))))) <|
      .bind 9 (.scalar .unit) (.store (.local 8) (.local 1)) <|
      .bind 10 (.pointer true true (.scalar (.int false 32))) (.load (.local 6)) <|
      .bind 11 (.pointer true false (.scalar (.int false 32))) (.elementPointer (.local 10) (.local 3)) <|
      .bind 12 (.scalar (.int false 32)) (.load (.local 11)) <|
      (.ret (.local 12))
  }

-- AIR SHA-256: 22c6cdf866c81ef3b81f3f955d9d83f18952ca427f9ee5f0f6e04733b8f71f6b
def fn_phrase_byte : Program :=
  { parameters := [(.pointer false true (.scalar (.int false 8))), (.scalar (.int false 64)), (.scalar (.int false 64))],
    returnType := (.scalar (.int false 8)),
    body :=
      .bind 0 (.pointer false true (.scalar (.int false 8))) (.argument 0) <|
      .bind 1 (.scalar (.int false 64)) (.argument 1) <|
      .bind 2 (.scalar (.int false 64)) (.argument 2) <|
      .bind 3 (.pointer true false (.pointer false true (.scalar (.int false 8)))) (.alloc (.pointer false true (.scalar (.int false 8)))) <|
      .bind 4 (.scalar .unit) (.store (.local 3) (.local 0)) <|
      .bind 5 (.pointer false false (.pointer false true (.scalar (.int false 8)))) (.pointerCast (.pointer false false (.pointer false true (.scalar (.int false 8)))) (.local 3)) <|
      .block 6 (.scalar .unit) (
        .bind 7 (.scalar (.int false 64)) (.scalar (.cast .bitcast (.int false 64) (.local 2))) <|
        .bind 8 (.scalar (.int false 64)) (.scalar (.cast .bitcast (.int false 64) (.local 1))) <|
        .bind 9 (.scalar .bool) (.scalar (.comparison .ge (.local 7) (.local 8))) <|
        .branch (.local 9)
          (
            (.ret (.constant (.scalar (.int false 8 (0)))))
          )
          (
            (.jump 6 (.constant (.scalar .unit)))
          )
      ) <|
      .bind 13 (.pointer false true (.scalar (.int false 8))) (.load (.local 5)) <|
      .bind 14 (.pointer false true (.scalar (.int false 8))) (.offsetPointer false (.local 13) (.constant (.scalar (.int false 64 (0))))) <|
      .bind 15 (.scalar (.int false 64)) (.scalar (.arithmetic .sub .unchecked (.local 1) (.constant (.int false 64 (0))))) <|
      .bind 24 (.scalar .unit) (.checkBounds (.constant (.scalar (.int false 64 (0)))) (.local 1) .unbounded) <|
      .bind 16 (.slice false (.scalar (.int false 8))) (.slice (.slice false (.scalar (.int false 8))) (.local 14) (.local 15)) <|
      .bind 17 (.pointer true false (.slice false (.scalar (.int false 8)))) (.alloc (.slice false (.scalar (.int false 8)))) <|
      .bind 18 (.scalar .unit) (.store (.local 17) (.local 16)) <|
      .bind 19 (.pointer false false (.slice false (.scalar (.int false 8)))) (.pointerCast (.pointer false false (.slice false (.scalar (.int false 8)))) (.local 17)) <|
      .bind 20 (.slice false (.scalar (.int false 8))) (.load (.local 19)) <|
      .bind 21 (.pointer false false (.scalar (.int false 8))) (.sliceElementPointer (.local 20) (.local 2)) <|
      .bind 22 (.scalar (.int false 8)) (.load (.local 21)) <|
      (.ret (.local 22))
  }

-- AIR SHA-256: 1430ba618d4cf742287ff2036e083189af3f9d5e421c7b89b314414d4855da3f
def fn_exaggerated_byte : Program :=
  { parameters := [(.pointer false true (.scalar (.int false 8))), (.scalar (.int false 64)), (.scalar (.int false 64))],
    returnType := (.scalar (.int false 8)),
    body :=
      .bind 0 (.pointer false true (.scalar (.int false 8))) (.argument 0) <|
      .bind 1 (.scalar (.int false 64)) (.argument 1) <|
      .bind 2 (.scalar (.int false 64)) (.argument 2) <|
      .bind 3 (.pointer true false (.pointer false true (.scalar (.int false 8)))) (.alloc (.pointer false true (.scalar (.int false 8)))) <|
      .bind 4 (.scalar .unit) (.store (.local 3) (.local 0)) <|
      .bind 5 (.pointer false false (.pointer false true (.scalar (.int false 8)))) (.pointerCast (.pointer false false (.pointer false true (.scalar (.int false 8)))) (.local 3)) <|
      .block 6 (.scalar .unit) (
        .bind 7 (.scalar (.int false 64)) (.scalar (.arithmetic .add .unchecked (.local 1) (.constant (.int false 64 (1))))) <|
        .bind 8 (.scalar (.int false 64)) (.scalar (.cast .bitcast (.int false 64) (.local 2))) <|
        .bind 9 (.scalar (.int false 64)) (.scalar (.cast .bitcast (.int false 64) (.local 7))) <|
        .bind 10 (.scalar .bool) (.scalar (.comparison .ge (.local 8) (.local 9))) <|
        .branch (.local 10)
          (
            (.ret (.constant (.scalar (.int false 8 (0)))))
          )
          (
            (.jump 6 (.constant (.scalar .unit)))
          )
      ) <|
      .bind 14 (.scalar (.int false 64)) (.scalar (.arithmetic .add .unchecked (.local 1) (.constant (.int false 64 (1))))) <|
      .bind 15 (.pointer false true (.scalar (.int false 8))) (.load (.local 5)) <|
      .bind 16 (.pointer false true (.scalar (.int false 8))) (.offsetPointer false (.local 15) (.constant (.scalar (.int false 64 (0))))) <|
      .bind 17 (.scalar (.int false 64)) (.scalar (.arithmetic .sub .unchecked (.local 14) (.constant (.int false 64 (0))))) <|
      .bind 26 (.scalar .unit) (.checkBounds (.constant (.scalar (.int false 64 (0)))) (.local 14) .unbounded) <|
      .bind 18 (.slice false (.scalar (.int false 8))) (.slice (.slice false (.scalar (.int false 8))) (.local 16) (.local 17)) <|
      .bind 19 (.pointer true false (.slice false (.scalar (.int false 8)))) (.alloc (.slice false (.scalar (.int false 8)))) <|
      .bind 20 (.scalar .unit) (.store (.local 19) (.local 18)) <|
      .bind 21 (.pointer false false (.slice false (.scalar (.int false 8)))) (.pointerCast (.pointer false false (.slice false (.scalar (.int false 8)))) (.local 19)) <|
      .bind 22 (.slice false (.scalar (.int false 8))) (.load (.local 21)) <|
      .bind 23 (.pointer false false (.scalar (.int false 8))) (.sliceElementPointer (.local 22) (.local 2)) <|
      .bind 24 (.scalar (.int false 8)) (.load (.local 23)) <|
      (.ret (.local 24))
  }

end «Compiler».«Tutorial».«Ziglings».«Generated»
