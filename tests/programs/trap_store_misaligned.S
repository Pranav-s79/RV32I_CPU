# trap_store_misaligned.S: SH to an odd address.
# Expected: cause 6, tval = 0x10005, memory word at 0x10004 unchanged.
    .section .text.init
    .globl _start
_start:
    li      s0, 0x10000
    li      t0, 0x11223344
    sw      t0, 4(s0)               # a normal store first
    li      t1, -1
expected_trap:
    sh      t1, 5(s0)               # misaligned: must not write
    ecall
