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

    logic                cache_load_1;
    logic                cache_load_2;
    logic [127:0]        cache_load_data;

    logic [31:0]         rd_data;
    logic                miss;
    logic                dirty_evict;

    // ---------- DUT ----------
    axi_cache dut (
        .clk             (clk),
        .rst_n           (rst_n),
        .addr            (addr),
        .wr_data         (wr_data),
        .wr_en           (wr_en),
        .rd_en           (rd_en),
        .byte_en         (byte_en),
        .cache_load_1    (cache_load_1),
        .cache_load_2    (cache_load_2),
        .cache_load_data (cache_load_data),
        .rd_data         (rd_data),
        .miss            (miss),
        .dirty_evict     (dirty_evict)
    );

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
        cache_load_1    = 0;
        cache_load_2    = 0;
        cache_load_data = '0;

        repeat (4) @(posedge clk);
        rst_n = 1;

        // TODO: tests here

        #1000 $finish;
    end

    // ---------- Waves ----------
    initial begin
        $dumpfile("tb_axi_cache.vcd");
        $dumpvars(0, tb_axi_cache);
    end

endmodule
