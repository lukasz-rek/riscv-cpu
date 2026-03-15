.section .text.init
.global _start

_start:
    # Set stack pointer below UART I/O region
    la sp, _stack_top

    call main

    # Signal completion
    li t0, 0x00010004
    li t1, 0xDEADBEEF
    sw t1, 0(t0)

_halt:
    j _halt


    # 00000000 <_start>:
    #        0: 0000f117     	auipc	sp, 0xf
    #        4: 00010113     	mv	sp, sp
    #        8: 000102b7     	lui	t0, 0x10
    #        c: 00428293     	addi	t0, t0, 0x4
    #       10: deadc337     	lui	t1, 0xdeadc
    #       14: eef30313     	addi	t1, t1, -0x111
    #       18: 0062a023     	sw	t1, 0x0(t0)


    # 00000000 <_start>:
    #        0: deadc337     	lui	t1, 0xdeadc
    #        4: eef30313     	addi	t1, t1, -0x111
    #        8: 0062a023     	sw	t1, 0x0(t0)
