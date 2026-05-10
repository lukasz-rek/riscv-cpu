#include <stdint.h>

#define UART_BASE 0x10000000
#define UART_THR  (*(volatile uint32_t *)(UART_BASE + 0x00))
#define UART_RBR  (*(volatile uint32_t *)(UART_BASE + 0x00))
#define UART_DLL  (*(volatile uint32_t *)(UART_BASE + 0x00))
#define UART_DLM  (*(volatile uint32_t *)(UART_BASE + 0x04))
#define UART_IER  (*(volatile uint32_t *)(UART_BASE + 0x04))
#define UART_FCR  (*(volatile uint32_t *)(UART_BASE + 0x08))
#define UART_LCR  (*(volatile uint32_t *)(UART_BASE + 0x0C))
#define UART_LSR  (*(volatile uint32_t *)(UART_BASE + 0x14))

#define LCR_DLAB  (1 << 7)
#define LCR_8N1   0x03
#define FCR_EN    0x01
#define LSR_THRE  (1 << 5)
#define LSR_DR    (1 << 0)  // Data Ready

#define UART_DIVISOR 43

void uart_init(void) {
    UART_LCR = LCR_DLAB;
    UART_DLL = UART_DIVISOR & 0xFF;
    UART_DLM = (UART_DIVISOR >> 8) & 0xFF;
    UART_LCR = LCR_8N1;
    UART_FCR = FCR_EN;
    UART_IER = 0x00;
}

void uart_putc(char c) {
    while (!(UART_LSR & LSR_THRE));
    UART_THR = c;
}

void uart_puts(const char *s) {
    while (*s) uart_putc(*s++);
}

char uart_getc(void) {
    while (!(UART_LSR & LSR_DR));
    return (char)(UART_RBR & 0xFF);
}

void uart_puts_char(const char *prefix, char c, const char *suffix) {
    uart_puts(prefix);
    uart_putc(c);
    uart_puts(suffix);
}

void print_hex(uint32_t val) {
    for (int i = 28; i >= 0; i -= 4) {
        uint8_t nibble = (val >> i) & 0xF;
        uart_putc(nibble < 10 ? '0' + nibble : 'A' + nibble - 10);
    }
}

__attribute__((interrupt("machine")))
void trap_handler(void) {
    uint32_t mcause;
    __asm__ volatile ("csrr %0, mcause" : "=r"(mcause));

    uart_puts("TRAP! mcause=0x");
    print_hex(mcause);
    uart_puts("\r\n");
    uint32_t mepc;
    __asm__ volatile ("csrr %0, mepc" : "=r"(mepc));
    mepc += 4;
    __asm__ volatile ("csrw mepc, %0" : : "r"(mepc));
}

void trap_init(void) {
    // Direct mode: all traps go to the same handler (mode bits = 00)
    // mtvec must be 4-byte aligned (your handler will be)
    __asm__ volatile (
        "la t0, trap_handler\n"
        "csrw mtvec, t0\n"
    );
}

int main(void) {
    uart_init();
    // uart_puts("RISC-V UART ready\r\n");

    // while (1) {
    //     char c = uart_getc();
    //     uart_puts("Char received: ");
    //     uart_putc(c);
    //     uart_puts("\r\n");
    // }

    trap_init();

    uart_puts("Before ebreak\r\n");
    __asm__ volatile ("ebreak");
    uart_puts("After ebreak (returned via mret)\r\n");
    // uint32_t cycle1, cycle2;

    // __asm__ volatile ("rdinstret %0" : "=r"(cycle1));

    // // __asm__ volatile ("nop");
    // // __asm__ volatile ("nop");

    // __asm__ volatile ("rdinstret %0" : "=r"(cycle2));

    // print_hex(cycle1);
    // uart_putc('\n');
    // print_hex(cycle2);
    // uart_putc('\n');
    // print_hex(cycle2 - cycle1);
    // uart_putc('\n');

    return 0;
}
