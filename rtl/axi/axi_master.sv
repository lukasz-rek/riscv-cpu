
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
    /* verilator lint_on UNUSEDSIGNAL */
    input logic [DATA_WIDTH-1:0] wr_data,

    input logic [3:0] byte_en,

    input logic flush_I,

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
    // AXI states
    typedef enum logic [4:0] {
        AXI_OFF,
        // Read states
        AXI_AR_REG,
        AXI_AR,
        AXI_R,
        AXI_R_DONE,  // Extra state for the actual requested read to go through
        // Write states
        AXI_CAPTURE_EVICTED,
        AXI_AW,
        AXI_W,
        AXI_B,  // Confirmation of write
        // AXI MMIO transactions
        MMIO_AR,
        MMIO_R,
        MMIO_R_DONE,
        MMIO_AW,
        MMIO_W,
        MMIO_B,
        MMIO_DONE
    } state_t;

    // AXI helpers
    logic [ 35:0] awaddr_r;
    logic [ 35:0] araddr_r;
    logic [127:0] wdata_r;
    logic         wlast_r;

    // MMIO handlers
    logic         is_mmio;
    assign is_mmio = (addr_d < 32'h8000_0000 && (rd_en_d || wr_en)) ? 1 : 0;
    logic   [  31:0] d_cache_out;  // Needed to mux MMIO or D_cache
    logic   [  31:0] mmio_out;
    logic            mmio_valid;

    logic [31:0] d_cache_out_q;

    // Bit of cheating :( but that's not gonna change
    // + 1 bit to overflow when we go over
    logic   [15 : 0] flush_line_counter;
    logic            flush_started;

    // Cache signals
    logic   [   1:0] cache_load;

    logic   [ 255:0] cache_evicted_data;
    logic   [ 255:0] cache_evicted_data_d;
    logic   [ 255:0] cache_evicted_data_i;
    logic   [ 127:0] evicted_buffer                                              [2];

    logic   [ 127:0] cache_load_data;

    logic            dirty_evict_d;
    logic            dirty_evict_i;

    logic            stall_d;
    logic            stall_i;
    logic            miss_d;
    logic            miss_i;

    /* verilator lint_off UNUSEDSIGNAL */
    logic   [  31:0] araddr_q;
    logic   [  31:0] evicted_addr_i;
    logic   [  31:0] evicted_addr_d;
    /* verilator lint_on UNUSEDSIGNAL */

    logic            i_stall_in_progress;  // Coordinate which cache is worked on
    state_t          state_q;
    logic            beat_counter;

    logic            d_clear_dirty;
    logic            i_clear_valid;

    axi_cache #() d_cache (
        .clk  (clk),
        .rst_n(rst_n),

        .addr((flush_started) ? {16'b0, flush_line_counter[15:0]} : addr_d),
        .wr_data(wr_data),
        .wr_en(wr_en && !is_mmio),
        .rd_en(rd_en_d && !is_mmio),
        .byte_en(byte_en),
        .stall(stall_d),

        .cache_load((i_stall_in_progress) ? '0 : cache_load),
        .cache_load_data(cache_load_data),
        .flush(flush_started),

        .clear_valid(0),
        .clear_dirty(d_clear_dirty),

        .rd_data(d_cache_out),
        .miss(miss_d),
        .dirty_evict(dirty_evict_d),
        .cache_evicted_data(cache_evicted_data_d),
        .evicted_addr(evicted_addr_d)
    );

    axi_cache #() i_cache (
        .clk  (clk),
        .rst_n(rst_n),

        .addr((flush_started) ? {16'b0, flush_line_counter[15:0]} : addr_i),
        // No writes to instruction cache
        .wr_data('0),
        .wr_en('0),
        .rd_en(rd_en_i && !flush_started),
        .byte_en('0),
        .stall(stall_i),

        .cache_load((i_stall_in_progress) ? cache_load : '0),
        .cache_load_data(cache_load_data),


        .clear_valid(i_clear_valid),
        .clear_dirty(0),
        .flush(flush_started),


        .rd_data(rd_data_i),
        .miss(miss_i),
        .dirty_evict(dirty_evict_i),
        .cache_evicted_data(cache_evicted_data_i),
        .evicted_addr(evicted_addr_i)
    );

    wire flush_in_progress;
    wire flush_done;

    assign flush_done = (flush_line_counter > 16'h8000);

    assign flush_in_progress = (flush_I && !flush_done);

    wire stall_D_raw = (stall_d || miss_d || (rd_en_d && addr_d != d_cache_out_addr_q));
    logic stall_D_raw_q;
    logic [31:0] d_cache_out_addr_q;

    assign stall_D = (((stall_D_raw || stall_D_raw_q) || (is_mmio && !mmio_valid) || flush_in_progress)) && !flush_done;
    assign stall_I = (stall_i || miss_i) || flush_in_progress;

    // Only clear if no miss or if miss and we're on final write stage
    assign i_clear_valid = flush_started;


    assign cache_evicted_data = (i_stall_in_progress) ? cache_evicted_data_i : cache_evicted_data_d;
    assign rd_data_d = (mmio_valid) ? mmio_out : d_cache_out_q;


    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state_q <= AXI_OFF;
            beat_counter <= '0;
            araddr_q <= '0;
            cache_load <= '0;
            cache_load_data <= '0;
            mmio_valid <= '0;
            flush_line_counter <= '0;
            flush_started <= 0;
            d_clear_dirty <= 0;
            d_cache_out_q <= '0;
            stall_D_raw_q <= '0;
        end else begin
            // See if we need to start an AXI transaction
            if ((state_q == AXI_OFF) && flush_in_progress && flush_started && !stall_d) begin
                // If it's a dirty evict, go to eviction cycles, else clear control bits and continue
                if (dirty_evict_d) begin
                    state_q <= AXI_CAPTURE_EVICTED;
                    beat_counter <= 0;
                end else begin
                    flush_line_counter <= flush_line_counter + 32;
                end
            end else if (!stall_i && miss_i && (state_q == AXI_OFF)) begin
                i_stall_in_progress <= 1'b1;
                araddr_q <= addr_i;
                if (dirty_evict_i) begin
                    state_q <= AXI_CAPTURE_EVICTED;
                    beat_counter <= 0;
                end else begin
                    state_q <= AXI_AR_REG;
                end
            end else if (!stall_d && miss_d && (state_q == AXI_OFF)) begin
                i_stall_in_progress <= 1'b0;
                araddr_q <= addr_d;
                if (dirty_evict_d) begin
                    state_q <= AXI_CAPTURE_EVICTED;
                    beat_counter <= 0;
                end else begin
                    state_q <= AXI_AR_REG;
                end
            end else if (is_mmio && (state_q == AXI_OFF) && rd_en_d) begin
                araddr_r <= {4'b0, addr_d};
                state_q  <= MMIO_AR;
            end else if (is_mmio && (state_q == AXI_OFF) && wr_en) begin
                awaddr_r <= {4'b0, addr_d};
                state_q  <= MMIO_AW;
            end else if ((state_q == AXI_OFF) && flush_in_progress) begin
                flush_started <= 1;
            end

            if (!flush_in_progress) begin
                flush_line_counter <= 0;
                flush_started <= 0;
            end

            d_cache_out_q <= d_cache_out;
            stall_D_raw_q <= stall_D_raw;
            d_cache_out_addr_q <= addr_d;

            // Process appriopriate state
            case (state_q)
                AXI_OFF: ;
                AXI_AR_REG: begin
                    araddr_r <= 36'({araddr_q[ADDR_WIDTH-1:5], 5'b0}) + START_ADDR;
                    state_q  <= AXI_AR;
                end
                // Reading progression
                AXI_AR:
                if (m_axi.arready) begin
                    state_q <= AXI_R;
                    beat_counter <= 0;
                end
                AXI_R: begin
                    cache_load <= 2'b00;
                    if (m_axi.rvalid) begin
                        cache_load <= beat_counter ? 2'b10 : 2'b01;
                        cache_load_data <= m_axi.rdata;
                        beat_counter <= !beat_counter;
                        if (beat_counter) begin
                            state_q <= AXI_R_DONE;
                        end
                    end
                end
                AXI_R_DONE: begin
                    i_stall_in_progress <= '0;
                    cache_load <= '0;
                    beat_counter <= 0;
                    state_q <= AXI_OFF;
                end

                // Write progression_ADDR
                AXI_CAPTURE_EVICTED: begin
                    if (i_stall_in_progress) begin
                        // $write("Evicted I %h\n", evicted_addr_i);
                        awaddr_r <= 36'({evicted_addr_i[ADDR_WIDTH-1:5], 5'b0}) + START_ADDR;
                    end else begin
                        // $write("Evicted D %h\n", evicted_addr_d);
                        awaddr_r <= 36'({evicted_addr_d[ADDR_WIDTH-1:5], 5'b0}) + START_ADDR;
                    end
                    evicted_buffer[0] <= cache_evicted_data[127:0];
                    evicted_buffer[1] <= cache_evicted_data[255:128];
                    // $write("Evicted %h\n", cache_evicted_data);
                    state_q <= AXI_AW;
                end
                AXI_AW:
                if (m_axi.awready) begin
                    state_q <= AXI_W;
                    wdata_r <= evicted_buffer[0];
                    wlast_r <= 0;
                    beat_counter <= 0;
                end
                AXI_W:
                if (m_axi.wready) begin
                    if (!beat_counter) begin
                        wdata_r <= evicted_buffer[1];
                        wlast_r <= 1;
                        beat_counter <= !beat_counter;
                    end else begin
                        state_q <= AXI_B;
                        d_clear_dirty <= flush_I;
                        wlast_r <= 0;
                        beat_counter <= 0;
                    end
                end
                AXI_B:
                if (m_axi.bvalid) begin
                    if (flush_started) begin
                        // Increment counter and continue flushing
                        flush_line_counter <= flush_line_counter + 32;
                        d_clear_dirty <= 0;
                        state_q <= AXI_OFF;
                    end else begin
                        // Now we need to go read the data requested to replace
                        araddr_r <= 36'({araddr_q[ADDR_WIDTH-1:5], 5'b0}) + START_ADDR;
                        state_q  <= AXI_AR;
                    end
                end
                // Progressions for MMIO reads/writes
                MMIO_AR:
                if (m_axi.arready) begin
                    state_q <= MMIO_R;
                end
                MMIO_R:
                if (m_axi.rvalid) begin
                    mmio_out <= m_axi.rdata[addr_d[3:2]*32+:32];
                    state_q <= MMIO_R_DONE;
                    mmio_valid <= 1;
                end
                MMIO_R_DONE: state_q <= MMIO_DONE;
                MMIO_DONE: begin
                    mmio_valid <= 0;
                    mmio_out <= '0;
                    state_q <= AXI_OFF;
                end
                MMIO_AW:
                if (m_axi.awready) begin
                    state_q <= MMIO_W;
                    wdata_r <= {96'b0, wr_data} << {addr_d[3:2], 5'b0};
                    wlast_r <= 1;
                end
                MMIO_W:
                if (m_axi.wready) begin
                    wlast_r <= 0;
                    state_q <= MMIO_B;
                end
                MMIO_B:
                if (m_axi.bvalid) begin
                    state_q <= MMIO_DONE;
                    mmio_valid <= 1;
                end
                default: ;
            endcase

        end
    end


    assign m_axi.awaddr = awaddr_r;
    assign m_axi.araddr = araddr_r;

    // Setup static AXI connections
    // AXI AR Channel
    assign m_axi.arlen   = (state_q == MMIO_AR) ? 8'd0   : 8'd1;
    assign m_axi.arsize  = (state_q == MMIO_AR) ? 3'b010 : 3'b100;
    assign m_axi.arburst = 2'b01;  // INCR (don't-care for len=0)
    assign m_axi.arlock  = 1'b0;
    assign m_axi.arcache = 4'b0011;  // normal non-cacheable bufferable
    assign m_axi.arprot  = 3'b000;
    assign m_axi.arvalid = (state_q == AXI_AR || state_q == MMIO_AR);
    assign m_axi.arid    = '0;
    assign m_axi.arqos   = '0;
    assign m_axi.aruser  = 1'b0;

    // ── AXI R channel ──
    assign m_axi.rready  = (state_q == AXI_R || state_q == MMIO_R);

    // assign stall_I   = 1'b0;
    // assign rd_data_i = '0;

    // ── AXI AW ──
    assign m_axi.awlen   = (state_q == MMIO_AW) ? 8'd0   : 8'd1;
    assign m_axi.awsize  = (state_q == MMIO_AW) ? 3'b010 : 3'b100;
    assign m_axi.awburst = 2'b01;
    assign m_axi.awlock  = 1'b0;
    assign m_axi.awcache = 4'b0011;
    assign m_axi.awprot  = 3'b000;
    assign m_axi.awvalid = (state_q == AXI_AW || state_q == MMIO_AW);
    assign m_axi.awid    = '0;
    assign m_axi.awqos   = '0;
    assign m_axi.awuser  = 1'b0;

    // ── AXI W ──
    assign m_axi.wdata  = wdata_r;
    assign m_axi.wlast  = wlast_r;
    assign m_axi.wstrb   = (state_q == MMIO_W)  ? (16'h000F << {addr_d[3:2], 2'b0}) : 16'hFFFF;
    assign m_axi.wvalid = (state_q == AXI_W || state_q == MMIO_W);

    // ── AXI B ──
    assign m_axi.bready = 1'b1;

endmodule
