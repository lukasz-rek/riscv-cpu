.section .text.init
.global _start

_start:
    # Set stack pointer
    la sp, _stack_top

    # Zero .bss
    la t0, _bss_start
    la t1, _bss_end
    bge t0, t1, 2f
1:
    sw zero, 0(t0)
    addi t0, t0, 4
    blt t0, t1, 1b
2:

    call main

    # Signal completion
    li t0, 0x00010004
    li t1, 0xDEADBEEF
    sw t1, 0(t0)

_halt:
    j _halt
