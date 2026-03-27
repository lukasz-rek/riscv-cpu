Just making a riscv cpu to learn out of order execution in depth and to just benchmark random bits of knowledge I've had. 
* Is making fancy computer arithmetic faster than just + in Vivado?
* Is out of order exec that much better (probably but idk)?
* What caching and branch prediction seems to work better
* How does that all work out on actual hardware next to me?
* Other stuff like this

They should've tought me all that at uni but they only teased it.

Currently, there is a simple riscv32i implementation that does everything in a single cycle and stalls when reading memory from BRAM. Slow but works. It also has .tcl script that compiles everything for a kria kv260 so the timing/area impacts can be measured. 

# Current stats

My Ryzen 9 5900 HS when running my ported benchmark doesn't even reach 100% util on single core (lol) but has below scores.
```
2K performance run parameters for coremark.
CoreMark Size    : 666
Total ticks      : 16878
Total time (secs): 16
Iterations/Sec   : 37500
Iterations       : 600000
Compiler version : GCC15.2.1 20260209
Compiler flags   : -O3
Memory location  : STACK
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0xa14c
Correct operation validated. See README.md for run and reporting rules.
```
Whereas my beatiful core achieves way less. With M extension at 20 MHz (max without pipelining)
```
2K performance run parameters for coremark.
CoreMark Size    : 666
Total ticks      : 511118594
Total time (secs): 25
Iterations/Sec   : 32
Iterations       : 800
Compiler version : GCC15.2.0
Compiler flags   : -O3
Memory location  : STACK
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0xcc42
Correct operation validated. See README.md for run and reporting rules.
```
With basic pipelining it's only slightly better as it still has lots of stalls and CPI hovers ~2.25

```
2K performance run parameters for coremark.         
CoreMark Size    : 666                                               
Total ticks      : 483976148                                         
Total time (secs): 21                                                
Iterations/Sec   : 38                                                
Iterations       : 800                                               
Compiler version : GCC15.2.0                                         
Compiler flags   : -O3                                               
Memory location  : STACK                                             
seedcrc          : 0xe9f5                                            
[0]crclist       : 0xe714                                            
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0xcc42
Correct operation validated. See README.md for run and reporting rule.
```

Gets improved down to 1.5 CPI, with some look ahead in decode, can be better if moved to exec and including load look ahead
```
2K performance run parameters for coremark.
CoreMark Size    : 666
Total ticks      : 327379284
Total time (secs): 14
Iterations/Sec   : 57
Iterations       : 800
Compiler version : GCC15.2.0
Compiler flags   : -O3
Memory location  : STACK
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0xcc42
Correct operation validated. See README.md for run and reporting rules.
Program completed at cycle 328144857 (sim time 16407243025)
CPI was ~ 1.523858
```
With a better look ahead CPI can become ~ 1.25
```
Starting coremark
2K performance run parameters for coremark.
CoreMark Size    : 666
Total ticks      : 268901552
Total time (secs): 11
Iterations/Sec   : 72
Iterations       : 800
Compiler version : GCC15.2.0
Compiler flags   : -O3
Memory location  : STACK
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0xcc42
Correct operation validated. See README.md for run and reporting rules.
```
With proper nonrestoring division we get 75 MHz and 
```
Starting coremark
2K performance run parameters for coremark.
CoreMark Size    : 666
Total ticks      : 806703110
Total time (secs): 10
Iterations/Sec   : 240
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
So now cpu is only x 156 times slower :)

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
