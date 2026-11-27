/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
Generated from admitted AIR; do not edit.
Source validity and native refinement require separate evidence.
-/
-- Source SHA-256: db78007af4878dd75a0fc1c24f1fdb90f44f2d15c4c6177c43e388262a17a44e
-- Capture report SHA-256: b26ecc3e79ffffc829e27835107ac4f7ae6b2d77cf89026630d955bc4d42d427
import Compiler.ZigAir.MemoryExecution

namespace «Compiler».«Components».«Replace».«Generated»
open Compiler.ZigAir.MemoryAir

-- AIR SHA-256: bfa561e354ce7910b34f1e54c5da0597a861829c4d97d1503240e8c5d4d7801a
def fn_replaceScalar__func_0 : Program true :=
  { parameters := [(.slice true (.scalar (.int false 32))), (.scalar (.int false 32)), (.scalar (.int false 32))],
    returnType := (.scalar .unit),
    body :=
      .bind 0 (.slice true (.scalar (.int false 32))) (.argument 0) <|
      .bind 1 (.scalar (.int false 32)) (.argument 1) <|
      .bind 2 (.scalar (.int false 32)) (.argument 2) <|
      .bind 3 (.pointer true false (.scalar (.int false 64))) (.alloc (.scalar (.int false 64))) <|
      .bind 4 (.scalar .unit) (.store (.local 3) (.constant (.scalar (.int false 64 (0))))) <|
      .bind 5 (.scalar (.int false 64)) (.sliceLen (.local 0)) <|
      .block 6 (.scalar .unit) (
        .loop rfl 7 <|
        .bind 8 (.scalar (.int false 64)) (.load (.local 3)) <|
        .block 9 (.scalar .unit) (
          .bind 10 (.scalar (.int false 64)) (.scalar (.cast .bitcast (.int false 64) (.local 8))) <|
          .bind 11 (.scalar (.int false 64)) (.scalar (.cast .bitcast (.int false 64) (.local 5))) <|
          .bind 12 (.scalar .bool) (.scalar (.comparison .lt (.local 10) (.local 11))) <|
          .branch (.local 12)
            (
              .bind 13 (.pointer true false (.scalar (.int false 32))) (.sliceElementPointer (.local 0) (.local 8)) <|
              .block 14 (.scalar .unit) (
                .bind 15 (.scalar (.int false 32)) (.load (.local 13)) <|
                .bind 16 (.scalar .bool) (.scalar (.comparison .eq (.local 15) (.local 1))) <|
                .branch (.local 16)
                  (
                    .bind 17 (.scalar .unit) (.store (.local 13) (.local 2)) <|
                    (.jump 14 (.constant (.scalar .unit)))
                  )
                  (
                    (.jump 14 (.constant (.scalar .unit)))
                  )
              ) <|
              (.jump 9 (.constant (.scalar .unit)))
            )
            (
              (.jump 6 (.constant (.scalar .unit)))
            )
        ) <|
        .bind 24 (.scalar (.int false 64)) (.scalar (.arithmetic .add .unchecked (.local 8) (.constant (.int false 64 (1))))) <|
        .bind 25 (.scalar .unit) (.store (.local 3) (.local 24)) <|
        (.repeat rfl 7)
      ) <|
      (.ret (.constant (.scalar .unit)))
  }

end «Compiler».«Components».«Replace».«Generated»
