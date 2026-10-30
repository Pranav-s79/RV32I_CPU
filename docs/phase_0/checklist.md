# Phase 0 Checklist

Only check an item when there is evidence for it (command output, a file in the repo, or the student's own confirmation).

## Environment

- [x] Vivado installed
- [x] Vivado BASIC license configured
- [x] WSL2 Ubuntu configured
- [x] VS Code connected to WSL
- [x] Git installed
- [x] RISC-V GCC installed
- [x] RISC-V binutils installed
- [x] Lightweight RTL simulator installed or configured (Icarus Verilog 11.0)

## Software toolchain

- [x] Write simple C program (`software/simple.c`)
- [x] Compile C to RV32I assembly (`software/simple.s`)
- [ ] Inspect object disassembly if not already verified

## RTL toolchain

- [x] Create simple 32-bit adder (`rtl/simple_adder.sv`)
- [x] Create adder testbench (`tb/simple_adder_tb.sv`)
- [ ] Confirm lightweight simulation passes
  - Agent run on 2026-10-29 printed `a = 5, b = 3, sum = 8` (correct). Testbench is not self-checking. Student to run and confirm.
- [x] Confirm Vivado simulation or compile flow works
  - 2026-10-29: Vivado 2026.1 xsim ran all Phase 1 testbenches, and synthesis/implementation completed (Phase 1). The adder itself was not run in Vivado.

## Infrastructure

- [ ] Confirm Git repo clean
- [x] Create root README
- [x] Create agent infrastructure (`AGENTS.md`, `CLAUDE.md`, `agents/`)
- [x] Create phase documentation (`docs/phase_0/`)
- [x] Create baseline/result folders (`configs/baselines/`, `results/`)
- [ ] Create Phase 0 milestone commit

## Understanding

- [x] Understand WSL purpose
- [x] Understand C vs SystemVerilog
- [x] Understand compiler → assembly → machine code flow
- [x] Understand basic testbench purpose
- [ ] Explain complete Phase 0 tool flow without notes
