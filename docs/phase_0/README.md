# Phase 0 — Development Environment and Toolchain Validation

## Goal

Establish a reproducible development environment and prove that both the software and RTL toolchains work before building the CPU.

## Concepts

- Why WSL2 is used (Linux tooling on a Windows host).
- C vs. SystemVerilog: software that runs *on* the CPU vs. hardware that *is* the CPU.
- The software flow: C → compiler → assembly → assembler → object/machine code.
- The RTL flow: SystemVerilog → simulator (check behavior) → synthesis (map to FPGA).
- What a testbench is: non-synthesizable code that drives inputs and checks outputs.

## Current environment

Versions marked *verified* were checked from the command line on 2026-10-29. The rest were reported by the student.

| Item | Status | Details |
|------|--------|---------|
| WSL2 Ubuntu | Verified | Ubuntu 22.04.5 LTS |
| VS Code connected to WSL | Reported | VS Code server present in WSL |
| Git | Verified | git 2.34.1 (WSL) |
| RISC-V GCC | Verified | `riscv64-unknown-elf-gcc` 10.2.0 |
| RISC-V binutils | Verified | `riscv64-unknown-elf-as`, `riscv64-unknown-elf-objdump` present |
| Icarus Verilog | Verified | 11.0 (stable) |
| Vivado | Install found | `C:\Xilinx\Vivado\2023.1` and `C:\AMDDesignTools\2026.1\Vivado`. Which one is used is still to be confirmed |
| Vivado BASIC license | Reported | Not verified from the command line |

## Work completed

| Item | Evidence |
|------|----------|
| C program written | `software/simple.c` |
| C compiled to RV32I assembly | `software/simple.s` (`.attribute arch, "rv32i2p0"`, GCC 10.2.0) |
| Simple 32-bit adder created | `rtl/simple_adder.sv` |
| Adder testbench created | `tb/simple_adder_tb.sv` |
| Lightweight RTL simulation workflow | Icarus Verilog; `scripts/run_adder_sim.sh` (agent-written helper) |

### Adder simulation status

On 2026-10-29 an agent compiled and ran the adder with Icarus Verilog 11.0:

```
$ iverilog -g2012 -o adder.vvp rtl/simple_adder.sv tb/simple_adder_tb.sv && vvp -n adder.vvp
a = 5, b = 3, sum = 8
```

The output is correct for this single input. However, the testbench **is not self-checking**: it prints the result but never compares it to an expected value, so it cannot report PASS or FAIL. The student still needs to run the simulation and confirm it (see checklist).

## Student implementation

- `rtl/simple_adder.sv`, `tb/simple_adder_tb.sv`, `software/simple.c`

## Agent assistance

- Repository structure, documentation, agent policy files, `.gitignore`.
- `scripts/run_adder_sim.sh` (helper script; does not modify RTL).

## Verification

- Icarus simulation of the adder (see above).
- Vivado simulation or elaboration of the same adder (not yet done).

## Measurements

None in Phase 0.

## Remaining work

- [ ] Student runs the adder simulation and confirms the output.
- [ ] (Optional exercise) Make the testbench self-checking with several vectors, including overflow (`0xFFFFFFFF + 1`).
- [ ] Confirm Vivado accepts and simulates the adder.
- [ ] Inspect object-file disassembly (`objdump -d`).
- [ ] Decide which Vivado version to use and record it in `decisions.md`.
- [ ] Clean Git state.
- [ ] Fill in the learning log.
- [ ] Save the Phase 0 milestone commit.

## Exit criteria

All items in [checklist.md](checklist.md) are checked, with evidence.

## Reflection

See [learning_log.md](learning_log.md).

## Milestone

Phase 0 milestone commit: *not yet created*.
