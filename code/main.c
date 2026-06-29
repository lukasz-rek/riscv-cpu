#include <stdint.h>

// ===========================================================================
//  Memory-hammer / cache-coherency test
//
//  Goal: prove or disprove the "lost store" hypothesis behind the Linux
//  set_kthread_struct WARN — a store that updates a line is not visible to a
//  later load of the same address, most likely a D-cache write-back / eviction
//  bug that only bites on the board (real DDR) and not in flat-memory sim.
//
//  The cache is direct-mapped, 32 KB, 32-byte lines (see rtl/axi/axi_cache.sv:
//  CACHE_SIZE=8 4KB-blocks, LINE_BYTES=32 -> 1024 sets). Two addresses alias
//  to the same set when they differ by a multiple of CACHE_BYTES (0x8000).
//
//  Output is plain UART text (sim snoops 0x10000000 TX, board has real UART),
//  so the result is checkable in both. Grep tokens: "HAMMER:", "RESULT".
// ===========================================================================

#define UART_BASE 0x10000000
#define UART_THR  (*(volatile uint32_t *)(UART_BASE + 0x00))
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

#define UART_BAUD          115200
#define EE_TICKS_PER_SEC   125000000
#define UART_DIVISOR  (((EE_TICKS_PER_SEC) + (16 * (UART_BAUD)) / 2) / (16 * (UART_BAUD)))

// ---- memory map under test -------------------------------------------------
// Code/data/stack live in 0x80000000..0x8000F000 (stack top 0x8000F000), so
// everything from 0x80100000 up is free scratch.
#define CACHE_BYTES   (32u * 1024u)        // direct-mapped cache size
#define LINE_BYTES    32u

#define HAMMER_BASE   0x80100000u          // 1 MB above code — safely clear

// ---------------------------------------------------------------------------
// UART
// ---------------------------------------------------------------------------
void uart_init(void) {
    UART_LCR = LCR_DLAB;
    UART_DLL = UART_DIVISOR & 0xFF;
    UART_DLM = (UART_DIVISOR >> 8) & 0xFF;
    UART_LCR = LCR_8N1;
    UART_FCR = FCR_EN;
    UART_IER = 0;
}

void uart_putc(char c) {
    while (!(UART_LSR & LSR_THRE));
    UART_THR = c;
}

void uart_puts(const char *s) {
    while (*s) uart_putc(*s++);
}

// hex with NO trailing newline
void print_hex_n(uint32_t val) {
    for (int i = 28; i >= 0; i -= 4) {
        uint8_t nib = (val >> i) & 0xF;
        uart_putc(nib < 10 ? '0' + nib : 'A' + nib - 10);
    }
}

void print_hex(uint32_t val) { print_hex_n(val); uart_putc('\n'); }

// ---------------------------------------------------------------------------
// Synchronous-trap reporter — interrupts stay OFF, so this only fires on a
// real fault (misaligned / access error). A bus fault during hammering is
// itself a useful signal, so surface it instead of hanging silently.
// ---------------------------------------------------------------------------
__attribute__((interrupt("machine")))
void machine_trap_handler(void) {
    uint32_t mcause, mepc, mtval;
    __asm__ volatile ("csrr %0, mcause" : "=r"(mcause));
    __asm__ volatile ("csrr %0, mepc"   : "=r"(mepc));
    __asm__ volatile ("csrr %0, mtval"  : "=r"(mtval));
    uart_puts("TRAP! mcause=0x"); print_hex_n(mcause);
    uart_puts(" pc=0x");          print_hex_n(mepc);
    uart_puts(" mtval=0x");       print_hex_n(mtval);
    uart_puts("\r\n");
    __asm__ volatile ("csrw mepc, %0" :: "r"(mepc + 4));  // skip & continue
}

void trap_init(void) {
    __asm__ volatile ("la t0, machine_trap_handler\n csrw mtvec, t0\n" ::: "t0");
}

// ---------------------------------------------------------------------------
// Test machinery
// ---------------------------------------------------------------------------

// Address-derived expected value. Keying on the *byte address* means a
// write-back that lands at the wrong line/address shows up as a mismatch, not
// a coincidentally-correct value.
static inline uint32_t keyval(uint32_t addr) {
    return (addr * 0x9E3779B1u) ^ 0xA5A5A5A5u;
}

static uint32_t g_errors;

static void fail(const char *tag, uint32_t addr, uint32_t exp, uint32_t got) {
    if (g_errors < 16) {  // cap spew
        uart_puts("  FAIL "); uart_puts(tag);
        uart_puts(" @0x");  print_hex_n(addr);
        uart_puts(" exp=0x"); print_hex_n(exp);
        uart_puts(" got=0x"); print_hex_n(got);
        uart_puts("\r\n");
    }
    g_errors++;
}

// --- Test 1: linear sweep, span >> cache -----------------------------------
// Writes every word of a 4 MB region (128 evictions per line), then reads it
// all back. Catches generic write-back loss and mis-addressed evictions.
static void test_linear(uint32_t span_bytes) {
    volatile uint32_t *p = (volatile uint32_t *)HAMMER_BASE;
    uint32_t words = span_bytes / 4;
    uart_puts("HAMMER: T1 linear span=0x"); print_hex(span_bytes);

    for (uint32_t i = 0; i < words; i++)
        p[i] = keyval((uint32_t)(uintptr_t)&p[i]);

    uint32_t before = g_errors;
    for (uint32_t i = 0; i < words; i++) {
        uint32_t a = (uint32_t)(uintptr_t)&p[i];
        uint32_t exp = keyval(a), got = p[i];
        if (got != exp) fail("T1", a, exp, got);
    }
    uart_puts("HAMMER: T1 errs=0x"); print_hex(g_errors - before);
}

// --- Test 2: same-set ping-pong --------------------------------------------
// Lines spaced exactly CACHE_BYTES apart all map to the same set. Writing them
// round-robin forces each write to evict the *previous* just-dirtied aliasing
// line — the exact "store then immediately evict that line" race. Multiple
// passes so the writeback of a freshly-written line is on the critical path.
static void test_same_set(uint32_t lines, uint32_t passes) {
    uint32_t base = HAMMER_BASE + 0x800000;  // fresh 8 MB-in region
    uart_puts("HAMMER: T2 same-set lines=0x"); print_hex_n(lines);
    uart_puts(" passes=0x"); print_hex(passes);

    for (uint32_t pass = 0; pass < passes; pass++)
        for (uint32_t k = 0; k < lines; k++) {
            volatile uint32_t *a = (volatile uint32_t *)(base + k * CACHE_BYTES);
            *a = keyval((uint32_t)(uintptr_t)a) + pass;     // +pass = distinct each pass
        }

    uint32_t before = g_errors;
    uint32_t last = passes - 1;
    for (uint32_t k = 0; k < lines; k++) {
        volatile uint32_t *a = (volatile uint32_t *)(base + k * CACHE_BYTES);
        uint32_t exp = keyval((uint32_t)(uintptr_t)a) + last, got = *a;
        if (got != exp) fail("T2", (uint32_t)(uintptr_t)a, exp, got);
    }
    uart_puts("HAMMER: T2 errs=0x"); print_hex(g_errors - before);
}

// --- Test 3: sub-word stores across a span >> cache ------------------------
// Byte stores exercise the cache byte-enable path (rtl/axi/axi_cache.sv:157);
// spanning > cache forces those partially-written lines through eviction.
static void test_subword(uint32_t span_bytes) {
    volatile uint8_t *q = (volatile uint8_t *)(HAMMER_BASE + 0x1800000); // 24 MB-in
    uart_puts("HAMMER: T3 subword span=0x"); print_hex(span_bytes);

    for (uint32_t i = 0; i < span_bytes; i++)
        q[i] = (uint8_t)(keyval((uint32_t)(uintptr_t)&q[i]) & 0xFF);

    uint32_t before = g_errors;
    for (uint32_t i = 0; i < span_bytes; i++) {
        uint8_t exp = (uint8_t)(keyval((uint32_t)(uintptr_t)&q[i]) & 0xFF);
        uint8_t got = q[i];
        if (got != exp) fail("T3", (uint32_t)(uintptr_t)&q[i], exp, got);
    }
    uart_puts("HAMMER: T3 errs=0x"); print_hex(g_errors - before);
}

// ---------------------------------------------------------------------------
// Atomic primitives (A extension) — these drive the AMO state machine and the
// LR/SC reservation path, which the plain load/store hammer never exercises.
// fast_dput / refcount_t / spinlocks all ride on exactly these.
// ---------------------------------------------------------------------------
static inline uint32_t amoadd_w(volatile uint32_t *p, uint32_t v) {
    uint32_t r; __asm__ volatile("amoadd.w %0,%2,(%1)" : "=r"(r) : "r"(p), "r"(v) : "memory");
    return r;
}
static inline uint32_t amoswap_w(volatile uint32_t *p, uint32_t v) {
    uint32_t r; __asm__ volatile("amoswap.w %0,%2,(%1)" : "=r"(r) : "r"(p), "r"(v) : "memory");
    return r;
}
static inline uint32_t amoor_w(volatile uint32_t *p, uint32_t v) {
    uint32_t r; __asm__ volatile("amoor.w %0,%2,(%1)" : "=r"(r) : "r"(p), "r"(v) : "memory");
    return r;
}
// cmpxchg via LR/SC. Returns the value observed; caller compares to `old`.
static inline uint32_t cmpxchg_w(volatile uint32_t *p, uint32_t old, uint32_t newv) {
    uint32_t ret, sc;
    __asm__ volatile(
        "1: lr.w   %0,(%2)\n"
        "   bne    %0,%3,2f\n"
        "   sc.w   %1,%4,(%2)\n"
        "   bnez   %1,1b\n"
        "2:\n"
        : "=&r"(ret), "=&r"(sc) : "r"(p), "r"(old), "r"(newv) : "memory");
    return ret;
}

// --- Test 4: amoadd over an evicting working set ----------------------------
// Working set (cnt*LINE_BYTES) is forced > cache so each amoadd misses, refills,
// and evicts a dirty line. If the AMO's store-half isn't written back, the
// counter ends up < iters. Each counter sits alone on its own line.
static void test_amoadd(uint32_t cnt, uint32_t iters) {
    uint32_t base = HAMMER_BASE + 0x2000000;   // 32 MB-in, fresh
    uart_puts("HAMMER: T4 amoadd cnt=0x"); print_hex_n(cnt);
    uart_puts(" iters=0x"); print_hex(iters);

    for (uint32_t k = 0; k < cnt; k++)
        *(volatile uint32_t *)(base + k * LINE_BYTES) = 0;
    for (uint32_t it = 0; it < iters; it++)
        for (uint32_t k = 0; k < cnt; k++)
            (void)amoadd_w((volatile uint32_t *)(base + k * LINE_BYTES), 1);

    uint32_t before = g_errors;
    for (uint32_t k = 0; k < cnt; k++) {
        uint32_t a = base + k * LINE_BYTES, got = *(volatile uint32_t *)a;
        if (got != iters) fail("T4", a, iters, got);
    }
    uart_puts("HAMMER: T4 errs=0x"); print_hex(g_errors - before);
}

// --- Test 5: LR/SC cmpxchg increment over an evicting working set -----------
// Same eviction stress, but the increment is a cmpxchg loop — this exercises
// reservation set (lr.w) survival across the refill/evict the cmpxchg itself
// triggers, plus correct sc.w success.
static void test_lrsc(uint32_t cnt, uint32_t iters) {
    uint32_t base = HAMMER_BASE + 0x2800000;   // 40 MB-in, fresh
    uart_puts("HAMMER: T5 lr/sc cnt=0x"); print_hex_n(cnt);
    uart_puts(" iters=0x"); print_hex(iters);

    for (uint32_t k = 0; k < cnt; k++)
        *(volatile uint32_t *)(base + k * LINE_BYTES) = 0;
    for (uint32_t it = 0; it < iters; it++)
        for (uint32_t k = 0; k < cnt; k++) {
            volatile uint32_t *p = (volatile uint32_t *)(base + k * LINE_BYTES);
            uint32_t o;
            do { o = *p; } while (cmpxchg_w(p, o, o + 1) != o);
        }

    uint32_t before = g_errors;
    for (uint32_t k = 0; k < cnt; k++) {
        uint32_t a = base + k * LINE_BYTES, got = *(volatile uint32_t *)a;
        if (got != iters) fail("T5", a, iters, got);
    }
    uart_puts("HAMMER: T5 errs=0x"); print_hex(g_errors - before);
}

// --- Test 6: directed LR/SC reservation semantics ---------------------------
// (a) lr then immediate sc must SUCCEED and write.
// (b) lr, then a plain store to the same word, then sc must FAIL (res!=0) and
//     leave the plain-stored value intact. This is the reservation-invalidation
//     path that a buggy spinlock/cmpxchg would get wrong.
static void test_lrsc_semantics(void) {
    volatile uint32_t *p = (volatile uint32_t *)(HAMMER_BASE + 0x3000000);
    uint32_t before = g_errors, t, sc;
    uart_puts("HAMMER: T6 lr/sc semantics\r\n");

    // (a) clean success
    *p = 0x11111111;
    __asm__ volatile("lr.w %0,(%1)" : "=r"(t) : "r"(p) : "memory");
    __asm__ volatile("sc.w %0,%2,(%1)" : "=r"(sc) : "r"(p), "r"(0x22222222) : "memory");
    if (sc != 0)        fail("T6a-scfail", (uint32_t)(uintptr_t)p, 0, sc);
    if (*p != 0x22222222) fail("T6a-val", (uint32_t)(uintptr_t)p, 0x22222222, *p);

    // (b) reservation broken by an intervening plain store -> sc must fail
    *p = 0x33333333;
    __asm__ volatile("lr.w %0,(%1)" : "=r"(t) : "r"(p) : "memory");
    *p = 0x44444444;                                   // breaks the reservation
    __asm__ volatile("sc.w %0,%2,(%1)" : "=r"(sc) : "r"(p), "r"(0xDEADBEEF) : "memory");
    if (sc == 0)        fail("T6b-scok", (uint32_t)(uintptr_t)p, 1, sc);   // expected fail
    if (*p != 0x44444444) fail("T6b-val", (uint32_t)(uintptr_t)p, 0x44444444, *p);

    uart_puts("HAMMER: T6 errs=0x"); print_hex(g_errors - before);
}

// --- Test 7: csrrw swap with rd == rs1 (the literal trap-entry instruction) -
// handle_exception's first insn is `csrrw tp, sscratch, tp`: atomically read
// the CSR into a reg while writing the SAME reg's old value back. A core that
// mishandles rd==rs1 corrupts tp on every trap. Tested here on mscratch (M-mode).
static void test_csr_swap(void) {
    uint32_t before = g_errors;
    uart_puts("HAMMER: T7 csrrw swap (rd==rs1)\r\n");
    static const uint32_t v[][2] = {
        {0xAAAAAAAA, 0x55555555}, {0x00000000, 0x12345678},
        {0xDEADBEEF, 0x00000000}, {0x80046000, 0x8089b380},
    };
    for (uint32_t i = 0; i < 4; i++) {
        uint32_t a = v[i][0], b = v[i][1], rd = v[i][1], m;
        __asm__ volatile("csrw mscratch, %0" :: "r"(a));          // mscratch = a
        __asm__ volatile("csrrw %0, mscratch, %0" : "+r"(rd));    // rd<-a ; mscratch<-b
        __asm__ volatile("csrr %0, mscratch" : "=r"(m));
        if (rd != a) fail("T7-rd", i, a, rd);   // read side must return old CSR
        if (m  != b) fail("T7-wr", i, b, m);    // write side must take old reg
    }
    uart_puts("HAMMER: T7 errs=0x"); print_hex(g_errors - before);
}

// --- Test 8: S-mode trap round-trip — reproduces the Linux tp corruption -----
// Drops to S-mode, installs a handler that manages tp through sscratch exactly
// like handle_exception, then takes many delegated ebreak traps and verifies:
//   * SPP reads 1 inside the handler (trap was from S-mode)
//   * tp survives every trap (== sentinel)
// If the core sets SPP wrong on an S-mode trap, t8_spp_bad / tp checks fire.
volatile uint32_t t8_traps;
volatile uint32_t t8_spp_bad;
volatile uint32_t t8_tp_bad;
#define T8_SENTINEL 0x8089b380u

extern void t8_strap(void);
__asm__(
    ".global t8_strap\n.align 2\n"
"t8_strap:\n"
    "   csrrw tp, sscratch, tp\n"     // tp<-sscratch ; sscratch<-old tp
    "   bnez  tp, 1f\n"               // sscratch nonzero => 'from user'
    "   csrr  tp, sscratch\n"         // kernel: restore tp
    "1: addi  sp, sp, -16\n"
    "   sw    t0, 0(sp)\n   sw t1, 4(sp)\n"
    "   csrr  t1, sstatus\n   andi t1, t1, 0x100\n"   // SPP
    "   bnez  t1, 2f\n"
    "   la    t0, t8_spp_bad\n   li t1, 1\n   sw t1, 0(t0)\n"  // SPP==0 from S-mode = BUG
    "2: li    t1, 0x8089b380\n   beq tp, t1, 3f\n"
    "   la    t0, t8_tp_bad\n   sw tp, 0(t0)\n"        // tp not preserved = BUG
    "3: la    t0, t8_traps\n   lw t1, 0(t0)\n   addi t1, t1, 1\n   sw t1, 0(t0)\n"
    "   csrw  sscratch, zero\n"        // we always return to S here -> keep 0
    "   csrr  t1, sepc\n   addi t1, t1, 4\n   csrw sepc, t1\n"  // skip the ebreak
    "   lw    t1, 4(sp)\n   lw t0, 0(sp)\n   addi sp, sp, 16\n"
    "   sret\n");

static void test_strap_tp(void) {
    uint32_t before = g_errors;
    uart_puts("HAMMER: T8 S-mode trap tp-survival\r\n");
    t8_traps = 0; t8_spp_bad = 0; t8_tp_bad = 0;

    __asm__ volatile("li t0,(1<<3); csrs medeleg, t0" ::: "t0");   // delegate breakpoint to S
    __asm__ volatile(                                              // drop to S-mode
        "li t0,0x1800\n csrc mstatus,t0\n"     // clear MPP
        "li t0,0x0800\n csrs mstatus,t0\n"     // MPP=01 (S)
        "la t0,1f\n csrw mepc,t0\n mret\n 1:\n" ::: "t0","memory");

    __asm__ volatile(                                              // now in S-mode
        "csrw sscratch, zero\n"
        "la t0, t8_strap\n csrw stvec, t0\n"
        "li tp, 0x8089b380\n" ::: "t0","tp","memory");

    for (volatile int i = 0; i < 2000; i++) __asm__ volatile("ebreak");

    uint32_t tp_now;
    __asm__ volatile("mv %0, tp" : "=r"(tp_now));
    if (t8_spp_bad)         fail("T8-SPP=0-from-S", 0, 1, t8_spp_bad);
    if (t8_tp_bad)          fail("T8-tp-in-handler", 0, T8_SENTINEL, t8_tp_bad);
    if (tp_now != T8_SENTINEL) fail("T8-tp-final", 0, T8_SENTINEL, tp_now);
    uart_puts("HAMMER: T8 traps=0x"); print_hex_n(t8_traps);
    uart_puts(" errs=0x"); print_hex(g_errors - before);
    // (remains in S-mode after this; UART/mem still reachable, no PMP)
}

// --- Test 9: M-mode (OpenSBI-style) trap round-trip + unaligned access -------
// The kernel's non-delegated traps go to OpenSBI in M-mode, whose entry swaps
// tp through mscratch: `csrrw tp, mscratch, tp`. This was never tested (T8 was
// S-mode). tp landing on an 0x8004xxxx (OpenSBI scratch) value points here.
// Also: misaligned load/store are NOT delegated (medeleg bit 4/6 clear) so they
// trap to M too — and the Spike log flags unaligned accesses. We verify:
//   * unaligned lw/sw actually trap with cause 4 / 6
//   * tp survives the OpenSBI-style mscratch double-swap across mret
volatile uint32_t t9_cause;
volatile uint32_t t9_tp_bad;
volatile uint32_t t9_mscratch_sentinel = 0x80046000u;   // mimic OpenSBI scratch ptr
#define T9_SENTINEL 0x8089b380u

extern void t9_mtrap(void);
__asm__(
    ".global t9_mtrap\n.align 2\n"
"t9_mtrap:\n"
    "   csrrw tp, mscratch, tp\n"      // tp<-mscratch(scratch) ; mscratch<-caller tp
    "   addi  sp, sp, -16\n"
    "   sw    t0,0(sp)\n   sw t1,4(sp)\n"
    "   csrr  t1, mcause\n   la t0, t9_cause\n   sw t1, 0(t0)\n"
    "   csrr  t1, mepc\n     addi t1,t1,4\n   csrw mepc, t1\n"   // skip faulting insn
    "   csrrw tp, mscratch, tp\n"      // swap back: tp<-caller tp ; mscratch<-scratch
    "   li    t1, 0x8089b380\n   beq tp, t1, 1f\n"
    "   la    t0, t9_tp_bad\n   sw tp, 0(t0)\n"                  // tp not restored = BUG
    "1: lw    t1,4(sp)\n   lw t0,0(sp)\n   addi sp,sp,16\n"
    "   mret\n");

static void test_mtrap_tp(void) {
    uint32_t before = g_errors, saved_tp;
    uart_puts("HAMMER: T9 M-mode trap + unaligned\r\n");
    t9_tp_bad = 0;
    __asm__ volatile("mv %0, tp" : "=r"(saved_tp));            // preserve C's tp

    __asm__ volatile(
        "la t0, t9_mtrap\n   csrw mtvec, t0\n"
        "la t0, t9_mscratch_sentinel\n lw t0,0(t0)\n csrw mscratch, t0\n"
        "li tp, 0x8089b380\n" ::: "t0","tp","memory");

    // (a) plain M-mode trap via ebreak
    t9_cause = 0xffffffff;
    __asm__ volatile("ebreak");
    if (t9_cause != 3) fail("T9a-cause", 0, 3, t9_cause);

    // (b) unaligned load — must trap with cause 4 (load addr misaligned)
    t9_cause = 0xffffffff;
    { volatile uint8_t *m = (volatile uint8_t *)(HAMMER_BASE + 1); uint32_t v;
      __asm__ volatile("lw %0, 0(%1)" : "=r"(v) : "r"(m) : "memory"); (void)v; }
    if (t9_cause != 4) fail("T9b-load-misalign-cause", 0, 4, t9_cause);

    // (c) unaligned store — must trap with cause 6 (store addr misaligned)
    t9_cause = 0xffffffff;
    { volatile uint8_t *m = (volatile uint8_t *)(HAMMER_BASE + 2);
      __asm__ volatile("sw %0, 0(%1)" :: "r"(0x1234), "r"(m) : "memory"); }
    if (t9_cause != 6) fail("T9c-store-misalign-cause", 0, 6, t9_cause);

    uint32_t tp_now;
    __asm__ volatile("mv %0, tp" : "=r"(tp_now));
    if (tp_now != T9_SENTINEL) fail("T9-tp-final", 0, T9_SENTINEL, tp_now);
    if (t9_tp_bad)             fail("T9-tp-in-handler", 0, T9_SENTINEL, t9_tp_bad);

    // restore C's tp and the normal trap handler before returning
    __asm__ volatile("mv tp, %0" :: "r"(saved_tp));
    trap_init();
    uart_puts("HAMMER: T9 cause(last)=0x"); print_hex_n(t9_cause);
    uart_puts(" errs=0x"); print_hex(g_errors - before);
}

// --- Test 10: S-mode -> M-mode ecall trap (the EXACT Linux SBI path) ----------
// T7/T8/T9 never cross privilege during the trap: T8 is S->S (delegated), T9 is
// M->M. Linux's tp corruption happens on `ecall` from S-mode -> OpenSBI in M-mode
// (mcause=9), whose vector's first insn is `csrrw tp, mscratch, tp`. This is the
// only untested structural case. We capture mscratch RIGHT AFTER the entry swap:
// if it isn't the caller's tp, the entry swap's CSR-write was dropped on the S->M
// transition -> that's the bug (tp ends up = OpenSBI scratch 0x80046000).
volatile uint32_t t10_cause;
volatile uint32_t t10_tp_bad;
volatile uint32_t t10_mscratch_after_entry;   // == caller tp if entry swap worked
volatile uint32_t t10_mscratch_sentinel = 0x80046000u;   // mimic OpenSBI scratch ptr
#define T10_SENTINEL 0x8089b380u

extern void t10_mtrap(void);
__asm__(
    ".global t10_mtrap\n.align 2\n"
"t10_mtrap:\n"
    "   csrrw tp, mscratch, tp\n"      // ENTRY swap: tp<-scratch ; mscratch<-S-mode tp
    "   addi  sp, sp, -16\n"
    "   sw    t0,0(sp)\n   sw t1,4(sp)\n"
    "   csrr  t1, mscratch\n   la t0,t10_mscratch_after_entry\n   sw t1,0(t0)\n" // did entry write it?
    "   csrr  t1, mcause\n     la t0,t10_cause\n   sw t1,0(t0)\n"
    "   csrr  t1, mepc\n       addi t1,t1,4\n   csrw mepc,t1\n"   // skip the ecall
    "   csrrw tp, mscratch, tp\n"      // RESTORE swap: tp<-S-mode tp ; mscratch<-scratch
    "   li    t1, 0x8089b380\n   beq tp,t1,1f\n"
    "   la    t0,t10_tp_bad\n   sw tp,0(t0)\n"      // tp not restored across S->M->S = BUG
    "1: li    t1, 0x1800\n   csrs mstatus, t1\n"    // force MPP=M so mret returns to M-mode
    "   lw    t1,4(sp)\n   lw t0,0(sp)\n   addi sp,sp,16\n"
    "   mret\n");

static void test_s_to_m_trap_tp(void) {
    uint32_t before = g_errors, saved_tp;
    uart_puts("HAMMER: T10 S->M ecall trap tp-survival\r\n");
    t10_cause = 0xffffffff; t10_tp_bad = 0; t10_mscratch_after_entry = 0xffffffff;
    __asm__ volatile("mv %0, tp" : "=r"(saved_tp));

    __asm__ volatile("li t0,(1<<9)\n csrc medeleg, t0\n" ::: "t0");   // ecall-from-S NOT delegated -> M
    __asm__ volatile(
        "la t0, t10_mtrap\n   csrw mtvec, t0\n"
        "la t0, t10_mscratch_sentinel\n lw t0,0(t0)\n csrw mscratch, t0\n" ::: "t0","memory");

    __asm__ volatile(                                    // drop to S, set tp, ecall (S->M), come back in M
        "li t0,0x1800\n csrc mstatus,t0\n"              // clear MPP
        "li t0,0x0800\n csrs mstatus,t0\n"              // MPP=01 (S)
        "la t0,1f\n csrw mepc,t0\n mret\n"
        "1:\n"                                           // now in S-mode
        "li tp, 0x8089b380\n"
        "ecall\n"                                        // S->M trap, mcause=9; handler returns to M
        ::: "t0","tp","memory");
    // back in M-mode here

    uint32_t tp_now;
    __asm__ volatile("mv %0, tp" : "=r"(tp_now));
    if (t10_cause != 9) fail("T10-cause", 0, 9, t10_cause);
    if (t10_mscratch_after_entry != T10_SENTINEL)
        fail("T10-entry-swap-mscratch", 0, T10_SENTINEL, t10_mscratch_after_entry);
    if (t10_tp_bad)             fail("T10-tp-in-handler", 0, T10_SENTINEL, t10_tp_bad);
    if (tp_now != T10_SENTINEL) fail("T10-tp-final", 0, T10_SENTINEL, tp_now);

    __asm__ volatile("mv tp, %0" :: "r"(saved_tp));
    trap_init();
    uart_puts("HAMMER: T10 mscr_after_entry=0x"); print_hex_n(t10_mscratch_after_entry);
    uart_puts(" errs=0x"); print_hex(g_errors - before);
}

// --- Test 11: back-to-back trap/mret storm — the privilege/PC desync ----------
// Linux's oops (epc=OpenSBI _trap_handler, cause=2 illegal, SPP=1) means the
// core redirected PC to the M-mode trap vector but left privilege in S, so the
// vector's first insn `csrrw tp, mscratch, tp` (an M-mode CSR) trapped illegal.
// Hypothesis: the fetch redirect (core.sv:129 trap_en|isr_en) and the privilege
// commit (csr_regfile.sv:417, gated by trap_changes_committed_q) are decoupled —
// when a 2nd trap/mret event lands while trap_changes_committed_q is still 1 from
// the previous one, the commit (privilege<=M) is skipped but PC still goes to
// mtvec. T7-T10 only ever do a single, isolated swap; this hammers *adjacent*
// events: every ecall here returns via mret straight back into the next trap.
//
// Detector: leave EVERYTHING non-delegated, so even the bad in-S entry swap traps
// to M (this same vector). If a handler entry ever sees mcause==2 with mepc at the
// vector base, the previous trap entered the vector in the wrong privilege => BUG.
// Spacings 0..3 between consecutive traps sweep the relative pipeline phase so we
// hit whatever offset re-arms the race.
volatile uint32_t t11_traps;          // handled traps (storm progress)
volatile uint32_t t11_bug_cnt;        // desync detections (illegal @ vector)
volatile uint32_t t11_bad_mepc;       // mepc of the offending entry swap
volatile uint32_t t11_bad_mscratch;   // mscratch when the desync was caught
volatile uint32_t t11_target;         // stop after this many handled traps
#define T11_SCRATCH  0x80046000u       // OpenSBI-scratch-like sentinel
#define T11_TP       0x8089b380u

extern void t11_mtrap(void);
__asm__(
    ".global t11_mtrap\n.align 2\n"
"t11_mtrap:\n"
    "   csrrw tp, mscratch, tp\n"                 // ENTRY swap (legal only in M-mode)
    "   addi  sp, sp, -16\n"
    "   sw t0,0(sp)\n   sw t1,4(sp)\n   sw t2,8(sp)\n"
    "   csrr  t1, mcause\n"
    "   li    t2, 2\n"
    "   beq   t1, t2, t11_bug\n"                  // illegal @ vector => priv/PC desync
    "   la    t0, t11_traps\n   lw t2,0(t0)\n   addi t2,t2,1\n   sw t2,0(t0)\n"
    "   la    t0, t11_target\n   lw t0,0(t0)\n"
    "   bge   t2, t0, t11_done\n"                 // reached target => return to M
    "   csrr  t1, mepc\n   addi t1,t1,4\n   csrw mepc, t1\n"   // skip the ecall
    "   csrrw tp, mscratch, tp\n"                 // RESTORE swap
    "   lw t2,8(sp)\n   lw t1,4(sp)\n   lw t0,0(sp)\n   addi sp,sp,16\n"
    "   mret\n"                                   // -> S, straight into the next trap
"t11_bug:\n"
    "   la    t0, t11_bug_cnt\n   lw t2,0(t0)\n   addi t2,t2,1\n   sw t2,0(t0)\n"
    "   csrr  t2, mepc\n       la t0, t11_bad_mepc\n     sw t2,0(t0)\n"
    "   csrr  t2, mscratch\n   la t0, t11_bad_mscratch\n sw t2,0(t0)\n"
"t11_done:\n"
    "   csrrw tp, mscratch, tp\n"                 // best-effort restore swap
    "   li    t1, 0x1800\n   csrs mstatus, t1\n"  // MPP=M -> mret returns to M-mode
    "   la    t1, t11_resume\n   csrw mepc, t1\n"
    "   lw t2,8(sp)\n   lw t1,4(sp)\n   lw t0,0(sp)\n   addi sp,sp,16\n"
    "   mret\n");

static void test_trap_storm(void) {
    uint32_t before = g_errors, saved_tp, saved_mtvec, saved_mscr, saved_medeleg;
    uart_puts("HAMMER: T11 trap/mret desync storm\r\n");
    t11_traps = 0; t11_bug_cnt = 0; t11_bad_mepc = 0; t11_bad_mscratch = 0;
    t11_target = 100000u;

    __asm__ volatile("mv %0, tp"       : "=r"(saved_tp));
    __asm__ volatile("csrr %0, mtvec"  : "=r"(saved_mtvec));
    __asm__ volatile("csrr %0, mscratch":"=r"(saved_mscr));
    __asm__ volatile("csrr %0, medeleg": "=r"(saved_medeleg));

    __asm__ volatile(
        "csrw medeleg, zero\n"                            // nothing delegated -> all to M
        "la t0, t11_mtrap\n   csrw mtvec, t0\n"
        "li t0, %0\n          csrw mscratch, t0\n"        // scratch sentinel
        :: "i"(T11_SCRATCH) : "t0", "memory");

    // Drop to S-mode and storm ecalls at spacings 0,0,1,2,3. Each handler returns
    // (mret) to the instruction after its ecall, i.e. right into the next one, so
    // every iteration is a tight mret->trap pair. The handler bails out to
    // t11_resume (in M-mode) once t11_target traps have been serviced.
    __asm__ volatile(
        "li t0,0x1800\n   csrc mstatus,t0\n"              // clear MPP
        "li t0,0x0800\n   csrs mstatus,t0\n"              // MPP=01 (S)
        "la t0,1f\n       csrw mepc,t0\n   mret\n"
        "1:\n"                                            // now in S-mode
        "li tp, %0\n"
        "2:\n"
        "   ecall\n"                                      // spacing 0
        "   ecall\n"                                      // spacing 0
        "   nop\n   ecall\n"                              // spacing 1
        "   nop\n   nop\n   ecall\n"                      // spacing 2
        "   nop\n   nop\n   nop\n   ecall\n"              // spacing 3
        "   j 2b\n"
        ".global t11_resume\n"
        "t11_resume:\n"
        "   nop\n"
        :: "i"(T11_TP) : "t0", "tp", "memory");
    // back in M-mode here

    // restore the M-mode environment we clobbered
    __asm__ volatile("csrw mtvec, %0"  :: "r"(saved_mtvec));
    __asm__ volatile("csrw mscratch, %0":: "r"(saved_mscr));
    __asm__ volatile("csrw medeleg, %0":: "r"(saved_medeleg));
    __asm__ volatile("mv tp, %0"       :: "r"(saved_tp));
    trap_init();

    if (t11_bug_cnt) fail("T11-desync", t11_bad_mepc, 0, t11_bug_cnt);
    uart_puts("HAMMER: T11 traps=0x"); print_hex_n(t11_traps);
    uart_puts(" bug=0x");              print_hex_n(t11_bug_cnt);
    uart_puts(" bad_mepc=0x");         print_hex_n(t11_bad_mepc);
    uart_puts(" bad_mscr=0x");         print_hex_n(t11_bad_mscratch);
    uart_puts(" errs=0x");             print_hex(g_errors - before);
}

int main(void) {
    uart_init();
    trap_init();
    g_errors = 0;

    uart_puts("\r\nHAMMER: START\r\n");

    test_linear(4u * 1024u * 1024u);   // 4 MB linear sweep
    test_same_set(256u, 4u);           // 256 aliasing lines (8 MB), 4 passes
    test_subword(1u * 1024u * 1024u);  // 1 MB of byte stores
    test_amoadd(2048u, 8u);            // 64 KB working set (> cache), 8 passes
    test_lrsc(2048u, 8u);              // same, via LR/SC cmpxchg
    test_lrsc_semantics();             // directed reservation success/fail
    test_csr_swap();                   // csrrw rd==rs1 (trap-entry instruction)
    test_mtrap_tp();                   // M-mode (OpenSBI-style) trap + unaligned
    test_s_to_m_trap_tp();             // S->M ecall trap (the exact Linux SBI path)
    test_trap_storm();                 // back-to-back trap/mret priv-vs-PC desync
    test_strap_tp();                   // S-mode trap tp/SPP survival (must be last)

    uart_puts("HAMMER: DONE total_errs=0x"); print_hex(g_errors);
    uart_puts(g_errors ? "RESULT FAIL\r\n" : "RESULT PASS\r\n");

    while (1) asm volatile("nop");
}
