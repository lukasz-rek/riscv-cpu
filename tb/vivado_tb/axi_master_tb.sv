`timescale 1ns / 1ps

import axi_vip_pkg::*;
import axi_test_axi_vip_0_0_pkg::*;

module axi_master_tb;

    logic clk   = 0;
    logic rst_n = 0;

    always #8.62 clk = ~clk;  // ~58 MHz

    // Memory-side stimulus to the axi_master
    logic [31:0] addr_d;
    logic [31:0] addr_i;
    logic        rd_en_d;
    logic rd_en_i;
    logic wr_en;
    logic [31:0] rd_data_d;
    logic [31:0] rd_data_i;
    logic        stall_D;
    logic stall_I;
    logic [31:0] wr_data;
    logic [3:0] byte_en;

    logic [127:0] evicted_line;

    // AXI interface between DUT and VIP
    axi_if m_axi_if();

    // ── DUT ──
    axi_master #(
        .ADDR_WIDTH (32),
        .DATA_WIDTH (32),
        .START_ADDR (36'h8_4000_0000)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .addr_i    (addr_i),
        .addr_d    (addr_d),
        .wr_data   (wr_data),
        .byte_en   (byte_en),
        .wr_en     (wr_en),
        .rd_en_i   (rd_en_i),
        .rd_en_d   (rd_en_d),
        .rd_data_i (rd_data_i),
        .rd_data_d (rd_data_d),
        .stall_I   (stall_I),
        .stall_D   (stall_D),
        .m_axi     (m_axi_if.master)
    );

    // ── AXI VIP (slave mode) ──
    axi_test_wrapper vip_inst (
        .aclk_0           (clk),
        .aresetn_0        (rst_n),
        // AR
        .S_AXI_0_araddr   (m_axi_if.araddr),
        .S_AXI_0_arlen    (m_axi_if.arlen),
        .S_AXI_0_arsize   (m_axi_if.arsize),
        .S_AXI_0_arburst  (m_axi_if.arburst),
        .S_AXI_0_arlock   (m_axi_if.arlock),
        .S_AXI_0_arcache  (m_axi_if.arcache),
        .S_AXI_0_arprot   (m_axi_if.arprot),
        .S_AXI_0_arqos    (m_axi_if.arqos),
        .S_AXI_0_arregion (4'b0),
        .S_AXI_0_arvalid  (m_axi_if.arvalid),
        .S_AXI_0_arready  (m_axi_if.arready),
        // R
        .S_AXI_0_rdata    (m_axi_if.rdata),
        .S_AXI_0_rresp    (m_axi_if.rresp),
        .S_AXI_0_rvalid   (m_axi_if.rvalid),
        .S_AXI_0_rlast    (m_axi_if.rlast),
        .S_AXI_0_rready   (m_axi_if.rready),
        // AW/W/B — connected but unused
        .S_AXI_0_awaddr   (m_axi_if.awaddr),
        .S_AXI_0_awlen    (m_axi_if.awlen),
        .S_AXI_0_awsize   (m_axi_if.awsize),
        .S_AXI_0_awburst  (m_axi_if.awburst),
        .S_AXI_0_awlock   (m_axi_if.awlock),
        .S_AXI_0_awcache  (m_axi_if.awcache),
        .S_AXI_0_awprot   (m_axi_if.awprot),
        .S_AXI_0_awqos    (m_axi_if.awqos),
        .S_AXI_0_awregion (4'b0),
        .S_AXI_0_awvalid  (m_axi_if.awvalid),
        .S_AXI_0_awready  (m_axi_if.awready),
        .S_AXI_0_wdata    (m_axi_if.wdata),
        .S_AXI_0_wstrb    (m_axi_if.wstrb),
        .S_AXI_0_wlast    (m_axi_if.wlast),
        .S_AXI_0_wvalid   (m_axi_if.wvalid),
        .S_AXI_0_wready   (m_axi_if.wready),
        .S_AXI_0_bresp    (m_axi_if.bresp),
        .S_AXI_0_bvalid   (m_axi_if.bvalid),
        .S_AXI_0_bready   (m_axi_if.bready)
    );

    axi_test_axi_vip_0_0_slv_mem_t slv_agent;

    task automatic check(input logic cond, input string msg);
        if (!cond) begin
            longint unsigned fail_time;
            fail_time = $time;
            repeat(1) @(posedge clk);
            $error("Assert failed at t=%0t: %s", fail_time, msg);
            $finish;
        end
    endtask

    initial begin
        slv_agent = new("slv_agent", vip_inst.axi_test_i.axi_vip_0.inst.IF);
        slv_agent.start_slave();

        // Preload the full 32-byte cache line at START_ADDR
        // Word layout inside the line (little-endian word order):
        //   offset 0x00: 0xDEADBEEF   <- what the read at addr 0x0 should return
        //   offset 0x04: 0x22222222
        //   offset 0x08: 0x33333333
        //   offset 0x0C: 0x44444444
        //   offset 0x10: 0x55555555
        //   ...
        slv_agent.mem_model.backdoor_memory_write(
            36'h8_C000_0000,
            128'h44444444_33333333_22222222_DEADBEEF,
            16'hFFFF
        );
        slv_agent.mem_model.backdoor_memory_write(
            36'h8_C000_0010,
            128'h88888888_77777777_66666666_55555555,
            16'hFFFF
        );
        slv_agent.mem_model.backdoor_memory_write(
            36'h8_C000_8000,
            128'hABCDABCD_BCDADBCA_CCDDDDCC_AABBBBAA,
            16'hFFFF
        );
        slv_agent.mem_model.backdoor_memory_write(
            36'h8_C000_0040,
            128'hFEFEFEFE_CDCDCDCD_0F0F0F0F_ACACACAC,
            16'hFFFF
        );



        addr_d  = 32'h0;
        addr_i = '0;
        rd_en_d = 1'b0;
        rd_en_i = 1'b0;
        wr_en = 1'b0;

        rst_n = 0;
        #500;
        rst_n = 1;
        $display("[TB] Reset released at %0t", $time);

        $display("Checking D reads");
        @(negedge clk);
        addr_d  = 32'h8000_0000;
        rd_en_d = 1'b1;
        #1; // Delay moment for stall_D to actually propagate

        check(stall_D == 1, "Stall high on start of first read");
        // Wait for the miss to be serviced
        while (stall_D) @(negedge clk);
        @(negedge clk);

        $display("[TB] rd_data_d = 0x%08h (expected 0xDEADBEEF)", rd_data_d);
        check(rd_data_d == 32'hDEADBEEF, "Diff data expected on first read");
        addr_d  = 32'h8000_000C;
        #1;
        check(stall_D == 1, "Stall low on start of second read");

        while (stall_D) @(negedge clk);
        @(negedge clk);

        check(rd_data_d == 32'h4444_4444, "Wrong data on second read");
        rd_en_d = 1'b0;

        @(negedge clk);
        $display("Checking D RAW");
        // Now just do a write, later verify it was modified
        wr_en = 1'b1;
        wr_data = 32'hABCD_DCBA;
        byte_en = '1;
        #1;
        check(stall_D == 1, "Stall high on write");

        while (stall_D) @(negedge clk);
        @(negedge clk);
        wr_en = 1'b0;
        rd_en_d = 1'b1;
        #1;
        check(stall_D == 1, "Stall high on read after write");
        while (stall_D) @(negedge clk);
        @(negedge clk);

        check(rd_data_d == 32'hABCD_DCBA, "Wrong data on RAW");
        $display("Checking D eviction");

        // Now start doing reads that evict previous line and verify it got written to AXI
        addr_d = 32'h8000_8000;

        #1;
        check(stall_D == 1, "Stall on eviction read");

        while (stall_D) @(negedge clk);
        @(negedge clk);


        check(rd_data_d == 32'hAABB_BBAA, "Incorrect data after eviction");

        evicted_line = slv_agent.mem_model.backdoor_memory_read(36'h8_c000_0000);
        assert(evicted_line[127:96] === 32'hABCD_DCBA)
            else $error("[TB] Eviction mismatch: got 0x%08h", evicted_line[127:96]);


        $display("Checking D + I concurrent access");
        // Now let's test that doing reads on i cache works
        rd_en_d = 0;
        rd_en_i = 1;
        addr_i = 32'h8000_0040;

        #1;

        check(stall_I == 1, "I stall not asserted on read");
        check(stall_D == 0, "D stall asserted on I-only read");

        while(stall_I) @(negedge clk);
        @(negedge clk);

        check(rd_data_i == 32'hACAC_ACAC, "I data not correct");

        @(negedge clk);
        // And that missing on both prioritizes I and doesn't mess anything up
        rd_en_d = 1;
        addr_i = 32'h8000_0000;
        addr_d = 32'h8000_0000;
        #1;

        check(stall_I == 1, "I stall not asserted on multi read");
        check(stall_D == 1, "D stall not asserted on multi read");

        // First I stall gets serviced
        while(stall_I) @(negedge clk);
        @(negedge clk);

        rd_en_i = 0;
        check(rd_data_i == 32'hDEAD_BEEF, "I data diff on mutli read");
        check(stall_D == 1, "D stall went low during multi read");

        while(stall_D) @(negedge clk);
        @(negedge clk);

        rd_en_d = 0;
        check(rd_data_d == 32'hDEAD_BEEF, "D data diff on mutli read");

        #1;
        $display("All tests passed!");
        $finish;
    end

    // Timeout
    initial begin
        #40_000;
        $error("[TB] TIMEOUT");
        $finish;
    end

    // Monitor
    always @(posedge clk) begin
        if (m_axi_if.arvalid && m_axi_if.arready)
            $display("[AXI] AR: addr=0x%09h len=%0d size=%0d @ %0t",
                     m_axi_if.araddr, m_axi_if.arlen, m_axi_if.arsize, $time);
        if (m_axi_if.rvalid && m_axi_if.rready)
            $display("[AXI]  R: data=0x%032h resp=%0d last=%0b @ %0t",
                     m_axi_if.rdata, m_axi_if.rresp, m_axi_if.rlast, $time);
        if (m_axi_if.awvalid && m_axi_if.awready)
                $display("[AXI] AW: addr=0x%09h len=%0d @ %0t",
                            m_axi_if.awaddr, m_axi_if.awlen, $time);
        if (m_axi_if.wvalid && m_axi_if.wready)
            $display("[AXI]  W: data=0x%032h strb=%0h last=%0b @ %0t",
                        m_axi_if.wdata, m_axi_if.wstrb, m_axi_if.wlast, $time);
        if (m_axi_if.bvalid && m_axi_if.bready)
            $display("[AXI]  B: resp=%0d @ %0t", m_axi_if.bresp, $time);
    end

endmodule
