# trap_illegal.S: a MUL instruction (M extension) is illegal in RV32I.
# Expected: cause 2 (illegal instruction), tval = the instruction bits,
# a0 = 0x11 (set before the trap), a1 untouched (instruction after the trap).
    .section .text.init
    .globl _start
_start:
    li      a0, 0x11
    li      a1, 0x3
    li      a2, 0x4
expected_trap:
    .word   0x02c585b3              # mul a1, a1, a2
    li      a0, 0x22                # must never execute
    ecall
