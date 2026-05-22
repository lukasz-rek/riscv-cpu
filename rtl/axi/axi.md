# AXI + CACHE Interatcions

If a memory access within the core is deemed to be going outside, then it is routed to the _axi_master_. There depending on how the cache itself behaves, the data might be passed directly from cache when it's ready, or perform a cache miss. The _axi_master_ hides it all away from the core and silently handles all of that while simply asserting the relevant _stall_ signal.

## Cache Behaviour

The cache has below params for both I and D modules:
```
Line size:   32 bytes (8 words)
Num sets:    1024
Cache size:  32 KB
Tag bits:    17
Index bits:  10
Offset bits: 5
```
This adds up to 32KB per cache, all in BRAM. The management data is also stored in BRAM for better resource utilization, though this necessitates an additional cycle for valid bit lookup, after which the data can be served on the cycle after that. The cache will near always assert a stall signal, and only when a lookup has been done and the bit is valid will it go low, outputting data on the cycle after it. This roughly means that. 

Cycle 0: ADDR, RD_EN | WR_EN, DATA

Cycle 1: If miss && stall == 0, then valid operation on next cycle. Else it is a miss and we need to start refill actions.

Cycle 2: Valid data shown

## AXI Master Behaviour

TBD
