This is just a riscv32 + extensions CPU I'm making for (sometimes questionable) fun. It is pipelined now and while the initial goal was to try out some Out of Order execution/Tomasulo stuff I'm going on a sidequest to port linux or other programs to this thing and just seeing where I end up.

Stuff still to be done before linux ready:
- [x] Add proper resets from kv260 host
- [x] Move memory from BRAM into DDR via axi
  - [x] Will probably require some smol cache to not tank perf
      - [ ]   Associative cache might give improvements, but current impl good enough for now
- [x] Tidy up UART interface (also anything MMIO is good for now)
- [x] Implement A extension (should be easy with only 1 cpu)
- [ ] Rest of privilege spec I need, S/U modes etc.
- [x] ISR handling + selected traps
- [ ] Implement MMU (theoretically not needed, but I wanna do it)
- [x] Finalize pick for linux version (got some ideas) -> Buildroot likely

# Current stats

See [Benchmarks](docs/benchmarks.md) for whole progress, but this is latest results:

125 MHz, riscv32im, pipelined with access to 1GB DDR over AXI, 2 32 KB I and D caches.
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


# Build

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
./scripts/run_sim.sh axi_tb 
./scripts/run_sim.sh module_name

# You can also run all ISA checks, tho this requires some setup and can maybe be run better than you. Point to directory that has .elf files of each self-checking binary
./scripts/run_arch_test.sh folder_name

```

# Zephyr

Use the board/soc files in the /zephyr folder. Then `west build - b plyta` with any other needed parameters.  
 
