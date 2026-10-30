# trap_ebreak.S: EBREAK halts the core with cause 3 (breakpoint), tval = pc.
    .section .text.init
    .globl _start
_start:
    li      a0, 0x33
expected_trap:
    ebreak
    li      a0, 0x44                # must never execute
    ecall
