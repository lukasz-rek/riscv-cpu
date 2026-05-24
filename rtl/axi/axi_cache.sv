module axi_cache #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,

    localparam int CACHE_LINE_SIZE = 8,  // 256 b always
    parameter int CACHE_SIZE = 8,  // In 4KB blocks

    localparam int LINE_BYTES  = CACHE_LINE_SIZE * 4,
    localparam int OFFSET_BITS = $clog2(LINE_BYTES),
    localparam int NUM_SETS    = (CACHE_SIZE * 4096) / LINE_BYTES,
    localparam int INDEX_BITS  = $clog2(NUM_SETS),
    localparam int TAG_BITS    = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS
) (
    input logic clk,
    input logic rst_n,

    // Memory interface
    /* verilator lint_off UNUSEDSIGNAL */
    input logic [ADDR_WIDTH-1:0] addr,
    /* verilator lint_on UNUSEDSIGNAL */
    input logic [DATA_WIDTH-1:0] wr_data,
    input logic                  wr_en,
    input logic                  rd_en,
    input logic [           3:0] byte_en,

    // Handle inserting things into cache, for perf reasons
    // we're loading 256b - 8 words
    input logic [  1:0] cache_load,
    input logic [127:0] cache_load_data, // AXI can only supply 4 words per transaction

    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  stall,
    output logic                  miss,
    output logic                  dirty_evict,
    output logic [         255:0] cache_evicted_data,
    output logic [          31:0] evicted_addr
);

    typedef struct packed {
        logic                valid;
        logic                dirty;
        logic [TAG_BITS-1:0] tag;
    } tag_entry_t;

    initial begin
        $display("=== Cache Configuration ===");
        $display("Line size:   %0d bytes (%0d words)", LINE_BYTES, CACHE_LINE_SIZE);
        $display("Num sets:    %0d", NUM_SETS);
        $display("Cache size:  %0d KB", (NUM_SETS * LINE_BYTES) / 1024);
        $display("Tag bits:    %0d", TAG_BITS);
        $display("Index bits:  %0d", INDEX_BITS);
        $display("Offset bits: %0d", OFFSET_BITS);
        $display("===========================");
    end

    // -------------------------------------------------------------------------
    // BRAM storage arrays
    // -------------------------------------------------------------------------
    (* ram_style = "block" *) logic [255:0]         cache      [NUM_SETS];
    (* ram_style = "block" *) logic [TAG_BITS+1:0]  cache_info [NUM_SETS]; // {TAG, VALID, DIRTY}

    // Raw BRAM outputs — these regs have EXACTLY ONE driver so they map
    // onto the BRAM primitive's internal output flop. Do not add any
    // other assignments to these. Bypass happens outside the BRAM.
    logic       [255:0] cache_line_raw;
    tag_entry_t         current_cache_info_raw;

    // Post-bypass versions used everywhere else in the module
    logic       [255:0] cache_line;
    tag_entry_t         current_cache_info;

    logic       [INDEX_BITS-1:0]   current_cache_info_line;

    // Write-side combinational nets
    logic       [       255:0] cache_wdata;
    logic       [        31:0] cache_wbe;
    tag_entry_t                cache_info_write;
    logic                      cache_info_we;

    // Registered copies of the previous-cycle write request — used to bypass
    // the BRAM read-first behavior when the line we're reading was just written.
    logic       [255:0]            cache_wdata_q;
    logic       [31:0]             cache_wbe_q;
    logic       [INDEX_BITS-1:0]   write_line_q;
    tag_entry_t                    cache_info_write_q;
    logic                          cache_info_we_q;

    initial begin
        for (int i = 0; i < NUM_SETS; i++) cache[i] = '0;
        for (int i = 0; i < NUM_SETS; i++) cache_info[i] = '0;
    end

    // -------------------------------------------------------------------------
    // Address decomposition
    // -------------------------------------------------------------------------
    wire  [INDEX_BITS-1:0]  requested_line;
    wire  [TAG_BITS-1:0]    requested_tag;
    wire  [OFFSET_BITS-3:0] requested_block;     // word index within line
    logic [OFFSET_BITS-3:0] requested_block_q;   // needed for masking on access due to BRAM pattern

    assign requested_block = addr[2+:OFFSET_BITS-2];
    assign requested_line  = addr[OFFSET_BITS+:INDEX_BITS];
    assign requested_tag   = addr[OFFSET_BITS+INDEX_BITS+:TAG_BITS];

    // -------------------------------------------------------------------------
    // Control / status outputs
    // -------------------------------------------------------------------------
    assign stall       = (rd_en || wr_en) && (requested_line != current_cache_info_line);
    assign miss        = (rd_en || wr_en) && (requested_tag != current_cache_info.tag || !current_cache_info.valid);
    assign dirty_evict = miss && current_cache_info.dirty;

    // -------------------------------------------------------------------------
    // Write-port datapath (combinational)
    // -------------------------------------------------------------------------
    always_comb begin
        cache_wdata        = '0;
        cache_wbe          = '0;
        cache_info_write   = '0;

        cache_info_we      = 1'b0;
        cache_info_write   = current_cache_info;

        cache_evicted_data = cache_line;
        evicted_addr       = {current_cache_info.tag, requested_line, {OFFSET_BITS{1'b0}}};

        unique case (cache_load)
            2'b01: begin
                cache_wdata[127:0] = cache_load_data;
                cache_wbe[15:0]    = '1;
            end
            2'b10: begin
                cache_info_write.tag   = requested_tag;
                cache_info_write.dirty = 1'b0;
                cache_info_write.valid = 1'b1;
                cache_info_we          = 1'b1;
                cache_wdata[255:128]   = cache_load_data;
                cache_wbe[31:16]       = '1;
            end
            default: begin
                if (wr_en && !miss) begin
                    for (int i = 0; i < 8; i++) cache_wdata[i*32+:32] = wr_data;
                    cache_wbe[requested_block*4+:4] = byte_en;
                    cache_info_we                   = 1'b1;
                    cache_info_write.dirty          = 1'b1;
                end
            end
        endcase
    end

    // -------------------------------------------------------------------------
    // BRAM patterns — KEEP CLEAN. Each output reg has exactly one driver,
    // otherwise inference falls back to LUTRAM.
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        // Data array — read-first inference template
        cache_line_raw <= cache[requested_line];

        for (int i = 0; i < 32; i++) begin
            if (cache_wbe[i]) begin
                cache[requested_line][i*8+:8] <= cache_wdata[i*8+:8];
            end
        end

        // Tag/info array
        current_cache_info_raw <= tag_entry_t'(cache_info[requested_line]);
        if (cache_info_we) begin
            cache_info[requested_line] <= cache_info_write;
        end

        // Line that the BRAM output regs currently hold
        current_cache_info_line <= requested_line;
    end

    // -------------------------------------------------------------------------
    // RAW bypass — register the previous cycle's write request and mux the
    // written bytes / new tag into the BRAM read outputs combinationally.
    // This recovers the "skip RAW cycle" behavior without touching the
    // BRAM output registers.
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            cache_wbe_q     <= '0;
            cache_info_we_q <= 1'b0;
        end else begin
            cache_wdata_q      <= cache_wdata;
            cache_wbe_q        <= cache_wbe;
            write_line_q       <= requested_line;
            cache_info_write_q <= cache_info_write;
            cache_info_we_q    <= cache_info_we;
        end
    end

    // Per-byte data bypass — only when last cycle's write hit the line that
    // the BRAM output regs are currently holding.
    always_comb begin
        cache_line = cache_line_raw;
        if (write_line_q == current_cache_info_line) begin
            for (int i = 0; i < 32; i++) begin
                if (cache_wbe_q[i]) cache_line[i*8+:8] = cache_wdata_q[i*8+:8];
            end
        end
    end

    // Tag/info bypass
    assign current_cache_info =
        (cache_info_we_q && (write_line_q == current_cache_info_line))
            ? cache_info_write_q
            : current_cache_info_raw;

    // -------------------------------------------------------------------------
    // rd_data path
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) requested_block_q <= '0;
        else        requested_block_q <= requested_block;
    end

    assign rd_data = cache_line[requested_block_q*32+:32];

endmodule
