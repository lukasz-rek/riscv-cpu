#include <stdint.h>

#define UART_TX   (*(volatile uint32_t *)0x00001000)
#define DONE_FLAG (*(volatile uint32_t *)0x00001004)

void uart_putc(char c) {
    UART_TX = c;
}

int main() {
    int variable = 1;
    variable += 1;

    // Send result as ASCII digit
    uart_putc('A');
    uart_putc('B');
    uart_putc('C');
    uart_putc('D');
    uart_putc('\n');



    DONE_FLAG = 0xDEADBEEF;
    return 0;
}
