# Phase 1: Single-Cycle RV32I CPU

## Goal

A functional, verified, single-cycle RV32I processor in SystemVerilog, with a measured FPGA baseline for later phases to compare against.

## Concepts

Datapath vs. control; instruction formats and immediates; register file ports; ALU operations and signedness; little-endian byte lanes; next-PC selection; exceptions; why single-cycle needs asynchronous memories; critical paths and slack.

## Implementation (authorship)

**Phase 1 RTL was written by Claude, at the student's explicit request** (2026-10-29), which overrides the default "student implements major blocks" rule for this phase. It started from the student's own drafts of `program_counter.sv` and `instruction_memory.sv`, which are preserved unchanged in [`student_drafts/`](student_drafts/). See decision D-101.

| Area | Files |
|------|-------|
| RTL | `rtl/*.sv` (14 files; `simple_adder.sv` is from Phase 0) |
| Testbenches | `tb/tb_*.sv`, `tb/tb_check.svh` |
| Programs | `tests/programs/*.S`, `crt0.S`, `link.ld` (+ generated `.hex`/`.sym`) |
| Reference model | `scripts/rv32i_iss.py` |
| Automation | `Makefile`, `scripts/*.sh`, `scripts/*.py`, `scripts/vivado/*.tcl` |
| Constraint | `constraints/timing_phase1.xdc` |

## Documentation

- [Architecture](../architecture.md)
- [SystemVerilog guide](../systemverilog_guide.md)
- [Instruction walkthrough](../instruction_walkthrough.md)
- [Verification](../verification.md)
- [Baseline](../baseline.md)
- [Interview guide](../phase1_interview_guide.md)

## Verification (run 2026-10-29)

- `make test`: 8/8 unit testbenches, 11/11 programs; RTL traces identical to the Python reference model.
- `make test-xsim`: the same, all passing in Vivado 2026.1 xsim.
- `make lint`: Icarus `-Wall` clean. Verilator is not installed (skipped).
- Fault injection: 14/14 planted bugs caught.

Saved output: `results/simulation/phase1_test_results.txt`.

## Measurements

Baseline B001 (`configs/baselines/B001_single_cycle.md`): 2,054 LUTs, 47 FFs, 0 latches; WNS −7.194 ns at 10 ns → estimated Fmax ≈ 58.2 MHz.

## Exit criteria

See [checklist.md](checklist.md).

## Reflection

See [learning_log.md](learning_log.md). The student's own reflection is still to be written.

## Milestone

Not yet committed. Suggested: commit Phase 1 after reviewing the diff, then update `configs/baselines/B001_single_cycle.md` with the commit hash.
