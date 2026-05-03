# Latest score 
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
For comparison, Ryzen 9 5900 HS (it didn't 100% the core so it might even just be memory bound and could be better lol)
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

# Step by step
Basic riscv32mi at 20 MHz (max without pipelining)
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
However, this leads to instabilities especially around reset handling. After fixing some Vivado warnings and shifting stuff around we're forced to drop down to 58 MHz :(, though now sim values are kinda accurate and no more funky behaviour.

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
Only AXI versions below:
