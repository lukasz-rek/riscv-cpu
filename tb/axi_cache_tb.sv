`timescale 1ns/1ps

module axi_cache_tb;

    // ---------- DUT signals ----------
    logic                clk;
    logic                rst_n;

    logic [31:0]         addr;
    logic [31:0]         wr_data;
    logic                wr_en;
    logic                rd_en;
    logic [3:0]          byte_en;

    logic [1:0]          cache_load;
    logic [127:0]        cache_load_data;

    logic [31:0]         rd_data;
    logic                miss;
    logic                dirty_evict;
    logic [127:0]        cache_evicted_data;


    // ---------- DUT ----------
    axi_cache dut (.*);

    // ---------- Clock ----------
    initial clk = 0;
    always #5 clk = ~clk;   // 100 MHz

    // ---------- Reset + init ----------
    initial begin
        rst_n           = 0;
        addr            = '0;
        wr_data         = '0;
        wr_en           = 0;
        rd_en           = 0;
        byte_en         = '0;
        cache_load      = 2'b00;
        cache_load_data = '0;

        repeat (4) @(posedge clk);
        rst_n = 1;

        // 1. Try to access sth, since it's our first load it fails
        @(negedge clk);
        addr = 32'h0000_0000;
        rd_en = 1;
        #1; // Moment to settle
        assert(miss == 1) else $error("expected miss, got %b", miss);
        assert(dirty_evict == 0) else $error("Evicted memory marked as dirty when it wasn't");

        // 2. Load sth after a miss, check it worked, verify miss is up during whole process
        @(negedge clk);
        cache_load = 2'b01;
        addr = 32'h0000_0000;
        cache_load_data = 128'hDEAD_BEEF_ABCD_ABCD_CAFE_BABE_EBEB_EBEB;
        assert(miss == 1) else $error("expected miss still up during 1st load, got %b", miss);

        @(negedge clk);
        cache_load = 2'b10;
        cache_load_data = 128'hAAAA_BBBB_CCCC_DDDD_EEEE_FFFF_0101_0202;
        assert(miss == 1) else $error("expected miss still up during 2nd load, got %b", miss);

        @(negedge clk);
        cache_load = 2'b00;
        rd_en = 1;
        #1
        assert(miss == 0) else $error("expected no miss, got %b", miss);
        @(negedge clk);
        // Now we should have BRAM output that is correct on first word
        assert(rd_data == 32'hEBEB_EBEB) else $error("Expected EBEB_EBEB, got %h", rd_data);
        addr = 32'h0000_001C; // Last loaded word

        @(negedge clk);
        assert(rd_data == 32'hAAAA_BBBB) else $error("Expected AAAA_BBBB, got %h", rd_data);
        rd_en = 0;

        // 3. Try to write, see if it sticks
        addr = 32'h0000_0008;
        wr_en = 1;
        wr_data = 32'hDCBA_DCBA;
        byte_en = '1;

        #1; // Settle
        assert(miss == 0) else $error("expected no miss for write, got %b", miss);

        @(negedge clk);
        // Should be written now
        rd_en = 1;
        wr_en = 0;
        byte_en = '0;
        addr = 32'h0000_0008;
        #1;
        assert(miss == 0) else $error("expected no miss when reading write, got %b", miss);

        @(negedge clk);
        assert(rd_data == 32'hDCBA_DCBA) else $error("Expected DCBA_DCBA, got %h", rd_data);
        rd_en = 1;

        // 4. Evict it, now that it's dirty we need to capture evicted data and verify

        addr = 32'h0000_4000;
        #1;
        assert(miss == 1) else $error("expected miss during eviction, got %b", miss);
        assert(dirty_evict == 1) else $error("Evicted memory not marked dirty when it was");

        // Verify proper data evicted 1st time
        @(negedge clk);
        rd_en = 0;
        assert(cache_evicted_data == 128'hDEAD_BEEF_DCBA_DCBA_CAFE_BABE_EBEB_EBEB) else $error("Wrong cache data 1st eviction, got %h", cache_evicted_data);


        @(negedge clk);
        // And second time
        assert(cache_evicted_data == 128'hAAAA_BBBB_CCCC_DDDD_EEEE_FFFF_0101_0202) else $error("Wrong cache data 2nd eviction, got %h", cache_evicted_data);


       // Wait and write proper data
       repeat (4) @(negedge clk);
       assert(miss == 1) else $error("expected miss during eviction, got %b", miss);
       cache_load = 2'b01;
       addr = 32'h0000_4000;
       cache_load_data = 128'h0101_0202_0303_0404_0505_0606_0707_0808;
       @(negedge clk);
       assert(miss == 1) else $error("expected miss during eviction, got %b", miss);
       cache_load = 2'b10;
       cache_load_data = 128'hAAAA_BBBB_CCCC_DDDD_EEEE_FFFF_0101_0202;
       @(negedge clk);
       cache_load = 2'b00;
       rd_en = 1;
       #1
       assert(miss == 0) else $error("expected no miss, got %b", miss);
       @(negedge clk);
       assert(rd_data == 32'h0707_0808) else $error("Expected EBEB_EBEB, got %h", rd_data);
       addr = 32'h0000_001C; // Last loaded word

       @(negedge clk);
       assert(rd_data == 32'hAAAA_BBBB) else $error("Expected AAAA_BBBB, got %h", rd_data);
       rd_en = 0;


        $display("All cache tests passed!");
        $finish;
    end

    // ---------- Waves ----------
    initial begin
        $dumpfile("logs/axi_cache_tb.fst");
        $dumpvars(0, axi_cache_tb);
    end

endmodule
