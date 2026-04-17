
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

    logic miss_d;
    logic dirty_evict_d;

    logic [1:0] cache_load_d;

    logic [127:0] cache_load_data;
    logic [127:0] cache_evicted_data;

    logic [127:0] evicted_buffer[2];

    typedef enum logic [4:0] {
        AXI_OFF,
        // Read states
        AXI_AR,
        AXI_R,
        // Write states
        AXI_AW,
        AXI_W,
        AXI_B  // Confirmation of write
    } state_t;

    state_t state_q;
    logic   is_2nd_beat;

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
        .miss(miss_d),
        .dirty_evict(dirty_evict_d),
        .cache_evicted_data(cache_evicted_data)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q <= AXI_OFF;
            is_2nd_beat <= 0;
            cache_load_d <= 2'b00;
        end else begin
            // If we're missing data then start up axi, do write if dirty
            if (miss_d && (state_q == AXI_OFF)) begin
                if (dirty_evict_d) begin
                    state_q <= AXI_AW;
                    m_axi.awaddr <= addr_d + START_ADDR;
                end else begin
                    state_q <= AXI_AR;
                    m_axi.araddr <= addr_d + START_ADDR;
                end
            end

            case (state_q)
                AXI_OFF: ;
                // Reading progression
                AXI_AR:
                if (m_axi.arready) begin
                    state_q <= AXI_R;
                    is_2nd_beat <= 0;
                end
                AXI_R:
                if (m_axi.rvalid) begin
                    cache_load_data <= m_axi.rdata;
                    if (!is_2nd_beat) begin
                        is_2nd_beat  <= 1;
                        cache_load_d <= 2'b01;
                    end else begin
                        is_2nd_beat <= 0;
                        cache_load_d <= 2'b10;
                        state_q <= AXI_OFF;
                    end
                end
                // Write progression

                default: ;
            endcase
        end
    end

    // Setup static AXI connections
    // AXI AR Channel
    assign m_axi.arlen = 8'd1;
    assign m_axi.arsize  = 3'b100;  // 16 bytes
    assign m_axi.arburst = 2'b01;  // INCR (don't-care for len=0)
    assign m_axi.arlock  = 1'b0;
    assign m_axi.arcache = 4'b0011;  // normal non-cacheable bufferable
    assign m_axi.arprot  = 3'b000;
    assign m_axi.arvalid = (state == AXI_AR);
    assign m_axi.arid    = '0;
    assign m_axi.arqos   = '0;
    assign m_axi.aruser  = 1'b0;

    // ── AXI R channel ──
    assign m_axi.rready  = (state == AXI_R);


endmodule
