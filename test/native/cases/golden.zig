// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
// Immutable reference controls with shared fixtures and explicit mutations.
const f = @import("../fixtures.zig");

pub const air_scalar_program_1_output_11 = f.s(
    \\{ parameters := [(.int false 8)], returnType := (.int false 8), body :=
    \\  (.bind 0 (.int false 8)
    \\  (.argument 0)
    \\  (.block 1 (.int false 8)
    \\  (.bind 2 .bool
    \\  (.comparison .lt (.local 0) (.constant (.int false 8 (128))))
    \\  (.branch (.local 2)
    \\  (.bind 4 (.int false 8)
    \\  (.arithmetic .add .unchecked (.local 0) (.constant (.int false 8 (1))))
    \\  (.jump 1 (.local 4)))
    \\  (.jump 1 (.local 0))))
    \\  (.ret (.local 1)))) }
);

pub const air_memory_program_2_output_30 = f.s(
    \\{ parameters := [(.pointer false true (.scalar (.int false 8))), (.scalar (.int false 64))], returnType := (.scalar (.int false 64)), body :=
    \\  (.bind 0 (.pointer false true (.scalar (.int false 8)))
    \\  (.argument 0)
    \\  (.bind 1 (.scalar (.int false 64))
    \\  (.argument 1)
    \\  (.bind 4 (.scalar .unit)
    \\  (.checkBounds (.constant (.scalar (.int false 64 (0)))) (.local 1) .unbounded)
    \\  (.bind 2 (.slice false (.scalar (.int false 8)))
    \\  (.slice (.slice false (.scalar (.int false 8))) (.local 0) (.local 1))
    \\  (.ret (.constant (.scalar (.int false 64 (1))))))))) }
);

pub const air_aggregate_program_4_output_50 = f.s(
    \\{ parameters := [(.scalar (.int false 64))], returnType := (.aggregate "fixture.Pair" ⟨16, 8⟩ [(0, (.scalar (.int false 64))), (8, (.scalar (.int false 64)))]), body :=
    \\  (.bind 0 (.scalar (.int false 64))
    \\  (.argument 0)
    \\  (.bind 1 (.pointer true false (.aggregate "fixture.Pair" ⟨16, 8⟩ [(0, (.scalar (.int false 64))), (8, (.scalar (.int false 64)))]))
    \\  (.memory (.alloc (.aggregate "fixture.Pair" ⟨16, 8⟩ [(0, (.scalar (.int false 64))), (8, (.scalar (.int false 64)))])))
    \\  (.bind 2 (.scalar .unit)
    \\  (.store (.local 1) (.constant (.aggregate (.aggregate "fixture.Pair" ⟨16, 8⟩ [(0, (.scalar (.int false 64))), (8, (.scalar (.int false 64)))]) [(0, (.scalar (.int false 64 (0))))])))
    \\  (.bind 3 (.pointer true false (.scalar (.int false 64)))
    \\  (.fieldPointer (.local 1) 0)
    \\  (.bind 4 (.scalar .unit)
    \\  (.store (.local 3) (.local 0))
    \\  (.bind 5 (.aggregate "fixture.Pair" ⟨16, 8⟩ [(0, (.scalar (.int false 64))), (8, (.scalar (.int false 64)))])
    \\  (.load (.local 1))
    \\  (.ret (.local 5)))))))) }
);

pub const air_word_bytes_program_6_output_77 = f.s(
    \\{ parameters := [(.pointer true false (.scalar (.int false 32))), (.scalar (.int false 64)), (.scalar (.int false 8))], returnType := (.scalar .unit), body :=
    \\  (.bind 0 (.pointer true false (.scalar (.int false 32)))
    \\  (.argument 0)
    \\  (.bind 1 (.scalar (.int false 64))
    \\  (.argument 1)
    \\  (.bind 2 (.scalar (.int false 8))
    \\  (.argument 2)
    \\  (.bind 3 (.pointer true true (.scalar (.int false 8)))
    \\  (.wordByteCast true true 4 (.local 0))
    \\  (.bind 4 (.slice true (.scalar (.int false 8)))
    \\  (.slice (.slice true (.scalar (.int false 8))) (.local 3) (.constant (.scalar (.int false 64 (4)))))
    \\  (.bind 5 (.pointer true false (.slice true (.scalar (.int false 8))))
    \\  (.alloc (.slice true (.scalar (.int false 8))))
    \\  (.bind 6 (.scalar .unit)
    \\  (.store (.local 5) (.local 4))
    \\  (.bind 7 (.pointer false false (.slice true (.scalar (.int false 8))))
    \\  (.pointerCast (.pointer false false (.slice true (.scalar (.int false 8)))) (.local 5))
    \\  (.bind 8 (.slice true (.scalar (.int false 8)))
    \\  (.load (.local 7))
    \\  (.bind 9 (.pointer true false (.scalar (.int false 8)))
    \\  (.sliceElementPointer (.local 8) (.local 1))
    \\  (.bind 10 (.scalar (.int false 8))
    \\  (.wordByteLoad .little (.local 9))
    \\  (.ret (.constant (.scalar .unit)))))))))))))) }
);

pub const air_loops_program_7_output_85 = f.s(
    \\{ parameters := [(.scalar (.int false 8))], returnType := (.scalar (.int false 8)), body :=
    \\  (.bind 0 (.scalar (.int false 8))
    \\  (.argument 0)
    \\  (.block 1 (.scalar (.int false 8))
    \\  (.loop rfl 2
    \\  (.bind 3 (.scalar .bool)
    \\  (.scalar (.comparison .lt (.local 0) (.constant (.int false 8 (128)))))
    \\  (.branch (.local 3)
    \\  (.bind 5 (.scalar (.int false 8))
    \\  (.scalar (.arithmetic .add .unchecked (.local 0) (.constant (.int false 8 (1)))))
    \\  (.repeat rfl 2))
    \\  (.jump 1 (.local 0)))))
    \\  (.ret (.local 1)))) }
);

pub const air_word_byte_loops_program_8_output_88 = f.s(
    \\{ parameters := [(.scalar (.int false 8))], returnType := (.scalar (.int false 8)), body :=
    \\  (.bind 0 (.scalar (.int false 8))
    \\  (.argument 0)
    \\  (.block 1 (.scalar (.int false 8))
    \\  (.bind 2 (.scalar .bool)
    \\  (.scalar (.comparison .lt (.local 0) (.constant (.int false 8 (128)))))
    \\  (.branch (.local 2)
    \\  (.bind 4 (.scalar (.int false 8))
    \\  (.scalar (.arithmetic .add .unchecked (.local 0) (.constant (.int false 8 (1)))))
    \\  (.jump 1 (.local 4)))
    \\  (.jump 1 (.local 0))))
    \\  (.ret (.local 1)))) }
);

pub const air_scalar_constant_9_output_91 = f.s("(.constant (.int false 512 (13407807929942597099574024998205846127479365820592393377723561443721764030073546976801874298166903427690031858186486050853753882811946569946433649006084095)))");

pub const air_scalar_constant_11_output_96 = f.s("(.constant (.int true 512 (-6703903964971298549787012499102923063739682910296196688861780721860882015036773488400937149083451713845015929093243025426876941405973284973216824503042048)))");

pub const air_scalar_program_12_output_103 = f.s(
    \\{ parameters := [(.int false 0)], returnType := (.int false 0), body :=
    \\  (.bind 0 (.int false 0)
    \\  (.argument 0)
    \\  (.bind 1 (.int false 0)
    \\  (.bitAnd (.local 0) (.constant (.int false 0 (0))))
    \\  (.ret (.local 1)))) }
);

pub const air_scalar_program_13_output_111 = f.s(
    \\{ parameters := [(.int false 1)], returnType := (.int false 1), body :=
    \\  (.bind 0 (.int false 1)
    \\  (.argument 0)
    \\  (.bind 1 (.int false 1)
    \\  (.shiftRight (.local 0) (.constant (.int false 0 (0))))
    \\  (.ret (.constant (.int false 1 (0)))))) }
);

pub const air_loops_program_21_output_141 = f.s(
    \\{ parameters := [(.pointer false true (.scalar (.int false 8))), (.scalar (.int false 64))], returnType := (.scalar (.int false 64)), body :=
    \\  (.bind 0 (.pointer false true (.scalar (.int false 8)))
    \\  (.argument 0)
    \\  (.bind 1 (.scalar (.int false 64))
    \\  (.argument 1)
    \\  (.bind 2 (.pointer false false (.scalar (.int false 8)))
    \\  (.elementPointer (.local 0) (.local 1))
    \\  (.ret (.constant (.scalar (.int false 64 (1)))))))) }
);

pub const air_loops_program_22_output_146 = f.s(
    \\{ parameters := [(.scalar (.int false 8))], returnType := (.scalar (.int false 8)), body :=
    \\  (.bind 0 (.scalar (.int false 8))
    \\  (.argument 0)
    \\  (.block 1 (.scalar (.int false 8))
    \\  (.loop rfl 2
    \\  (.loop rfl 9
    \\  (.bind 3 (.scalar .bool)
    \\  (.scalar (.comparison .lt (.local 0) (.constant (.int false 8 (128)))))
    \\  (.branch (.local 3)
    \\  (.bind 5 (.scalar (.int false 8))
    \\  (.scalar (.arithmetic .add .unchecked (.local 0) (.constant (.int false 8 (1)))))
    \\  (.repeat rfl 2))
    \\  (.repeat rfl 9)))))
    \\  (.ret (.local 1)))) }
);

pub const air_aggregate_program_26_output_162 = f.s(
    \\{ parameters := [(.scalar (.int false 8))], returnType := (.scalar (.int false 8)), body :=
    \\  (.bind 0 (.scalar (.int false 8))
    \\  (.argument 0)
    \\  (.block 1 (.scalar (.int false 8))
    \\  (.bind 2 (.scalar .bool)
    \\  (.memory (.scalar (.comparison .lt (.local 0) (.constant (.int false 8 (128))))))
    \\  (.branch (.local 2)
    \\  (.bind 4 (.scalar (.int false 8))
    \\  (.memory (.scalar (.arithmetic .add .unchecked (.local 0) (.constant (.int false 8 (1))))))
    \\  (.jump 1 (.local 4)))
    \\  (.jump 1 (.local 0))))
    \\  (.ret (.local 1)))) }
);

// Expected native output embeds the synthetic captured initializer explicitly.

pub const word_fixture_0_output_1124 = f.s(
    \\{ program :=
    \\  { parameters := [(.pointer true false (.scalar (.int false 32))), (.pointer true false (.scalar (.int false 32)))], returnType := (.scalar .unit), body :=
    \\  (.bind 0 (.pointer true false (.scalar (.int false 32)))
    \\  (.argument 0)
    \\  (.bind 1 (.pointer true false (.scalar (.int false 32)))
    \\  (.argument 1)
    \\  (.ret (.constant (.scalar .unit))))) } }
);
