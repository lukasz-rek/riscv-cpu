# AXI Idea

For the whole CPU we need one read port for the instruction fetching and another read/write set for the data access. AXI is considerably slower than the CPU, hence caches are nice and we're combining them into a single *axi_master* module.



## Interface

Thanks to the cache, this can appear as a simple clocked BRAM memory module to the outside with the addition of a *stall* signal which gets triggered on cache misses. So we get:

* clk
* rst_n
* [ADDR_WIDTH] addr1
* [ADDR_WIDTH] addr2 - used for both reads and writes
* [DATA_WIDTH] rd_data1
* [DATA_WIDTH] rd_data2
* [DATA_WIDTH] wr_data
* wr_en
* read_en - read enable needed since trying to read sth accidentaly can trigger expensive cache miss
* [4] byte_en 
* stall_I/D - held high as long previous operation still running, ignores inputs in meantime, gives out results on lowedge, seperated for both caches

## Access Mechanics

Pretty simple in most cases when latency masked by BRAM. When luck runs out, stall goes high and we need to wait. Since we have single controller the special case is when both instruction and data miss, but we only need stall one cycle then.