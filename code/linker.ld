ENTRY(_start)

SECTIONS {
    . = 0x00000000;
    
    .text : {
        *(.text.init)    /* startup code first */
        *(.text*)        /* then everything else */
    }
    
    .rodata : { *(.rodata*) }
    .data : { *(.data*) *(.sdata*) }
    .bss : { *(.bss*) *(.sbss*) *(COMMON) }

    _stack_top = 0x0000F000;
}