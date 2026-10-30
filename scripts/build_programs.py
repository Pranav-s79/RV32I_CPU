#!/usr/bin/env python3
"""Assemble/compile test programs into instruction-memory images.

For each program this writes, in tests/programs/:
  <name>.hex  one 32-bit little-endian word per line, for $readmemh
  <name>.sym  symbol table (address, name) from nm
and a disassembly to build/programs/<name>.dump for debugging.

Programs:
  every tests/programs/*.S except crt0.S  -> assembled on its own
  c_simple                                -> crt0.S + software/simple.c

Requires riscv64-unknown-elf-gcc / objcopy / objdump / nm on PATH.
"""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROG_DIR = ROOT / "tests" / "programs"
OUT_DIR = ROOT / "build" / "programs"
PREFIX = "riscv64-unknown-elf-"
CFLAGS = ["-march=rv32i", "-mabi=ilp32", "-nostdlib", "-nostartfiles",
          "-ffreestanding", "-O0", "-T", str(PROG_DIR / "link.ld")]
IMEM_BYTES = 4096


def run(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(f"command failed: {' '.join(cmd)}\n{result.stdout}{result.stderr}")
    return result.stdout


def build(name, sources):
    elf = OUT_DIR / f"{name}.elf"
    run([PREFIX + "gcc", *CFLAGS, *map(str, sources), "-o", str(elf)])

    # Refuse programs that need initialized data memory (nothing loads it).
    for line in run([PREFIX + "objdump", "-h", str(elf)]).splitlines():
        parts = line.split()
        if len(parts) >= 3 and parts[1] == ".data" and int(parts[2], 16) != 0:
            sys.exit(f"{name}: .data/.rodata is not empty; DMEM has no loader yet")

    binary = OUT_DIR / f"{name}.bin"
    run([PREFIX + "objcopy", "-O", "binary", "-j", ".text", str(elf), str(binary)])
    data = binary.read_bytes()
    if len(data) > IMEM_BYTES:
        sys.exit(f"{name}: {len(data)} bytes does not fit in {IMEM_BYTES}-byte IMEM")
    data += b"\x00" * (-len(data) % 4)
    words = [int.from_bytes(data[i:i + 4], "little") for i in range(0, len(data), 4)]
    (PROG_DIR / f"{name}.hex").write_text("".join(f"{w:08x}\n" for w in words))

    syms = []
    for line in run([PREFIX + "nm", "-n", str(elf)]).splitlines():
        parts = line.split()
        if len(parts) == 3:
            syms.append(f"{parts[0]} {parts[2]}\n")
    (PROG_DIR / f"{name}.sym").write_text("".join(syms))

    (OUT_DIR / f"{name}.dump").write_text(run([PREFIX + "objdump", "-d", "-M", "no-aliases", str(elf)]))
    print(f"built {name}: {len(words)} words")


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for src in sorted(PROG_DIR.glob("*.S")):
        if src.stem != "crt0":
            build(src.stem, [src])
    build("c_simple", [PROG_DIR / "crt0.S", ROOT / "software" / "simple.c"])


if __name__ == "__main__":
    main()
