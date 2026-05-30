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

#define TIMECMP_LO (*(volatile uint32_t *)0x02004000)
#define TIMECMP_HI (*(volatile uint32_t *)0x02004004)
#define MTIME_LO   (*(volatile uint32_t *)0x0200BFF8)
#define MTIME_HI   (*(volatile uint32_t *)0x0200BFFC)

#define LCR_DLAB  (1 << 7)
#define LCR_8N1   0x03
#define FCR_EN    0x01
#define LSR_THRE  (1 << 5)
#define LSR_DR    (1 << 0)

#define UART_DIVISOR 43
#define TIMER_INTERVAL 4297

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

void print_hex(uint32_t val) {
    for (int i = 28; i >= 0; i -= 4) {
        uint8_t nibble = (val >> i) & 0xF;
        uart_putc(nibble < 10 ? '0' + nibble : 'A' + nibble - 10);
    }
}

static inline uint64_t read_mtime(void) {
    uint32_t lo, hi, hi2;
    // Re-read on carry: if hi changed between reads, lo wrapped
    do {
        hi  = MTIME_HI;
        lo  = MTIME_LO;
        hi2 = MTIME_HI;
    } while (hi != hi2);
    return ((uint64_t)hi << 32) | lo;
}

static inline void write_timecmp(uint64_t next) {
    // Set HI to max first to suppress comparator while writing LO
    TIMECMP_HI = 0xFFFFFFFF;
    TIMECMP_LO = (uint32_t)(next & 0xFFFFFFFF);
    TIMECMP_HI = (uint32_t)(next >> 32);
}

uint32_t secs;

__attribute__((interrupt("machine")))
void trap_handler(void) {
    uint32_t mcause;
    __asm__ volatile ("csrr %0, mcause" : "=r"(mcause));
    if (mcause & 0x80000000) {
        if ((mcause & 0x7FFFFFFF) == 7) {
            secs++;
            write_timecmp(read_mtime() + TIMER_INTERVAL);
            uart_puts("TIMER ");
            print_hex(secs);
            uart_putc('\n');
        }
    } else {
        uint32_t mepc, mtval;
        __asm__ volatile ("csrr %0, mepc"  : "=r"(mepc));
        __asm__ volatile ("csrr %0, mtval" : "=r"(mtval));

        uart_puts("TRAP! mcause=0x"); print_hex(mcause);
        uart_puts(" pc=0x");          print_hex(mepc);
        uart_puts(" mtval=0x");       print_hex(mtval);
        uart_puts("\r\n");
        while (1) {}
    }
}

void trap_init(void) {
    __asm__ volatile (
        "la t0, trap_handler\n"
        "csrw mtvec, t0\n"
    );
}

void print_5(void) {
    print_hex(0x5);
}

void print_D(void) {
    print_hex(0xD);
}

int main(void) {
    uart_init();
    trap_init();

    uart_putc('\n');

    print_5();
    uart_putc('\n');


    *(volatile uint32_t *)0x80000430 = 0x00d00513u;

    __asm__ volatile ("fence.i" ::: "memory");

    print_5();

    // uart_puts("Before ebreak\r\n");
    // __asm__ volatile ("ebreak");
    // uart_puts("After ebreak (returned via mret)\r\n");

    // Arm timer before enabling interrupts
    // write_timecmp(read_mtime() + TIMER_INTERVAL);

    // uart_puts("mtime_lo=0x");  print_hex(MTIME_LO);   uart_puts("\r\n");
    // uart_puts("timecmp_lo=0x"); print_hex(TIMECMP_LO); uart_puts("\r\n");
    // uart_puts("timecmp_hi=0x"); print_hex(TIMECMP_HI); uart_puts("\r\n");

    // secs = 0;
    // __asm__ volatile ("li t0, 0x80; csrs mie, t0");   // enable MTIE
    // __asm__ volatile ("csrsi mstatus, 0x8");           // enable MIE

    // uart_putc('a');
    // uart_puts("elemel\n");

    // asm volatile("nop");
    // asm volatile("nop");
    // asm volatile("nop");
    // asm volatile("ebreak");
    // asm volatile (
    //     "li t0, 0x80000002\n\t"
    //     "jalr zero, t0, 0"
    //     ::: "t0"
    // );
    // asm volatile (".word 0xFFFFFFFF");
    // asm volatile (".word 0x0000006F | (1 << 21)");  // JAL x0, +2
    // static uint32_t buf[2] = {0xDEADBEEF, 0xCAFEBABE};
    // uint32_t *p = buf;
    // asm volatile (
    //     "addi %0, %0, 1\n\t"
    //     "lw t0, 0(%0)"
    //     : "+r"(p)
    //     :: "t0"
    // );
    // static uint32_t dst[2];
    // asm volatile (
        // "addi %0, %0, 2\n\t"   // misalign by 2 (halfword boundary, not word)
        // "sw t0, 0(%0)"
        // : "+r"(dst)
        // :: "memory"
    // );
    while(1) {
        asm volatile("nop");
    }
}
