/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
Generated from admitted AIR; do not edit.
Source validity and native refinement require separate evidence.
-/
-- Source SHA-256: 41f67e6cf358628827fa8cab618048d11eb0477710bb72449153163c68eee4bf
-- Capture report SHA-256: cccda0a6cba0a9feacf7f357861112c146a1981c9876e6979c8cc805d82cf4ec
import Compiler.ZigAir.Scalar

namespace «Compiler».«Tutorial».«Counter».«V2».«Generated»
open Compiler.ZigAir.Scalar

-- AIR SHA-256: 51ecf7dbb885c94d49cd432a1aed0e9bae4aed509f25a14cf6a4b6ecc6b10962
def fn_advance : Program :=
{ parameters := [(.int false 8)], returnType := (.int false 8), body :=
  (.bind 0 (.int false 8)
  (.argument 0)
  (.block 1 (.int false 8)
  (.bind 2 .bool
  (.comparison .lt (.local 0) (.constant (.int false 8 (254))))
  (.branch (.local 2)
  (.bind 3 (.int false 8)
  (.arithmetic .add .unchecked (.local 0) (.constant (.int false 8 (2))))
  (.jump 1 (.local 3)))
  (.jump 1 (.constant (.int false 8 (255))))))
  (.ret (.local 1)))) }

end «Compiler».«Tutorial».«Counter».«V2».«Generated»
