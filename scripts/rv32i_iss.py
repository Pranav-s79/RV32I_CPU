#!/usr/bin/env python3
"""Reference instruction-set simulator (ISS) for RV32I.

This is the "golden model" the RTL is compared against. It is written
from the RISC-V unprivileged spec, one instruction at a time, with no
shared code or structure with the SystemVerilog design.

It models the same system as rtl/rv32i_soc_top.sv:
  IMEM  0x0000_0000 .. 0x0000_0FFF  fetch only
  DMEM  0x0001_0000 .. 0x0001_0FFF  load/store
  LED   0x8000_0000                 4-bit register (written when byte 0 is stored)
  else  access fault
and the same Phase 1 trap policy: the first exception stops execution.

Output format (one line per retired instruction, then final state) must
match tb/tb_rv32i_core.sv exactly; see write_state().

Usage: rv32i_iss.py <program.hex> <out_trace.txt> [max_steps]
"""

import sys

MASK = 0xFFFFFFFF
IMEM_BASE, IMEM_SIZE = 0x0000_0000, 4096
DMEM_BASE, DMEM_SIZE = 0x0001_0000, 4096
LED_ADDR = 0x8000_0000

CAUSE_INSTR_MISALIGNED = 0
CAUSE_INSTR_ACCESS = 1
CAUSE_ILLEGAL = 2
CAUSE_BREAKPOINT = 3
CAUSE_LOAD_MISALIGNED = 4
CAUSE_LOAD_ACCESS = 5
CAUSE_STORE_MISALIGNED = 6
CAUSE_STORE_ACCESS = 7
CAUSE_ECALL_M = 11


class Trap(Exception):
    def __init__(self, cause, tval):
        super().__init__(cause, tval)
        self.cause = cause
        self.tval = tval & MASK


def sext(value, bits):
    """Interpret the low `bits` of value as a two's-complement number."""
    value &= (1 << bits) - 1
    return value - (1 << bits) if value >> (bits - 1) else value


def signed(x):
    return sext(x, 32)


class Machine:
    def __init__(self, image_words):
        self.imem = list(image_words) + [0] * (IMEM_SIZE // 4 - len(image_words))
        self.dmem = bytearray(DMEM_SIZE)
        self.led = 0
        self.x = [0] * 32
        self.pc = IMEM_BASE
        self.trace = []

    # ---------------- memory ----------------
    def fetch(self, addr):
        if not (IMEM_BASE <= addr < IMEM_BASE + IMEM_SIZE):
            raise Trap(CAUSE_INSTR_ACCESS, addr)
        return self.imem[(addr - IMEM_BASE) // 4]

    def load(self, addr, size):
        """Return `size` bytes at addr as an unsigned integer."""
        if DMEM_BASE <= addr < DMEM_BASE + DMEM_SIZE:
            off = addr - DMEM_BASE
            return int.from_bytes(self.dmem[off:off + size], "little")
        if (addr & ~3) == LED_ADDR:
            word = self.led.to_bytes(4, "little")
            off = addr & 3
            return int.from_bytes(word[off:off + size], "little")
        raise Trap(CAUSE_LOAD_ACCESS, addr)

    def store(self, addr, size, value):
        """Store and return the (word address, strobe, lane data) bus record."""
        lanes = ((1 << size) - 1) << (addr & 3)
        lane_data = (value & ((1 << (8 * size)) - 1)) << (8 * (addr & 3))
        if DMEM_BASE <= addr < DMEM_BASE + DMEM_SIZE:
            off = addr - DMEM_BASE
            self.dmem[off:off + size] = (value & ((1 << (8 * size)) - 1)).to_bytes(size, "little")
        elif (addr & ~3) == LED_ADDR:
            if lanes & 1:
                self.led = value & 0xF
        else:
            raise Trap(CAUSE_STORE_ACCESS, addr)
        return (addr & ~3, lanes, lane_data)

    # ---------------- execution ----------------
    def jump(self, target):
        target &= MASK
        if target & 3:
            raise Trap(CAUSE_INSTR_MISALIGNED, target)
        return target

    def step(self):
        """Execute one instruction. Raises Trap without changing state."""
        pc = self.pc
        insn = self.fetch(pc)
        opcode = insn & 0x7F
        rd = (insn >> 7) & 0x1F
        funct3 = (insn >> 12) & 0x7
        rs1 = (insn >> 15) & 0x1F
        rs2 = (insn >> 20) & 0x1F
        funct7 = insn >> 25
        a = self.x[rs1]
        b = self.x[rs2]

        imm_i = sext(insn >> 20, 12)
        imm_s = sext(((insn >> 25) << 5) | ((insn >> 7) & 0x1F), 12)
        imm_b = sext((((insn >> 31) & 1) << 12) | (((insn >> 7) & 1) << 11)
                     | (((insn >> 25) & 0x3F) << 5) | (((insn >> 8) & 0xF) << 1), 13)
        imm_u = insn & 0xFFFFF000
        imm_j = sext((((insn >> 31) & 1) << 20) | (((insn >> 12) & 0xFF) << 12)
                     | (((insn >> 20) & 1) << 11) | (((insn >> 21) & 0x3FF) << 1), 21)

        def illegal():
            return Trap(CAUSE_ILLEGAL, insn)

        result = None          # value for rd, if the instruction writes rd
        next_pc = (pc + 4) & MASK
        mem_record = None

        if opcode == 0b0110111:                         # LUI
            result = imm_u
        elif opcode == 0b0010111:                       # AUIPC
            result = pc + imm_u
        elif opcode == 0b1101111:                       # JAL
            next_pc = self.jump(pc + imm_j)
            result = pc + 4
        elif opcode == 0b1100111:                       # JALR
            if funct3 != 0:
                raise illegal()
            next_pc = self.jump((a + imm_i) & ~1)
            result = pc + 4
        elif opcode == 0b1100011:                       # BRANCH
            conds = {
                0b000: a == b,
                0b001: a != b,
                0b100: signed(a) < signed(b),
                0b101: signed(a) >= signed(b),
                0b110: a < b,
                0b111: a >= b,
            }
            if funct3 not in conds:
                raise illegal()
            if conds[funct3]:
                next_pc = self.jump(pc + imm_b)
        elif opcode == 0b0000011:                       # LOAD
            sizes = {0b000: (1, True), 0b001: (2, True), 0b010: (4, False),
                     0b100: (1, False), 0b101: (2, False)}
            if funct3 not in sizes:
                raise illegal()
            size, is_signed = sizes[funct3]
            addr = (a + imm_i) & MASK
            if addr % size:
                raise Trap(CAUSE_LOAD_MISALIGNED, addr)
            value = self.load(addr, size)
            result = sext(value, 8 * size) if is_signed else value
        elif opcode == 0b0100011:                       # STORE
            sizes = {0b000: 1, 0b001: 2, 0b010: 4}
            if funct3 not in sizes:
                raise illegal()
            size = sizes[funct3]
            addr = (a + imm_s) & MASK
            if addr % size:
                raise Trap(CAUSE_STORE_MISALIGNED, addr)
            mem_record = self.store(addr, size, b)
        elif opcode in (0b0010011, 0b0110011):          # OP-IMM, OP
            is_imm = opcode == 0b0010011
            operand = imm_i & MASK if is_imm else b
            shamt = operand & 0x1F
            if funct3 == 0b000:
                if is_imm or funct7 == 0:
                    result = a + operand
                elif funct7 == 0b0100000:
                    result = a - operand
                else:
                    raise illegal()
            elif funct3 == 0b001:
                if funct7 != 0:
                    raise illegal()
                result = a << shamt
            elif funct3 == 0b101:
                if funct7 == 0:
                    result = a >> shamt
                elif funct7 == 0b0100000:
                    result = signed(a) >> shamt
                else:
                    raise illegal()
            else:
                if not is_imm and funct7 != 0:
                    raise illegal()
                if funct3 == 0b010:
                    result = int(signed(a) < signed(operand))
                elif funct3 == 0b011:
                    result = int(a < operand)
                elif funct3 == 0b100:
                    result = a ^ operand
                elif funct3 == 0b110:
                    result = a | operand
                else:
                    result = a & operand
        elif opcode == 0b0001111:                       # MISC-MEM
            if funct3 != 0:
                raise illegal()                         # FENCE.I not implemented
            # FENCE: nothing to order in a single in-order hart.
        elif opcode == 0b1110011:                       # SYSTEM
            if insn == 0x00000073:
                raise Trap(CAUSE_ECALL_M, 0)
            if insn == 0x00100073:
                raise Trap(CAUSE_BREAKPOINT, pc)
            raise illegal()
        else:
            raise illegal()

        # ---- commit ----
        line = f"{pc:08x} {insn:08x}"
        if result is not None and rd != 0:
            self.x[rd] = result & MASK
            line += f" x{rd}={self.x[rd]:08x}"
        if mem_record is not None:
            waddr, lanes, data = mem_record
            line += f" [{waddr:08x}]{lanes:x}={data:08x}"
        self.trace.append(line)
        self.pc = next_pc

    def run(self, max_steps):
        for _ in range(max_steps):
            try:
                self.step()
            except Trap as trap:
                return trap
        return None

    def write_state(self, path, trap):
        lines = list(self.trace)
        if trap is None:
            lines.append("TIMEOUT")
        else:
            lines.append(f"TRAP cause={trap.cause} pc={self.pc:08x} tval={trap.tval:08x}")
        for i in range(1, 32):
            lines.append(f"x{i}={self.x[i]:08x}")
        lines.append(f"LED={self.led:x}")
        for off in range(0, DMEM_SIZE, 4):
            word = int.from_bytes(self.dmem[off:off + 4], "little")
            if word:
                lines.append(f"MEM[{DMEM_BASE + off:08x}]={word:08x}")
        with open(path, "w") as f:
            f.write("\n".join(lines) + "\n")


def read_hex(path):
    words = []
    with open(path) as f:
        for line in f:
            line = line.split("//")[0].strip()
            if line:
                words.append(int(line, 16))
    return words


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    max_steps = int(sys.argv[3]) if len(sys.argv) > 3 else 100000
    m = Machine(read_hex(sys.argv[1]))
    trap = m.run(max_steps)
    m.write_state(sys.argv[2], trap)


if __name__ == "__main__":
    main()
