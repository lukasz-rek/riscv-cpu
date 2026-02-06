ENTRY(_start)

SECTIONS {
    . = 0x00000000;
    
    .text : {
        *(.text.init)    /* startup code first */
        *(.text*)        /* then everything else */
    }
    
    .rodata : { *(.rodata*) }
    .data : { *(.data*) }
    .bss : { *(.bss*) }
    
    . = 0x00010000;
    _stack_top = .;
}