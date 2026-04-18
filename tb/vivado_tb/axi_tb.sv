`timescale 1ns / 1ps

import axi_vip_pkg::*;
import axi_test_axi_vip_0_0_pkg::*;

module tb_axi_read;

    logic clk   = 0;
    logic rst_n = 0;
    logic uart_tx;

    always #8.62 clk = ~clk; // ~58 MHz

    // ── Flat AXI wires (matched to VIP's port set) ──
    // Read Address
    wire [35:0] axi_araddr;
    wire [ 7:0] axi_arlen;
    wire [ 2:0] axi_arsize;
    wire [ 1:0] axi_arburst;
    wire [ 0:0] axi_arlock;
    wire [ 3:0] axi_arcache;
    wire [ 2:0] axi_arprot;
    wire [ 3:0] axi_arqos;
    wire        axi_arvalid;
    wire        axi_arready;
    // Read Data
    wire [127:0] axi_rdata;
    wire [ 1:0] axi_rresp;
    wire        axi_rvalid;
    wire        axi_rlast;
    wire        axi_rready;
    // Write Address
    wire [35:0] axi_awaddr;
    wire [ 7:0] axi_awlen;
    wire [ 2:0] axi_awsize;
    wire [ 1:0] axi_awburst;
    wire [ 0:0] axi_awlock;
    wire [ 3:0] axi_awcache;
    wire [ 2:0] axi_awprot;
    wire [ 3:0] axi_awqos;
    wire        axi_awvalid;
    wire        axi_awready;
    // Write Data
    wire [127:0] axi_wdata;
    wire [ 15:0] axi_wstrb;
    wire        axi_wlast;
    wire        axi_wvalid;
    wire        axi_wready;
    // Write Response
    wire [ 1:0] axi_bresp;
    wire        axi_bvalid;
    wire        axi_bready;

    // ── DUT ──
    // Signals top_wrapper drives but VIP doesn't accept (no ID/user on VIP)
    wire [5:0] dummy_arid, dummy_awid;
    wire       dummy_aruser, dummy_awuser;

    top_wrapper dut (
        .clk             (clk),
        .rst_n           (rst_n),
        .uart_tx         (uart_tx),
        // AR
        .m_axi_araddr    (axi_araddr),
        .m_axi_arlen     (axi_arlen),
        .m_axi_arsize    (axi_arsize),
        .m_axi_arburst   (axi_arburst),
        .m_axi_arlock    (axi_arlock),
        .m_axi_arcache   (axi_arcache),
        .m_axi_arprot    (axi_arprot),
        .m_axi_arvalid   (axi_arvalid),
        .m_axi_arready   (axi_arready),
        .m_axi_arid      (dummy_arid),
        .m_axi_arqos     (axi_arqos),
        .m_axi_aruser    (dummy_aruser),
        // R
        .m_axi_rdata     (axi_rdata),
        .m_axi_rresp     (axi_rresp),
        .m_axi_rvalid    (axi_rvalid),
        .m_axi_rlast     (axi_rlast),
        .m_axi_rready    (axi_rready),
        .m_axi_rid       (6'b0),
        // AW
        .m_axi_awaddr    (axi_awaddr),
        .m_axi_awlen     (axi_awlen),
        .m_axi_awsize    (axi_awsize),
        .m_axi_awburst   (axi_awburst),
        .m_axi_awlock    (axi_awlock),
        .m_axi_awcache   (axi_awcache),
        .m_axi_awprot    (axi_awprot),
        .m_axi_awvalid   (axi_awvalid),
        .m_axi_awready   (axi_awready),
        .m_axi_awid      (dummy_awid),
        .m_axi_awqos     (axi_awqos),
        .m_axi_awuser    (dummy_awuser),
        // W
        .m_axi_wdata     (axi_wdata),
        .m_axi_wstrb     (axi_wstrb),
        .m_axi_wlast     (axi_wlast),
        .m_axi_wvalid    (axi_wvalid),
        .m_axi_wready    (axi_wready),
        // B
        .m_axi_bresp     (axi_bresp),
        .m_axi_bvalid    (axi_bvalid),
        .m_axi_bready    (axi_bready),
        .m_axi_bid       (6'b0)
    );

    // ── AXI VIP (slave mode) ──
    axi_test_wrapper vip_inst (
        .aclk_0             (clk),
        .aresetn_0          (rst_n),
        // AR
        .S_AXI_0_araddr     (axi_araddr),
        .S_AXI_0_arlen      (axi_arlen),
        .S_AXI_0_arsize     (axi_arsize),
        .S_AXI_0_arburst    (axi_arburst),
        .S_AXI_0_arlock     (axi_arlock),
        .S_AXI_0_arcache    (axi_arcache),
        .S_AXI_0_arprot     (axi_arprot),
        .S_AXI_0_arqos      (axi_arqos),
        .S_AXI_0_arregion   (4'b0),
        .S_AXI_0_arvalid    (axi_arvalid),
        .S_AXI_0_arready    (axi_arready),
        // R
        .S_AXI_0_rdata      (axi_rdata),
        .S_AXI_0_rresp      (axi_rresp),
        .S_AXI_0_rvalid     (axi_rvalid),
        .S_AXI_0_rlast      (axi_rlast),
        .S_AXI_0_rready     (axi_rready),
        // AW
        .S_AXI_0_awaddr     (axi_awaddr),
        .S_AXI_0_awlen      (axi_awlen),
        .S_AXI_0_awsize     (axi_awsize),
        .S_AXI_0_awburst    (axi_awburst),
        .S_AXI_0_awlock     (axi_awlock),
        .S_AXI_0_awcache    (axi_awcache),
        .S_AXI_0_awprot     (axi_awprot),
        .S_AXI_0_awqos      (axi_awqos),
        .S_AXI_0_awregion   (4'b0),
        .S_AXI_0_awvalid    (axi_awvalid),
        .S_AXI_0_awready    (axi_awready),
        // W
        .S_AXI_0_wdata      (axi_wdata),
        .S_AXI_0_wstrb      (axi_wstrb),
        .S_AXI_0_wlast      (axi_wlast),
        .S_AXI_0_wvalid     (axi_wvalid),
        .S_AXI_0_wready     (axi_wready),
        // B
        .S_AXI_0_bresp      (axi_bresp),
        .S_AXI_0_bvalid     (axi_bvalid),
        .S_AXI_0_bready     (axi_bready)
    );

    // ── VIP slave memory agent ──
    axi_test_axi_vip_0_0_slv_mem_t slv_agent;

    initial begin
        slv_agent = new("slv_agent", vip_inst.axi_test_i.axi_vip_0.inst.IF);
        slv_agent.start_slave();

        // Preload test data
        slv_agent.mem_model.backdoor_memory_write(
            36'h8_4000_0000,
            128'h0A214958_41206D6F_7266206F_6C6C6548,
            16'hFFFF
        );
        slv_agent.mem_model.backdoor_memory_write(
            36'h8_4000_0010,
            128'h0000000A_21646C72_6F57206F_6C6C6548,
            16'hFFFF
        );
        slv_agent.mem_model.backdoor_memory_write(
            36'h8_4000_0020,
            128'h0000000A_73656C75_7220562D_43534952,
            16'hFFFF
        );
        slv_agent.mem_model.backdoor_memory_write(
            36'h8_4000_0030,
            128'h00000000_00000A21_64656464_65626D45,
            16'hFFFF
        );
        slv_agent.mem_model.backdoor_memory_write(
            36'h8_4000_0040,
            128'h00000000_00000A34_33323120_74736574,
            16'hFFFF
        );
        slv_agent.mem_model.backdoor_memory_write(
            36'h8_4000_0050,
            128'h0A214958_41206D6F_7266206F_6C6C6548,
            16'hFFFF
        );

        // Reset
        rst_n = 0;
        #500;
        rst_n = 1;
        $display("[TB] Reset released at %0t", $time);

        // 4 words x 4 bytes x ~87us/byte = ~1.4ms
        #8_000_000;

        $display("[TB] Simulation finished at %0t", $time);
        $finish;
    end

    // ── Monitor AXI reads ──
    // always @(posedge clk) begin
    //     if (axi_arvalid && axi_arready)
    //         $display("[AXI] AR: addr=0x%08h @ %0t", axi_araddr, $time);
    //     if (axi_rvalid && axi_rready)
    //         $display("[AXI]  R: data=0x%032h resp=%0d @ %0t", axi_rdata, axi_rresp, $time);
    // end



endmodule
