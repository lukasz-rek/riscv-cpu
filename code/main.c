#include <stdint.h>

#define UART_TX   (*(volatile uint32_t *)0x00010000)
#define DONE_FLAG (*(volatile uint32_t *)0x00010004)

void uart_putc(char c) {
    while (UART_TX & 1);  // wait while FIFO is full
    UART_TX = c;
}

void print_hex(uint32_t val) {
    for (int i = 28; i >= 0; i -= 4) {
        uint8_t nibble = (val >> i) & 0xF;
        uart_putc(nibble < 10 ? '0' + nibble : 'A' + nibble - 10);
    }
}

int main() {
    // uint32_t cycle1, cycle2;

    // __asm__ volatile ("csrr %0, mcycle" : "=r"(cycle1));

    // __asm__ volatile ("nop");
    // __asm__ volatile ("nop");

    // __asm__ volatile ("csrr %0, mcycle" : "=r"(cycle2));

    int a = 110;
    int b = 10;

    print_hex(a/b);
    uart_putc('\n');


    return 0;
}
