SECTIONS {
    . = 0x80000000;
    .text : {
        *(.text.init)
        *(.text*)
    }
    .rodata : ALIGN(4) { *(.rodata*) }
    .data   : ALIGN(4) { *(.data*) *(.sdata*) }
    . = ALIGN(4);
    _bss_start = .;
    .bss : ALIGN(4) {
        *(.bss*)
        *(.sbss*)
        *(COMMON)
    }
    _bss_end = ALIGN(4);
    _stack_top = 0x8000F000;
}
