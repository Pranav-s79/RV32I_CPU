# trap_store_fault.S: store one word past the end of data memory.
# 0x11000 must NOT wrap around to 0x10000. Expected: cause 7, tval = 0x11000,
# data memory word 0x10000 unchanged.
    .section .text.init
    .globl _start
_start:
    li      s0, 0x10000
    li      t0, 0xAAAA5555
    sw      t0, 0(s0)
    li      t1, 0x11000
    li      t0, 0xDEADDEAD
expected_trap:
    sw      t0, 0(t1)
    ecall
