# 07. Simulation and Verification

## Why waveforms are not enough

A waveform shows one execution. It is useful for seeing signal timing but does
not automatically say whether a result was correct. A self-checking testbench
compares actual values to expected values and exits with a clear pass/fail
result.

Verification should be layered:

1. **Unit tests** isolate one block, such as the ALU or immediate generator.
2. **Directed programs** execute instruction sequences on the full CPU.
3. **Reference-model comparison** checks the RTL's architectural trace against
   an independent software model.
4. **Additional tools** such as a second simulator, official ISA tests, random
   testing, and formal proofs provide different forms of evidence.

No single layer proves everything. A correct final `a0` can hide an incorrect
intermediate register value, so traces and corner cases matter.

## What a testbench does

A testbench instantiates the design, drives clocks/resets and inputs, loads a
program, waits for completion, and checks outputs. It may write a VCD waveform
for inspection. Simulation-only features belong in testbench code, not the
synthesizable CPU.

## Directed and randomized tests

Directed tests target known tricky cases: shift amount 31, signed minimum
versus unsigned maximum, x0 writes, negative branch offsets, every byte lane,
JALR bit clearing, and faults at the end of memory. Random tests explore many
input combinations, but only help when an independent checker can identify
wrong results.

## Differential testing

The Python reference model executes the same hex program as the RTL. The test
runner compares each retired instruction and state change. A useful mismatch
report names the first differing record and includes nearby history.

For a future pipeline, cycle numbers must be ignored: instruction order and
architectural effects must match the single-cycle core. Do compare PC,
instruction, destination/value, store address/data/byte enables, and final
state. A trap must identify the same PC, cause, and value.

## Fault injection and coverage

Fault injection means deliberately introducing a known bug in a disposable
copy and checking that the test suite catches it. This demonstrates that tests
can detect certain mistakes. It does not prove every possible bug is covered.

Keep track of what each test exercises and what it does not. For example, the
current directed programs are small; they do not replace long software runs,
official compliance tests, or formal verification.

## Running the project checks

```sh
make test-unit
make test-core
make test
make lint
```

Run tests after RTL changes and save actual command output. Never copy an old
PASS log and present it as a new run.

## Check your understanding

1. What can a waveform show that a self-checking test cannot?
2. Why should the reference model be structurally independent of the RTL?
3. Why compare every retirement record instead of only final memory and
   registers?
4. What does a fault-injection result establish, and what does it not establish?

## In this repository

See [`../verification.md`](../verification.md),
[`../../scripts/run_core_tests.py`](../../scripts/run_core_tests.py), and
[`../../scripts/rv32i_iss.py`](../../scripts/rv32i_iss.py).
