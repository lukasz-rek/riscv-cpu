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
#define UART_IIR  (*(volatile uint32_t *)(UART_BASE + 0x08))
#define IER_RDA   (1 << 0)   // Received Data Available
#define IIR_NO_INT (1 << 0)

#define TIMECMP_LO (*(volatile uint32_t *)0x02004000)
#define TIMECMP_HI (*(volatile uint32_t *)0x02004004)
#define MTIME_LO   (*(volatile uint32_t *)0x0200BFF8)
#define MTIME_HI   (*(volatile uint32_t *)0x0200BFFC)

#define LCR_DLAB  (1 << 7)
#define LCR_8N1   0x03
#define FCR_EN    0x01
#define LSR_THRE  (1 << 5)
#define LSR_DR    (1 << 0)

#define UART_BAUD           115200
#define UART_DIVISOR_BAUD(freq, baud)  (((freq) + (16 * (baud)) / 2) / (16 * (baud)))
#define EE_TICKS_PER_SEC           100000000

#define UART_DIVISOR  UART_DIVISOR_BAUD(EE_TICKS_PER_SEC, UART_BAUD)

#define TIMER_INTERVAL 5314

void uart_init(void) {
    UART_LCR = LCR_DLAB;
    UART_DLL = UART_DIVISOR & 0xFF;
    UART_DLM = (UART_DIVISOR >> 8) & 0xFF;
    UART_LCR = LCR_8N1;
    UART_FCR = FCR_EN;
    UART_IER = IER_RDA;
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
    uart_putc('\n');
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
void machine_trap_handler(void) {
    uint32_t mcause;
    __asm__ volatile ("csrr %0, mcause" : "=r"(mcause));
    if (mcause & 0x80000000) {
        uint32_t code = mcause & 0x7FFFFFFF;
        if (code == 7) {
            secs++;
            write_timecmp(read_mtime() + TIMER_INTERVAL);
            uart_puts("TIMER ");
            print_hex(secs);
            uart_putc('\n');
        } else if (code == 11) {
            // Drain RX FIFO and echo — loop until IIR says no interrupt pending
            while (!(UART_IIR & IIR_NO_INT)) {
                if (UART_LSR & LSR_DR)
                    uart_putc((char)(UART_RBR & 0xFF));
            }
        }
    } else {
        uint32_t mepc, mtval;
        __asm__ volatile ("csrr %0, mepc"  : "=r"(mepc));
        __asm__ volatile ("csrr %0, mtval" : "=r"(mtval));
        uart_puts("TRAP! mcause=0x"); print_hex(mcause);
        uart_puts(" pc=0x");          print_hex(mepc);
        uart_puts(" mtval=0x");       print_hex(mtval);
        uart_puts("\r\n");
        __asm__ volatile ("csrw mepc, %0"  :: "r"(mepc + 4));
        // while (1) {}
    }
}

__attribute__((interrupt("supervisor")))
void supervisor_trap_handler(void) {
    uint32_t scause;
    __asm__ volatile ("csrr %0, scause" : "=r"(scause));
    if (scause & 0x80000000) {
        uint32_t code = scause & 0x7FFFFFFF;
        if (code == 7) {
            secs++;
            write_timecmp(read_mtime() + TIMER_INTERVAL);
            uart_puts("TIMER ");
            print_hex(secs);
            uart_putc('\n');
        } else if (code == 11) {
            // Drain RX FIFO and echo — loop until IIR says no interrupt pending
            while (!(UART_IIR & IIR_NO_INT)) {
                if (UART_LSR & LSR_DR)
                    uart_putc((char)(UART_RBR & 0xFF));
            }
        }
    } else {
        uint32_t sepc, stval;
        __asm__ volatile ("csrr %0, sepc"  : "=r"(sepc));
        __asm__ volatile ("csrr %0, stval" : "=r"(stval));
        uart_puts("TRAP! scause=0x"); print_hex(scause);
        uart_puts(" pc=0x");          print_hex(sepc);
        uart_puts(" stval=0x");       print_hex(stval);
        uart_puts("\r\n");
        __asm__ volatile ("csrw sepc, %0"  :: "r"(sepc + 4));
        // while (1) {}
    }
}

void supervisor_loop(void) {
    while(1) {
        uart_puts("super-vibing\n");
        for(int i = 0; i < 1000; i++) {
            asm volatile("nop");
        }
    }

}

void trap_init(void) {
    __asm__ volatile (
        "la t0, machine_trap_handler\n"
        "csrw mtvec, t0\n"
    );
    __asm__ volatile (
        "la t0, supervisor_trap_handler\n"
        "csrw stvec, t0\n"
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

    uart_puts("echo ready\r\n");
        __asm__ volatile ("li t0, 0x800; csrs mie, t0");  // MEIE = mie[11]
        __asm__ volatile ("csrsi mstatus, 0x8");           // MIE


        // Arm timer before enabling interrupts
    write_timecmp(read_mtime() + TIMER_INTERVAL);

    uart_puts("mtime_lo=0x");  print_hex(MTIME_LO);   uart_puts("\r\n");
    uart_puts("timecmp_lo=0x"); print_hex(TIMECMP_LO); uart_puts("\r\n");
    uart_puts("timecmp_hi=0x"); print_hex(TIMECMP_HI); uart_puts("\r\n");
    secs = 0;
    __asm__ volatile ("li t0, 0x80; csrs mie, t0");   // enable MTIE
    __asm__ volatile ("csrsi mstatus, 0x8");


    __asm__ volatile ("csrw mepc, %0" :: "r"(&supervisor_loop));
    __asm__ volatile ("csrc mstatus, %0" :: "r"(0x1800));
    __asm__ volatile ("csrs mstatus, %0" :: "r"(0x800));
    __asm__ volatile ("csrs medeleg, %0" :: "r"(1 << 2)); // Medeleg for bad instr
    __asm__ volatile("mret");

    uart_puts("Still in machine\n");

    while(1) {
        asm volatile("nop");
    }
}
