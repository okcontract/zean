/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
Generated from admitted AIR; do not edit.
Source validity and native refinement require separate evidence.
-/
-- Source SHA-256: 5982a1e64168a7ccd82784e0d13e8a765d95334c9953375e77c1813fb97b1e4f
-- Capture report SHA-256: 802bb4ccacaa620e21ae327012617ffd78750b95dc191f04849901bde509ba17
import Compiler.ZigAir.Scalar

namespace «Compiler».«Tutorial».«Counter».«V1».«Generated»
open Compiler.ZigAir.Scalar

-- AIR SHA-256: bf96d9a43184d3c39e0d3baab9385eeed5851d6fa1248867e993f216073673a3
def fn_advance : Program :=
{ parameters := [(.int false 8)], returnType := (.int false 8), body :=
  (.bind 0 (.int false 8)
  (.argument 0)
  (.block 1 (.int false 8)
  (.bind 2 .bool
  (.comparison .lt (.local 0) (.constant (.int false 8 (255))))
  (.branch (.local 2)
  (.bind 3 (.int false 8)
  (.arithmetic .add .unchecked (.local 0) (.constant (.int false 8 (1))))
  (.jump 1 (.local 3)))
  (.jump 1 (.constant (.int false 8 (255))))))
  (.ret (.local 1)))) }

end «Compiler».«Tutorial».«Counter».«V1».«Generated»
