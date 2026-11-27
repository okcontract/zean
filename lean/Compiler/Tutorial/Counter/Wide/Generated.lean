/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
Generated from admitted AIR; do not edit.
Source validity and native refinement require separate evidence.
-/
-- Source SHA-256: 8f942c47ebb9e5dbe774c3a8779379e68e84a5da9f77f7b4a91d8e86f027d350
-- Capture report SHA-256: b557c1232d00bdb2fdc9cd427af8abbeff63dc0db95018a4467430df54eb82b3
import Compiler.ZigAir.Scalar

namespace «Compiler».«Tutorial».«Counter».«Wide».«Generated»
open Compiler.ZigAir.Scalar

-- AIR SHA-256: eb4bbfcff4557bb4d3c7340fa16a8ea16f3dd1a7c4e35380908051ed28051ae7
def fn_advance : Program :=
  { parameters := [(.int false 32)],
    returnType := (.int false 32),
    body :=
      .bind 0 (.int false 32) (.argument 0) <|
      .block 1 (.int false 32) (
        .bind 2 .bool (.comparison .lt (.local 0) (.constant (.int false 32 (4294967294)))) <|
        .branch (.local 2)
          (
            .bind 3 (.int false 32) (.arithmetic .add .unchecked (.local 0) (.constant (.int false 32 (2)))) <|
            (.jump 1 (.local 3))
          )
          (
            (.jump 1 (.constant (.int false 32 (4294967295))))
          )
      ) <|
      (.ret (.local 1))
  }

end «Compiler».«Tutorial».«Counter».«Wide».«Generated»
