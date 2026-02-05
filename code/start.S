.section .text.init
.global _start

_start:
    # Set stack pointer to top of memory
    li sp, 0x00010000
    
    # Call main
    call main
    
    # If main returns, loop forever
_halt:
    j _halt