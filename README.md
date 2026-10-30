# RV32I CPU

A learning-focused implementation of a 32-bit RISC-V RV32I processor in SystemVerilog.

## Target

- Board: Zybo Z7-10
- FPGA: Zynq XC7Z010
- Tools: Vivado (Windows), RISC-V GCC + Icarus Verilog (WSL2 Ubuntu 22.04)

## Roadmap

| Phase | Focus |
|-------|-------|
| 0 | Development environment and toolchain validation |
| 1 | Single-cycle RV32I CPU |
| 2 | Functional verification and software execution |
| 3 | 5-stage pipeline |
| 4 | Hazard detection and forwarding |
| 5 | ISA/reference verification |
| 6 | FPGA implementation and baseline characterization |
| 7 | Performance and area optimization |
| 8 | Final benchmarking, documentation, and resume results |

Current phase: **Phase 1 complete (pending student review and milestone commit)**: a single-cycle RV32I CPU, verified in simulation, with a measured Vivado baseline. See [`docs/phase_1/`](docs/phase_1/README.md).

## Phase 1 status

| | |
|-|-|
| ISA | RV32I: all 37 computational/memory/control instructions + FENCE, ECALL, EBREAK; illegal-instruction and misaligned/access-fault detection (trap = halt) |
| Verification | 8 self-checking unit testbenches; 11 programs (incl. a C program) traced instruction-by-instruction against a Python reference model; passing in Icarus 11 and Vivado xsim |
| Baseline (B001) | 2,054 LUTs, 47 FFs, 0 latches; WNS −7.194 ns @ 10 ns → est. Fmax ≈ 58 MHz; CPI = 1 |
| Docs | [architecture](docs/architecture.md) · [SystemVerilog guide](docs/systemverilog_guide.md) · [instruction walkthrough](docs/instruction_walkthrough.md) · [verification](docs/verification.md) · [baseline](docs/baseline.md) · [interview guide](docs/phase1_interview_guide.md) |

## Software vs. hardware

This repository contains two very different kinds of code:

- **Software / C** (`software/`): programs that eventually run *on* the processor. They are compiled by RISC-V GCC into RV32I machine code.
- **SystemVerilog / RTL** (`rtl/`, `tb/`): a hardware description used to *create* the processor. It is simulated (Icarus Verilog, Vivado) and synthesized onto the FPGA.

The C code is the passenger; the RTL is the vehicle.

## Repository layout

```
rtl/          SystemVerilog design sources
tb/           Testbenches
tests/        Test programs (assembly, linker script, .hex images)
software/     C / assembly programs that run on the CPU
scripts/      Test runners, reference model, Vivado Tcl
constraints/  Vivado constraint files (.xdc)
configs/      Build configurations and recorded baselines
results/      Selected simulation, synthesis, and timing summaries
docs/         Phase docs, architecture notes, decisions, experiments
agents/       Role definitions for AI assistants
```

## Quick start

```bash
make test           # all unit tests + programs vs. reference model (Icarus Verilog)
make test-alu       # one unit test (also: test-pc, test-registers, test-imm, test-control,
                    #                test-branch, test-nextpc, test-lsu, test-core)
make test-xsim      # the same tests in Vivado's simulator
make lint           # elaboration with all warnings
make programs       # rebuild tests/programs/*.hex (needs RISC-V GCC)
make synth          # Vivado synthesis + implementation baseline
make vivado-project # Vivado GUI project in build/vivado/rv32i_phase1/
```

Vivado is called from WSL through `cmd.exe`; the path is set by `VIVADO` in the `Makefile`.

### Opening the design in Vivado

1. Run `make vivado-project` (or, in the Vivado Tcl console: `cd C:/Users/prana/RV32i_cpu` then `source scripts/vivado/create_project.tcl`).
2. Open `build/vivado/rv32i_phase1/rv32i_phase1.xpr`.
3. *Run Simulation → Run Behavioral Simulation* runs `tb_rv32i_core` on `rv32i_full.hex`; the Tcl console prints `PASS: tb_rv32i_core`.
4. *Open Elaborated Design → Schematic* shows the module structure. *Run Synthesis* (out-of-context) and *Report Timing Summary* show the critical path.

## Project philosophy

- **Correctness first.** A fast CPU that gives wrong answers is worthless.
- **Measurable engineering claims.** Every performance or area claim is backed by a recorded measurement.
- **Baseline before optimization.** Characterize the simple design before changing it.
- **Student implements the architecture.** Major CPU blocks are written by the student; AI agents explain, review, test, and automate. (Exception: Phase 1 RTL was written by Claude at the student's request, starting from the student's drafts. See `docs/phase_1/decisions.md`, D-101.)

See [`AGENTS.md`](AGENTS.md) for how AI assistants are used in this project.
