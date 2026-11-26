/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
Generated from admitted AIR; do not edit.
Source validity and native refinement require separate evidence.
-/
-- Source SHA-256: 4baa54571d04d4cb049a4e9023c0d97b7f9f9ea29eff6896dc571dffb9ffac9c
-- Capture report SHA-256: f200be71fbc6e1687b2ed3b348daf9388b8fb7fd2c7564b2f0de903a659e90c4
import Compiler.ZigAir.Scalar

namespace «Compiler».«Tutorial».«Counter».«Broken».«Generated»
open Compiler.ZigAir.Scalar

-- AIR SHA-256: 3a8bfcca0899e535fbb490338e2ebafbaba1f759e8515afd923073b57cbbbd0c
def fn_advance : Program :=
  { parameters := [(.int false 8)],
    returnType := (.int false 8),
    body :=
      .bind 0 (.int false 8) (.argument 0) <|
      .block 1 (.int false 8) (
        .bind 2 .bool (.comparison .lt (.local 0) (.constant (.int false 8 (255)))) <|
        .branch (.local 2)
          (
            .bind 3 (.int false 8) (.arithmetic .add .unchecked (.local 0) (.constant (.int false 8 (2)))) <|
            (.jump 1 (.local 3))
          )
          (
            (.jump 1 (.constant (.int false 8 (255))))
          )
      ) <|
      (.ret (.local 1))
  }

end «Compiler».«Tutorial».«Counter».«Broken».«Generated»
