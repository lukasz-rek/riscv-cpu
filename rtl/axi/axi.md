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
This adds up to 32KB per cache, all in BRAM. The management data is also stored in BRAM for better resource utilization, though this necessitates an additional cycle for valid bit lookup, after which the data can be served on the cycle after that. So for a cache access we need to pull relevant control bits (check if everything's ok), then fetch data for subsequent cycle. For speedup, we keep the most recent control bits as then we can just give data immediately on next access.



## AXI Master Behaviour

Since the cache signals ready data on next cycle on if !stall && !miss, then in this case the master simply forwards whatever data is there in next cycle and doesn't do anything. However if !stall && miss, then depending on whether it is dirty eviction it performs the appropriate cache refill.

Similarly, the shown interface works on the same rules though with lesser complexity. If stall_I/D is up, then the core waits until it goes low. This signals the operation is performed on the following cycle.
