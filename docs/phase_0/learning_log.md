# Phase 0 Learning Log

Items marked *(student)* are for the student to write in their own words. Agents must not fill them in.

## Concepts I understand

- *(student)* WSL purpose:
- *(student)* C vs. SystemVerilog:
- *(student)* Compiler → assembly → machine code:
- *(student)* What a testbench does:

## Concepts I am still learning

- *(student)*

## Things I personally implemented

- `rtl/simple_adder.sv`: 32-bit combinational adder
- `tb/simple_adder_tb.sv`: testbench driving `5 + 3`
- `software/simple.c`: `add_numbers` + `main`
- *(student: add anything else)*

## Things agents/tools assisted with

- GCC generated `software/simple.s` from `software/simple.c`.
- An agent created the repository structure, `README.md`, `CLAUDE.md`, `AGENTS.md`, `agents/*.md`, Phase 0 docs, `results/` and `configs/baselines/` READMEs, and `.gitignore` (2026-10-29).
- An agent wrote `scripts/run_adder_sim.sh` (2026-10-29).

## Commands worth remembering

```bash
# Compile C to RV32I assembly
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -S software/simple.c -o software/simple.s

# Compile to an object file and view the machine code
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -c software/simple.c -o build/simple.o
riscv64-unknown-elf-objdump -d build/simple.o

# Simulate the adder with Icarus Verilog
iverilog -g2012 -o build/sim/adder.vvp rtl/simple_adder.sv tb/simple_adder_tb.sv
vvp build/sim/adder.vvp
# or
./scripts/run_adder_sim.sh
```

## Questions to revisit

- Why does the `-O0` assembly store arguments on the stack and immediately load them back?
- What happens in the adder when `a + b` overflows 32 bits?
- *(student)*

## Phase reflection

*(student: write this at the end of Phase 0. What worked, what was confusing, what you would do differently.)*
