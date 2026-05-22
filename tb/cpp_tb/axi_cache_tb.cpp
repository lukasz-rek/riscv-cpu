#include "Vaxi_cache.h"
#include "verilated.h"
#include "verilated_fst_c.h"
#include <cstdio>
#include <cstdlib>

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    Vaxi_cache dut;
    VerilatedFstC tfp;
    dut.trace(&tfp, 99);
    tfp.open("logs/axi_cache_tb.fst");

    uint64_t t = 0;
    auto tick = [&]() {
        dut.clk = 1; dut.eval(); tfp.dump(t); t += 5;
        dut.clk = 0; dut.eval(); tfp.dump(t); t += 5;
    };
    auto check = [&](bool cond, const char* msg) {
        if (!cond) {
            fprintf(stderr, "[FAIL] t=%lu: %s\n", t, msg);
            for (int i = 0; i < 10; i++) tick();
            tfp.close();
            exit(1);
        }
    };

    // Reset
    dut.rst_n = 0;
    for (int i = 0; i < 4; i++) tick();
    dut.rst_n = 1;

    // 1. Cold miss — drive at negedge, outputs settle after eval
    dut.clk = 0; dut.eval(); tfp.dump(t); t += 5; // negedge
    dut.addr  = 0x00000000;
    dut.rd_en = 1;
    dut.eval();
    check(dut.stall == 1, "1. expected stall");

    tick();
    check(dut.miss  == 1, "1. expected miss during refill");
    check(dut.stall == 1, "1. expected stall during refill");

    tick();

    printf("All tests passed\n");
    tfp.close();
}
