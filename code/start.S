.section .text.init
.global _start

_start:
    # Set stack pointer below UART I/O region
    la sp, _stack_top

    # Call main
    call main

    # Signal completion
    li t0, 0x00010004
    li t1, 0xDEADBEEF
    sw t1, 0(t0)

_halt:
    j _halt
