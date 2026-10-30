# trap_load_fault.S: load from instruction memory's address range.
# Instruction memory is not on the data bus (Harvard), so this is an
# access fault. Expected: cause 5, tval = 0x100, t0 unchanged.
    .section .text.init
    .globl _start
_start:
    li      t1, 0x100
    li      t0, 0x66
expected_trap:
    lw      t0, 0(t1)
    ecall
