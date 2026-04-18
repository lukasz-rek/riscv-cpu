
module axi_master #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter logic [35:0] START_ADDR = 36'h8_4000_0000
) (
    input logic clk,
    input logic rst_n,

    // Memory interface
    input logic [ADDR_WIDTH-1:0] addr_i,
    input logic [ADDR_WIDTH-1:0] addr_d,
    input logic [ADDR_WIDTH-1:0] wr_addr,
    /* verilator lint_on UNUSEDSIGNAL */
    input logic [DATA_WIDTH-1:0] wr_data,
    input logic [           3:0] byte_en,

    input  logic                  wr_en,
    input  logic                  rd_en_i,
    input  logic                  rd_en_d,
    output logic [DATA_WIDTH-1:0] rd_data_i,
    output logic [DATA_WIDTH-1:0] rd_data_d,

    output logic stall_I,
    output logic stall_D,
    // AXI connections
    axi_if.master m_axi
);

    /*
        Rough idea
        First try to request data via cache. If miss isn't raised then it's all good
        If miss gets raised, then raise respective stall, begin AXI fetch and cache replacement
        Depending on whether evicted data is dirty, write it back before reading
        Once data arrives then return it on the same cycle
    */

    logic dirty_evict_d;

    logic [ADDR_WIDTH-1:0] awaddr_r;
    logic [ADDR_WIDTH-1:0] araddr_r;

    logic [1:0] cache_load_d;

    logic [127:0] cache_load_data;
    logic [127:0] cache_evicted_data;

    logic [127:0] evicted_buffer[2];

    typedef enum logic [4:0] {
        AXI_OFF,
        // Read states
        AXI_AR,
        AXI_R,
        AXI_R_DONE, // Extra state for the actual requested read to go through
        // Write states
        AXI_AW,
        AXI_W,
        AXI_B  // Confirmation of write
    } state_t;

    state_t state_q;
    logic   beat_counter;

    axi_cache #() d_cache (
        .clk  (clk),
        .rst_n(rst_n),

        .addr(addr_d),
        .wr_data(wr_data),
        .wr_en(wr_en),
        .rd_en(rd_en_d),
        .byte_en(byte_en),

        .cache_load(cache_load_d),
        .cache_load_data(cache_load_data),

        .rd_data(rd_data_d),
        .miss(stall_D),
        .dirty_evict(dirty_evict_d),
        .cache_evicted_data(cache_evicted_data)
    );

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state_q <= AXI_OFF;
            beat_counter <= 0;
            cache_load_d <= 2'b00;
        end else begin
            // If we're missing data then start up axi, do write if dirty
            if (stall_D && (state_q == AXI_OFF)) begin
                if (dirty_evict_d) begin
                    state_q <= AXI_AW;
                    awaddr_r <= {addr_d[ADDR_WIDTH-1:5], 5'b0} + START_ADDR;
                end else begin
                    state_q <= AXI_AR;
                    araddr_r <= {addr_d[ADDR_WIDTH-1:5], 5'b0} + START_ADDR;
                end
            end

            case (state_q)
                AXI_OFF: ;
                // Reading progression
                AXI_AR:
                if (m_axi.arready) begin
                    state_q <= AXI_R;
                    beat_counter <= 0;
                end
                AXI_R: begin
                    cache_load_d <= 2'b00;
                    if (m_axi.rvalid) begin
                        cache_load_data <= m_axi.rdata;
                        cache_load_d <= beat_counter ? 2'b10 : 2'b01;
                        beat_counter <= !beat_counter;
                        if (beat_counter) begin
                            state_q <= AXI_R_DONE;
                        end
                    end
                end
                AXI_R_DONE: begin
                    cache_load_d <= 2'b00;
                    beat_counter <= 0;
                    state_q <= AXI_OFF;
                end

                // Write progression

                default: ;
            endcase
        end
    end

    assign m_axi.awaddr = awaddr_r;
    assign m_axi.araddr = araddr_r;

    // Setup static AXI connections
    // AXI AR Channel
    assign m_axi.arlen = 8'd1;
    assign m_axi.arsize  = 3'b100;  // 16 bytes
    assign m_axi.arburst = 2'b01;  // INCR (don't-care for len=0)
    assign m_axi.arlock  = 1'b0;
    assign m_axi.arcache = 4'b0011;  // normal non-cacheable bufferable
    assign m_axi.arprot  = 3'b000;
    assign m_axi.arvalid = (state_q == AXI_AR);
    assign m_axi.arid    = '0;
    assign m_axi.arqos   = '0;
    assign m_axi.aruser  = 1'b0;

    // ── AXI R channel ──
    assign m_axi.rready  = (state_q == AXI_R);

    assign stall_I   = 1'b0;
    assign rd_data_i = '0;

    // ── AXI AW ──
    assign m_axi.awlen   = 8'd1;
    assign m_axi.awsize  = 3'b100;  // 16 bytes
    assign m_axi.awburst = 2'b01;
    assign m_axi.awlock  = 1'b0;
    assign m_axi.awcache = 4'b0011;
    assign m_axi.awprot  = 3'b000;
    assign m_axi.awvalid = (state_q == AXI_AW);
    assign m_axi.awid    = '0;
    assign m_axi.awqos   = '0;
    assign m_axi.awuser  = 1'b0;

    // ── AXI W ──
    assign m_axi.wdata  = '0;
    assign m_axi.wstrb  = 16'hFFFF;
    assign m_axi.wlast  = 1'b1;
    assign m_axi.wvalid = (state_q == AXI_W);

    // ── AXI B ──
    assign m_axi.bready = 1'b1;

endmodule
