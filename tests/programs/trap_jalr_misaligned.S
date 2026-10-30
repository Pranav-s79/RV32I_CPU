# trap_jalr_misaligned.S: JALR to an address with bit 1 set.
# RV32I needs 4-byte aligned instructions, so the JALR itself traps.
# Expected: cause 0, tval = target, ra NOT written.
    .section .text.init
    .globl _start
_start:
    li      ra, 0x77
    lui     t0, %hi(landing)
    addi    t0, t0, %lo(landing)
    addi    t0, t0, 2
expected_trap:
    jalr    ra, 0(t0)
landing:
    ecall
    ecall
