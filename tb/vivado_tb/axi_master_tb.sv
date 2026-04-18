`timescale 1ns / 1ps

import axi_vip_pkg::*;
import axi_test_axi_vip_0_0_pkg::*;

module axi_master_tb;

    logic clk   = 0;
    logic rst_n = 0;

    always #8.62 clk = ~clk;  // ~58 MHz

    // Memory-side stimulus to the axi_master
    logic [31:0] addr_d;
    logic        rd_en_d;
    logic wr_en;
    logic [31:0] rd_data_d;
    logic        stall_D;
    logic [31:0] wr_addr;
    logic [31:0] wr_data;

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
        .addr_i    (32'h0),
        .addr_d    (addr_d),
        .wr_addr   (wr_addr),
        .wr_data   (wr_data),
        .byte_en   (4'hF),
        .wr_en     (wr_en),
        .rd_en_i   (1'b0),
        .rd_en_d   (rd_en_d),
        .rd_data_i (),
        .rd_data_d (rd_data_d),
        .stall_I   (),
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
            36'h8_4000_0000,
            128'h44444444_33333333_22222222_DEADBEEF,
            16'hFFFF
        );
        slv_agent.mem_model.backdoor_memory_write(
            36'h8_4000_0010,
            128'h88888888_77777777_66666666_55555555,
            16'hFFFF
        );

        addr_d  = 32'h0;
        rd_en_d = 1'b0;

        rst_n = 0;
        #500;
        rst_n = 1;
        $display("[TB] Reset released at %0t", $time);

        // Issue a read at address 0x0
        @(negedge clk);
        addr_d  <= 32'h0000_0000;
        rd_en_d <= 1'b1;
        #1; // Delay moment for stall_D to actually propagate

        // Wait for the miss to be serviced
        while (stall_D) @(negedge clk);


        $display("[TB] rd_data_d = 0x%08h (expected 0xDEADBEEF)", rd_data_d);
        rd_en_d <= 1'b0;

        @(negedge clk);
        rd_en_d <= 1'b1;
        addr_d  <= 32'h0000_000C;

        @(negedge clk);
        $display("[TB] rd_data_d = 0x%08h (expected 0x44444444)", rd_data_d);
        rd_en_d <= 1'b0;

        // Now just do a write, later verify it was modified
        @(negedge clk);
        wr_en <= 1'b1;
        wr_addr <= 32'h0000_000C;
        wr_data <= 32'hABCD_DCBA;

        @(negedge clk);
        wr_en <= 1'b0;
        rd_en_d <= 1'b1;

        @(negedge clk);
        $display("[TB] rd_data_d = 0x%08h (expected 0xABCDDBCA)", rd_data_d);
        // Now start doing reads that evict previous line and verify it got written to AXI
        addr_d <= 32'h0000_4000;
        #1;

        assert(stall_D == 1);
        assert(dut.dirty_evict_d == 1);


        #1000;
        $finish;
    end

    // Timeout
    initial begin
        #2_000_000;
        $display("[TB] TIMEOUT");
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
    end

endmodule
