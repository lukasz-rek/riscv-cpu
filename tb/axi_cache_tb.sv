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
    logic                stall;
    logic                dirty_evict;
    logic [255:0]        cache_evicted_data;
    logic [31:0]         evicted_addr;

    // ---------- DUT ----------
    axi_cache dut (.*);

    // ---------- Clock ----------
    initial clk = 0;
    always #5 clk = ~clk;

    // ---------- Clocking block ----------

    task automatic check(input logic cond, input string msg);
        if (!cond) begin
            longint unsigned fail_time;
            fail_time = $time;
            repeat(1) @(posedge clk);
            $error("Assert failed at t=%0t: %s", fail_time, msg);
            $finish;
        end
    endtask

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

        // 1. Cold miss — drive via clocking block, sample next cycle
        $display("1. Cold Miss Test...");
        @(negedge clk);
        addr  = 32'h0000_0000;
        rd_en = 1;

        #1;
        check(stall == 1, "1. Expect stall after setting address");
        @(negedge clk);
        check(miss == 1, "1. expected miss during 1st lookup");
        check(stall == 0, "1. expected low stall during lookup");

        @(negedge clk);
        check(miss  == 1, "1. expected miss during refill");
        check(stall == 1, "1. expected stall during refill");

        repeat (4) @(posedge clk); // Wait few cycles simulating AXI read
        @(negedge clk);
        // Now we do refill
        cache_load = 2'b01;
        cache_load_data = 128'hDEAD_BEEF_ABCD_ABCD_CAFE_BABE_EBEB_EBEB;

        check(miss  == 1, "1. expected miss during 1st load");
        check(stall == 1, "1. expected stall during 1st load");

        @(negedge clk);

        cache_load = 2'b10;
        cache_load_data = 128'hAAAA_BBBB_CCCC_DDDD_EEEE_FFFF_0101_0202;

        @(negedge clk);
        // Now we can check if it reads nicely
        cache_load = 2'b00;

        check(miss == 0, "1. expected low miss after refill");
        check(stall == 0, "1. expected low stall after refill");

        @(negedge clk);
        check(rd_data == 32'hEBEB_EBEB, "1. expeced diff data from read");

        $display("2. Check if consecutive reads from one cache line are faster");
        addr = 32'h0000_001C; // Last loaded word
        #1;
        check(miss == 0, "2. expected low miss in consecutive read");
        check(stall == 0, "2. expected low stall in consecutive read");

        @(negedge clk);

        check(rd_data == 32'hAAAA_BBBB, "2. expeced diff data from consecutive read");
        rd_en = 0;

        $display("3. Check if writes work");
         addr = 32'h0000_0008;
         wr_en = 1;
         wr_data = 32'hDCBA_DCBA;
         byte_en = '1;

         #1;
         check(miss == 0, "3. Expected low miss when writing to valid cache line");
         check(stall == 0, "3. Expected low stall when writing to valid cache line");

         @(negedge clk);
         // Should be written now so let's check it

         wr_en = 0;
         rd_en = 1;
         #1;
         check(miss == 0, "3. Expected low miss when reading valid cache line");
         check(stall == 1, "3. Expected high stall when reading valid cache line");

         @(negedge clk);

         check(miss == 0, "3. Expected low miss when reading from valid cache line");
         check(stall == 0, "3. Expected low stall when reading from valid cache line after write");

         @(negedge clk);
         check(rd_data == 32'hDCBA_DCBA, "3. Expected diff data after write");

         $display("4. Check that eviction works and is marked properly");
          addr = 32'h0000_8000;
          #1;
          check(stall == 1, "4. Expected stall when starting evicting");

          // Wait 2 cycles for stall to go down to check if we have dirty_evict
          @(negedge clk);
          @(negedge clk);
          check(miss == 1, "4. Expected miss when evicting");
          check(dirty_evict == 1, "4. Expected dirty evict when doing dirty evict");
          check(stall == 0, "4. Expected low stall when giving eviction result");

          check(evicted_addr == 32'h0000_0000, "wrong evicted addr");
          check(cache_evicted_data == 256'hAAAA_BBBB_CCCC_DDDD_EEEE_FFFF_0101_0202_DEAD_BEEF_DCBA_DCBA_CAFE_BABE_EBEB_EBEB,"wrong evicted data");

          repeat (8) @(posedge clk); // Wait few cycles simulating AXI write + read


          check(miss == 1, "4. Expected miss during eviction refill");
          cache_load = 2'b01;
          cache_load_data = 128'h0101_0202_0303_0404_0505_0606_0707_0808;

          @(negedge clk);


          cache_load = 2'b10;
          cache_load_data = 128'hAAAA_BBBB_CCCC_DDDD_EEEE_FFFF_0101_0202;

          @(negedge clk);

          cache_load = 2'b00;

          check(miss == 0, "1. expected low miss after refill");
          check(stall == 0, "1. expected low stall after refill");

          @(negedge clk);

          check(rd_data == 32'h0707_0808, "Wrong data after cache eviction refill");
          rd_en = 0;

          @(negedge clk);
          check(dut.cache_state == '0, "Cache doesn't go off when rd_en low");


        $display("All cache tests passed!");
        $finish;
    end

    // ---------- Waves ----------
    initial begin
        $dumpfile("logs/axi_cache_tb.fst");
        $dumpvars(0, axi_cache_tb);
    end

endmodule
