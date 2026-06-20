This is just a riscv32 + extensions CPU I'm making for (sometimes questionable) fun. The initial goal was to try out some Out of Order execution/Tomasulo stuff that make up modern fast computers but I went on a sidequest to port Linux to this core. Currently it runs noMMU Linux and Zephyr RTOS and baremetal programs/benchmarks.

# Current stats

See [Benchmarks](docs/benchmarks.md) for whole progress, but this is latest results:

125 MHz, riscv32ima, pipelined with access to 1GB DDR over AXI, 2 32 KB I and D caches.
Supports a timer ISR, selected traps and 16550 UART. 

Runs Zephyr with the attached board/soc files. 

It's also passing the riscv ISA [tests](https://github.com/riscv/riscv-arch-test) for I,M,A,Zicsr, Zicntr extensions.
```
Starting coremark
2K performance run parameters for coremark.
CoreMark Size    : 666
Total ticks      : 1685332207
Total time (secs): 13
Iterations/Sec   : 230
Iterations       : 3000
Compiler version : GCC15.2.0
Compiler flags   : -O3
Memory location  : STACK
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0xcc42
Correct operation validated. See README.md for run and reporting rules.

Got 1690360788 cycles and 904021454 instructions
CPI: ~1.86
```
Some utilization results from KRIA KV260 - Zynq Ultrascale+
```

```
# Architecture

## Core

It's a pipelined core with 5 stages and forwarding. 

IF -> ID -> EXEC/CSR -> MEM -> RF

It has memory access to 1 GB of main DDR memory over AXI via 2 32KB I/D Caches. Since it is only single hart, the support for atomics and cache coherency is naturally simplified though with some bus reworks it could quickly support more cores. 

CSR/PRIVILEGE handling is done alongside EXEC, as well as flushing and various stalls. Branch prediction always takes the jump as it's good enough with loops and I've made too many branch predictors already, so I can leave some perf on the table here. 

## Peripherals
To make porting easier I added some MMIO devices at their usual/spec-defined addresses:
* CLINT - 0x0c00_0000
* PLIC - 0x0200_0000
* 16550 UART - 0x1000_0000

They're very simple and don't support all features but are perfect for porting as it's just a few lines of verilog as opposed to writing firmware patches or making wild device trees.
# Build/Sim

After I finalize block design I hope to make scripts that regenerate it and run whole synth/impl/bit flow, but a backup is there in *scripts* folder. Once you have it

```

# To re-compile code in code/main.c, or coremark
make code
make coremark

# For quick linting checks or formatting with verible
make lint
make format

# To build & run for specific module, especially the non vivado needing tests
make build TOP_MODULE_NAME=register_file run

# Whole core integration tests use Vivado AXI VIP, so require a test.bd + xsim
./scripts/run_sim.sh axi_tb # Main test file that can run all binaries like linux/zephyr etc. Very useful.
./scripts/run_sim.sh module_name

# You can also run all ISA checks, tho this requires some setup and can maybe be run better than you. Point to directory that has .elf files of each self-checking binary
./scripts/run_arch_test.sh folder_name

```

# Zephyr

Use the board/soc files in the /zephyr folder. Then `west build - b plyta` with any other needed parameters.  

# Linux

Use .config folders in Linux for Buildroot/Linux/uclib/busybox. Note that noMMU Linux is not exactly the intended way to run Linux so some trickery may be required. My hint is to select all the options that simplify memory allocation/process spawning but the names may have changed from what I have.
 
# Remaining improvements
- [ ] Add MMU stage -> should make Linux much more usable
- [ ] Add more cache settings
- [ ] Rework memory controller
  - [ ] This would allow measurable metrics for OoO.
- [ ] Some cool extensions? C,V, bit manipulation, more?
- [ ] I had a sensible critical path in decode but it seems that congestions from CSR/PRIV moved that. I should look into it.