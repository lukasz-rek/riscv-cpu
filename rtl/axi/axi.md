# AXI Idea

For the whole CPU we need one read port for the instruction fetching and another read/write set for the data access. AXI is considerably slower than the CPU, hence caches are nice and we're combining them into a single *axi_master* module.

We need 2 caches (I and D), both are their own modules which makes it easier to test them. The AXI master module holds both caches and handles the data access between or any possible misses.

Finally, since I'm inferring the cache into BRAM I need to use RAMB36E2 which limits possible cache sizes but makes it very efficient.

## Interface

Thanks to the cache, this can appear as a simple clocked BRAM memory module to the outside with the addition of a *stall* signal which gets triggered on cache misses. So we get:

* clk
* rst_n
* axi_if.master - interface for an AXI master output
* [ADDR_WIDTH] addr1
* [ADDR_WIDTH] addr2 - used for both reads and writes
* [DATA_WIDTH] rd_data1
* [DATA_WIDTH] rd_data2
* [DATA_WIDTH] wr_data
* wr_en
* read_en - read enable needed since trying to read sth accidentaly can trigger expensive cache miss
* [4] byte_en 
* stall_I/D - held high as long previous operation still running, ignores inputs in meantime, gives out results on lowedge, seperated for both caches

A cache itself takes on most of the interface but must also indicate if a miss occured, so the AXI master can fetch from main memory
* [ADDR_WIDTH] addr
* [DATA_WIDTH] rd_data
* [DATA_WIDTH] wr_data
* wr_en
* read_en
* miss -> indicates the requested address is not there. Current contents are outputted on rd_data, regardless of whether we wanted read/write.
* cache_load_en -> used to indicate to the cache to replace sth in cache but using 

## Access Mechanics

Pretty simple in most cases when latency masked by BRAM. When luck runs out, stall goes high and we need to wait. Since we have single controller the special case is when both instruction and data miss, but we only need stall one cycle then.

For cache eviction (we doing write-back):
1. We try to read/write sth from cache
2. Since it's not there we see *miss* signal go up and the soon to be evicted data shows up
3. We write the contents over axi, next we read the requested data
4. Once requested data is here we insert it into cache
  * If we wanted to read, then in the same cycle we output it from axi_master
  * If we wanted to write, we insert our changes when inserting into cache

If both I and D cache miss, then we retrieve I first, then D and then deassert both stall_I/D
