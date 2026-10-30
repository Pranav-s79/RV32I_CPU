# trap_branch_misaligned.S: a taken branch with offset +2.
# Expected: cause 0, tval = branch pc + 2. A NOT-taken branch with the
# same offset must not trap, so one is executed first.
    .section .text.init
    .globl _start
_start:
    li      a0, 1
    bne     zero, zero, .+2         # not taken: no trap
    li      a0, 2
expected_trap:
    beq     zero, zero, .+2         # taken: misaligned target
    ecall
