# Explicit call-stack execution

The call-machine route represents every function body and call target
as data. Suspension retains the complete caller stack, including environments,
continuations and lifetime marks. `advance_add` proves that resuming two budgets
has exactly the same result as executing their sum.

```sh
zig build run -- translate --capture /path/to/capture/report.json \
  --root calls.update --profile calls --call-machine \
  --certify /tmp/calls-certificate --output /tmp/calls-model
```

The `calls`, `call-loops` and `nested-calls` admission profiles all emit this
representation by default. `--call-machine` is an optional explicit assertion
that the selected profile supports calls; it does not broaden admission.
Each generated definition has type `Function`;
`functions` is the complete table. `FunctionId.fn_name` names the checked table
index used by calls and proof entry points. Sequential instructions use Lean's
ordinary `<|` notation; branches and blocks indent their nested code. Captured
records follow the program definitions instead of interrupting them. The
manifest records each function's index.
The independent `CapturedCallMachine.decode` checks the whole table against
captured data. Calls must resolve a unique earlier declaration with matching
source identity, arity and return type. Recursion and forward dependencies reject.

For example, `MemoryCallMachine.run functions fuel root args state` produces a
finished result or a suspended configuration. Passing `.reuse` as its final
argument reclaims physical storage at invocation boundaries. The default
`.history` policy retains the previous address accounting. Both policies retain
fresh lifetime IDs; neither turns a dangling returned pointer into a live one.

`Safe`, `FaultFree`, `Terminates` and `Completes` distinguish memory-fault
exclusion, exclusion of every fault, termination with any result, and successful
completion. `Contract` quantifies over every finite observation. These predicates
do not establish source validity or native stack capacity.

The intraprocedural adapter has exact execution equivalence, including faults,
cleanup and loop suspension. `ofMemory_contract` transfers arbitrary existing
`Std.WP` contracts through that theorem. `ofMemory_contract_at` also handles a
checked entry in a larger function table. The [buffer client](../lean/Compiler/Tutorial/Buffer/Machine.lean)
uses it to preserve the existing contract without instruction-level proof work.

## Checked summaries and VC generation

Import `Compiler.ZigAir.Verify.Machine` for the machine's `Std.WP` interface.
`invoke functions root args` is a verification action over the existing
interpreter. Its WP covers every finite observation, including faults inside
callees. `sound` connects a checked triple to `advance`; `safe_of_spec` derives
memory safety when the fault postcondition permits only `.outOfMemory`.
The postconditions can also describe returned values and reached memory, so
the same interface supports manually proved functional properties.

`Contract.apply` reuses a previously proved procedure contract. The context
composition theorem attaches the real caller continuation to an isolated
callee execution. It preserves reached writes, unwinds faults with cleanup,
checks the caller's result type, and retains suspension. Both resource policies
use this theorem. A contract is a proved summary of the actual function table;
it is never substituted into the executable program.

`machine_vcgen` generates obligations for memory instructions, branches, blocks,
jumps, loops, direct calls and returns, reusing the existing atomic memory rules. The
[independent caller/helper client](../examples/client/calls/README.md) exercises
this interface against fresh generated functions. Its caller proof keeps the
helper body opaque and uses its contract. Synthetic controls also reject
fault-free contracts for a dangling pointer and a mismatched call result type.

For structured control, use `verify functions root arguments invariants` in the
triple. This denotes the same invocation as `invoke`; the invariant argument
selects a proof rule and does not change execution. Each loop requires an entry
assertion and a preservation proof. A back edge checks the invariant, while a
break carries the current locals and memory to its matching block. Invalid
conditions, result types and targets retain their fault obligations. The
[byte-scanning client](../examples/client/scan/README.md) combines a loop,
early returns, readonly memory and a separately checked helper.

The structural conditions are propositions over generated code. Their
soundness theorem connects them to every finite observation of the canonical
interpreter. Calls use the actual invocation WP. The proof accounts for the
call transition before using a continuation, so suspension cannot supply a
return value and a loop cannot assume its own safety. Both resource policies
share this proof. `machine_normalize` exposes client definitions and prepares
the shared memory automation; difficult obligations remain ordinary Lean goals.

The manual `invariant_spec` rule remains available for other execution
invariants, and intraprocedural proofs retain the exact `ofMemory_contract`
adapter. The [buffer client](../lean/Compiler/Tutorial/Buffer/Machine.lean)
uses this adapter to preserve its relational contract. Earlier finite and partial-target interpreters remain as regression models.
Production translation and tutorial clients use the call machine; equivalence
with those regression interpreters is not assumed. Invariant inference remains
open. `Bindings.argument`, `allocationOfType`,
`castToType` and `singleLoop` select invariant bindings from generated program
data and reject missing or ambiguous matches. `air_binding%` retains a
kernel-checked equality to each selection; static selection does not infer a
dynamic allocation lifetime.

`verify_at` selects a body using a proved table lookup, keeping unrelated
functions out of VC generation. `MemoryCallMachine.effects` proves heap validity
and preservation of existing allocation metadata across every observation,
including faults and suspension. Contents and initialization still require
the function's contract. `rootWritable_retained` specializes this preservation to
writable root capabilities, including suspension and faults under either resource policy.

## Termination of finite closures

Import `Compiler.ZigAir.MemoryCallMachineTermination` when termination is needed.
`Finite.infer` proposes structural costs for loop-free bodies and their call
dependencies. A separate `Finite.Valid` proof checks those costs against the
actual table; `Finite.terminates` connects the certificate to machine execution
for arbitrary inputs and states. The certificate covers branches, block exits,
calls and ordinary faults. It measures transitions, not native time or stack use.

Loops and recursive cycles cannot receive a finite structural certificate.
A finite helper can still be certified in a table containing looping functions.
The [Calls termination proof](../lean/Compiler/Tutorial/Calls/Proofs.lean)
checks the finite three-function closure. Looping clients still require a
separate progress argument.

## Validation

Fresh validation captured the three-function `calls.update` chain, compared
native objects and checked the emitted machine correspondence certificate.
Independent controls cover missing/duplicate identities, forward calls,
suspension inside a callee, fault unwinding with retained writes, cleanup and
dangling returns. The byte scan additionally passed a fresh call-loop capture,
certificate and safety proof replay. Its deliberately inclusive-bound variant
fails the unchanged safety proof; a separate checked execution witness proves
a reached one-past-the-end fault after a helper call and back edge. Native
compiler preservation remains a separate claim.
