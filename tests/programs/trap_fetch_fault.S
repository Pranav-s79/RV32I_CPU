# trap_fetch_fault.S: jump to 0x1000, the first address past the 4 KiB
# instruction memory. The jump itself is fine (aligned); the FETCH at
# 0x1000 faults. Expected: cause 1, pc = tval = 0x1000, ra = link address.
    .section .text.init
    .globl _start
_start:
    li      t0, 0x1000
    jalr    ra, 0(t0)
    ecall
