This is just a riscv32 + extensions CPU I'm making for (sometimes questionable) fun. It is pipelined now and while the initial goal was to try out some Out of Order execution/Tomasulo stuff I'm going on a sidequest to port linux or other programs to this thing and just seeing where I end up.

Stuff still to be done before linux ready:
- [ ] Add proper resets from kv260 host
- [ ] Move memory from BRAM into DDR via axi
  - [ ] Will probably require some smol cache to not tank perf
- [ ] Tidy up UART interface
- [ ] Implement A extension
- [ ] Implement MMU
- [ ] Finalize pick for linux version (got some ideas)

# Current stats

See [Benchmarks](docs/benchmarks.md) for whole progress, but seems we are only stable at those stats for now:

58 MHz, riscv32mi, non-restoring division with CPI ~1.25
```
Starting coremark
2K performance run parameters for coremark.
CoreMark Size    : 666
Total ticks      : 806703110
Total time (secs): 13
Iterations/Sec   : 184
Iterations       : 2400
Compiler version : GCC15.2.0
Compiler flags   : -O3
Memory location  : STACK
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0x382f
Correct operation validated. See README.md for run and reporting rules.
```

# Build

Have verilator, verible, gtkwave and make installed

```
# To build and then run main core with the code from code/main.c
make build run

# To re-compile code in code/main.c, tho it should happen with above target
make code

# For quick linting checks or formatting with verible
make lint
make format

# To build & run for specific module
make build TOP_MODULE_NAME=register_file run

# To check some waves
gtkwave logs/waveform.fst


```
