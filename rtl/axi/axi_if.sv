interface axi_if #(
    parameter ADDR_W = 36,
    parameter DATA_W = 128,
    parameter ID_W   = 6,
    parameter QOS_W  = 4
) ();
    wire [  ADDR_W-1:0] awaddr;
    wire [         7:0] awlen;
    wire [         2:0] awsize;
    wire [         1:0] awburst;
    wire                awlock;
    wire [         3:0] awcache;
    wire [         2:0] awprot;
    wire                awvalid;
    wire                awready;
    wire [    ID_W-1:0] awid;
    wire [   QOS_W-1:0] awqos;
    wire                awuser;

    wire [  DATA_W-1:0] wdata;
    wire [DATA_W/8-1:0] wstrb;
    wire                wlast;
    wire                wvalid;
    wire                wready;

    wire [         1:0] bresp;
    wire                bvalid;
    wire                bready;
    wire [    ID_W-1:0] bid;

    wire [  ADDR_W-1:0] araddr;
    wire [         7:0] arlen;
    wire [         2:0] arsize;
    wire [         1:0] arburst;
    wire                arlock;
    wire [         3:0] arcache;
    wire [         2:0] arprot;
    wire                arvalid;
    wire                arready;
    wire [    ID_W-1:0] arid;
    wire [   QOS_W-1:0] arqos;
    wire                aruser;

    wire [  DATA_W-1:0] rdata;
    wire [         1:0] rresp;
    wire                rvalid;
    wire                rlast;
    wire                rready;
    wire [    ID_W-1:0] rid;

    modport master(
        output awaddr, awlen, awsize, awburst, awlock, awcache, awprot,
               awvalid, awid, awqos, awuser,
               wdata, wstrb, wlast, wvalid,
               bready,
               araddr, arlen, arsize, arburst, arlock, arcache, arprot,
               arvalid, arid, arqos, aruser,
               rready,
        input  awready, wready, bresp, bvalid, bid, arready,
               rdata, rresp, rvalid, rlast, rid
    );
endinterface
