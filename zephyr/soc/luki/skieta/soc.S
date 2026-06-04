#include <zephyr/toolchain.h>

GTEXT(__soc_handle_irq)
SECTION_FUNC(exception.other, __soc_handle_irq)
    ret
