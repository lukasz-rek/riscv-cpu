#include <stdint.h>

#define UART_TX   (*(volatile uint32_t *)0x00010000)
#define DONE_FLAG (*(volatile uint32_t *)0x00010004)


#define MEM_MARK (*(volatile uint32_t *)0x80004000)

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
    // Each line has 8 words
    // We got 1024 sets
    // uint32_t arr[8 * 2048];

    // for (int i = 0; i < 8 * 2048; i++) {
    //     arr[i] = 0;
    // }

    // arr[0] = 1;
    // arr[1024] = 1;

    // volatile uint32_t *arr = (volatile uint32_t *)0x80004000;

    // arr[0] = 1;
    // arr[8192] = 1;
    // arr[0]++;






    // uint32_t cycle1, cycle2;

    // __asm__ volatile ("csrr %0, mcycle" : "=r"(cycle1));

    // __asm__ volatile ("nop");
    // __asm__ volatile ("nop");

    // __asm__ volatile ("csrr %0, mcycle" : "=r"(cycle2));

    int a = 20;
    int b = 4;

    // // b *= 11;
    // // if ( (a -  b) == 0) {
    //      // uart_putc('0');
    // // } else {
    //      // uart_putc('1');
    // // }
    // uart_putc('\n');

    // if ((a + b) == 120) {
    //     uart_putc('y');

    // } else {
    //     uart_putc('n');
    // }

    // // uart_putc('a');
    // uart_putc('E');
    print_hex(a * b);
    uart_putc('\n');
    // print_hex(cycle2);
    // uart_putc('\n');

    // print_hex(a/b);
    // uart_putc('\n');


    return 0;
}
