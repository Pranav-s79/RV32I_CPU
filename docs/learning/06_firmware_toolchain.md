# 06. Firmware and the RISC-V Toolchain

## Software becomes instruction words

The compiler and assembler translate source code into machine instructions.
The linker assigns addresses and combines code and data into an ELF file. The
simulator or FPGA memory needs a format it can load, commonly a text hex file
with one 32-bit instruction per line.

```text
C / assembly → compiler → object files → linker → ELF → hex → instruction memory
```

The RTL does not execute C directly. It fetches the 32-bit words produced by
the toolchain.

## The compiler contract

Tell the compiler exactly which instructions and ABI the core supports:

```sh
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -O0 -S source.c -o source.s
```

`-march=rv32i` prevents extensions such as multiplication from appearing.
`-mabi=ilp32` describes 32-bit integers, longs, and pointers. Optimization
level changes generated instruction sequences, but must not change program
meaning. During bring-up, inspect disassembly when a program uses an
unsupported instruction.

## Startup and the linker

Bare-metal programs have no operating system to set up a stack or call `main`.
A small startup routine establishes the stack pointer and calls `main`. The
linker script places program sections at addresses the CPU can fetch. `.text`
contains instructions, `.rodata` constants, `.data` initialized writable
data, and `.bss` zero-initialized data.

The current teaching programs use a simple image and constrained memory map.
If startup code is extended to use globals, it must copy initialized data to
RAM and clear `.bss`; merely defining these sections in a linker script does
not initialize them at run time.

## ELF to hex

ELF contains machine code plus symbols and address metadata. `objdump -d`
shows instructions with their addresses. `objcopy -O binary` extracts a flat
load image. A converter groups bytes into 32-bit words and accounts for
little-endian byte order so `$readmemh` loads the intended instruction.

Useful repository commands include:

```sh
make programs
make test-core
```

The first rebuilds the test images with the configured RISC-V toolchain. The
second runs those images on the RTL and compares the trace with the reference
model.

## Program termination and test results

The current test programs terminate using `ECALL` and place their result in
`a0` (`x10`). The testbench checks the halt/trap cause and expected result.
This is a controlled simulation convention, not a general operating-system
ABI. The guide's later `tohost` convention and UART are possible alternatives
when the software/RTL contract is deliberately extended.

## Check your understanding

1. What does the compiler do that the RTL simulator does not?
2. Why specify both `-march` and `-mabi`?
3. What does the linker script decide?
4. Why inspect disassembly when a C program traps as illegal?

## In this repository

See [`../phase_0/README.md`](../phase_0/README.md),
[`../../scripts/build_programs.py`](../../scripts/build_programs.py),
[`../../tests/programs/crt0.S`](../../tests/programs/crt0.S), and
[`../../tests/programs/link.ld`](../../tests/programs/link.ld).
