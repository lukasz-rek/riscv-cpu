module top_wrapper (
    input wire clk,
    input wire rst_n,

    // Flat AXI ports — BD sees these
    output wire [35:0] m_axi_awaddr,
    output wire [ 7:0] m_axi_awlen,
    output wire [ 2:0] m_axi_awsize,
    output wire [ 1:0] m_axi_awburst,
    output wire        m_axi_awlock,
    output wire [ 3:0] m_axi_awcache,
    output wire [ 2:0] m_axi_awprot,
    output wire        m_axi_awvalid,
    input  wire        m_axi_awready,
    output wire [ 5:0] m_axi_awid,
    output wire [ 3:0] m_axi_awqos,
    output wire        m_axi_awuser,

    output wire [127:0] m_axi_wdata,
    output wire [ 15:0] m_axi_wstrb,
    output wire         m_axi_wlast,
    output wire         m_axi_wvalid,
    input  wire         m_axi_wready,

    input  wire [1:0] m_axi_bresp,
    input  wire       m_axi_bvalid,
    output wire       m_axi_bready,
    input  wire [5:0] m_axi_bid,

    output wire [35:0] m_axi_araddr,
    output wire [ 7:0] m_axi_arlen,
    output wire [ 2:0] m_axi_arsize,
    output wire [ 1:0] m_axi_arburst,
    output wire        m_axi_arlock,
    output wire [ 3:0] m_axi_arcache,
    output wire [ 2:0] m_axi_arprot,
    output wire        m_axi_arvalid,
    input  wire        m_axi_arready,
    output wire [ 5:0] m_axi_arid,
    output wire [ 3:0] m_axi_arqos,
    output wire        m_axi_aruser,

    input  wire [127:0] m_axi_rdata,
    input  wire [  1:0] m_axi_rresp,
    input  wire         m_axi_rvalid,
    input  wire         m_axi_rlast,
    output wire         m_axi_rready,
    input  wire [  5:0] m_axi_rid
);
    // Internal interface instance
    axi_if #(
        .ADDR_W(36),
        .DATA_W(128),
        .ID_W  (6),
        .QOS_W (4)
    ) axi_bus ();

    // Master outputs: interface → flat ports
    assign m_axi_awaddr    = axi_bus.awaddr;
    assign m_axi_awlen     = axi_bus.awlen;
    assign m_axi_awsize    = axi_bus.awsize;
    assign m_axi_awburst   = axi_bus.awburst;
    assign m_axi_awlock    = axi_bus.awlock;
    assign m_axi_awcache   = axi_bus.awcache;
    assign m_axi_awprot    = axi_bus.awprot;
    assign m_axi_awvalid   = axi_bus.awvalid;
    assign m_axi_awid      = axi_bus.awid;
    assign m_axi_awqos     = axi_bus.awqos;
    assign m_axi_awuser    = axi_bus.awuser;

    assign m_axi_wdata     = axi_bus.wdata;
    assign m_axi_wstrb     = axi_bus.wstrb;
    assign m_axi_wlast     = axi_bus.wlast;
    assign m_axi_wvalid    = axi_bus.wvalid;

    assign m_axi_bready    = axi_bus.bready;

    assign m_axi_araddr    = axi_bus.araddr;
    assign m_axi_arlen     = axi_bus.arlen;
    assign m_axi_arsize    = axi_bus.arsize;
    assign m_axi_arburst   = axi_bus.arburst;
    assign m_axi_arlock    = axi_bus.arlock;
    assign m_axi_arcache   = axi_bus.arcache;
    assign m_axi_arprot    = axi_bus.arprot;
    assign m_axi_arvalid   = axi_bus.arvalid;
    assign m_axi_arid      = axi_bus.arid;
    assign m_axi_arqos     = axi_bus.arqos;
    assign m_axi_aruser    = axi_bus.aruser;

    assign m_axi_rready    = axi_bus.rready;

    // Slave inputs: flat ports → interface
    assign axi_bus.awready = m_axi_awready;

    assign axi_bus.wready  = m_axi_wready;

    assign axi_bus.bresp   = m_axi_bresp;
    assign axi_bus.bvalid  = m_axi_bvalid;
    assign axi_bus.bid     = m_axi_bid;

    assign axi_bus.arready = m_axi_arready;

    assign axi_bus.rdata   = m_axi_rdata;
    assign axi_bus.rresp   = m_axi_rresp;
    assign axi_bus.rvalid  = m_axi_rvalid;
    assign axi_bus.rlast   = m_axi_rlast;
    assign axi_bus.rid     = m_axi_rid;

    top top_inst (
        .clk  (clk),
        .rst_n(rst_n),
        .m_axi(axi_bus)
    );

endmodule
