# trap_load_misaligned.S: LW from an address that is not a multiple of 4.
# Expected: cause 4, tval = 0x10002, t0 keeps its old value (no writeback).
    .section .text.init
    .globl _start
_start:
    li      s0, 0x10000
    li      t0, 0x55
expected_trap:
    lw      t0, 2(s0)
    ecall
