# crt0.S: minimal C runtime. Sets the stack pointer to the top of data
# memory, calls main(), and ends with ECALL so main's return value is in a0.
    .section .text.init
    .globl _start
_start:
    li      sp, 0x11000             # stack grows down from the end of DMEM
    call    main
    ecall
