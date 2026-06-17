#include <zephyr/toolchain.h>

# GTEXT(__reset)
# GTEXT(__initialize)

# SECTION_FUNC(reset, __reset)
#     /* Disable interrupts */
#     csrw mstatus, x0
#     csrw mie, x0
#
#     /* Allow mcycle and minstret to increment */
#     li x11, ~5
#     csrw mcountinhibit, x11
#
#     /* Zero the counters */
#     csrw mcycle, x0
#     csrw mcycleh, x0
#     csrw minstret, x0
#     csrw minstreth, x0
#
#     call __initialize
