SECTIONS {
    . = 0x80000000;

    .text : {
        *(.text.init)    /* startup code first */
        *(.text*)        /* then everything else */
    }

    .rodata : { *(.rodata*) }
    .data : { *(.data*) *(.sdata*) }

    _bss_start = .;

    .bss : {
        *(.bss*)
        *(.sbss*)
        *(COMMON)
    }

    _bss_end = ALIGN(4);

    _stack_top = 0x8000F000;
}
