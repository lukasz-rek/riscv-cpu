interface axi_if #(
    parameter ADDR_W = 32,
    parameter DATA_W = 32,
    parameter ID_W   = 6,
    parameter QOS_W  = 4
) ();
    /* verilator lint_off UNUSEDSIGNAL */
    // Write Address
    logic [  ADDR_W-1:0] awaddr;
    logic [         7:0] awlen;
    logic [         2:0] awsize;
    logic [         1:0] awburst;
    logic                awlock;
    logic [         3:0] awcache;
    logic [         2:0] awprot;
    logic                awvalid;
    logic                awready;
    logic [    ID_W-1:0] awid;
    logic [   QOS_W-1:0] awqos;
    logic                awuser;
    // Write Data
    logic [  DATA_W-1:0] wdata;
    logic [DATA_W/8-1:0] wstrb;
    logic                wlast;
    logic                wvalid;
    logic                wready;
    // Write Response
    logic [         1:0] bresp;
    logic                bvalid;
    logic                bready;
    logic [    ID_W-1:0] bid;
    /* verilator lint_on UNUSEDSIGNAL */
    // Read Address
    logic [  ADDR_W-1:0] araddr;
    logic [         7:0] arlen;
    logic [         2:0] arsize;
    logic [         1:0] arburst;
    logic                arlock;
    logic [         3:0] arcache;
    logic [         2:0] arprot;
    logic                arvalid;
    logic                arready;
    logic [    ID_W-1:0] arid;
    logic [   QOS_W-1:0] arqos;
    logic                aruser;
    // Read Data
    logic [  DATA_W-1:0] rdata;
    logic [         1:0] rresp;
    logic                rvalid;
    logic                rlast;
    logic                rready;
    logic [    ID_W-1:0] rid;

    // Tie off currently unused signals



    modport master(
        output awaddr, awlen, awsize, awburst, awlock, awcache, awprot,
               awvalid, awid, awqos, awuser,
               wdata, wstrb, wlast, wvalid,
               bready,
               araddr, arlen, arsize, arburst, arlock, arcache, arprot,
               arvalid, arid, arqos, aruser,
               rready,
        input awready, wready, bresp, bvalid, bid, arready, rdata, rresp, rvalid, rlast, rid
    );


endinterface
