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
    input logic [127:0] cache_load_data,


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

    typedef enum logic [3:0] {
        CACHE_OFF,
        CACHE_LOOKUP,
        // Now depending on valid we go
        CACHE_ACCESS,
        // Or on miss
        CACHE_REFILL
    } cache_state_t;


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
    (* ram_style = "block" *) logic [255:0] cache [NUM_SETS];
    (* ram_style = "block" *) logic [TAG_BITS+1:0] cache_info_bram [NUM_SETS];  // {TAG, VALID, DIRTY}

    // Registered BRAM outputs (no reset — these are the BRAM output regs)
    logic [255:0]   cache_line;
    tag_entry_t     cache_info;

    // Write-side combinational nets
    logic [255:0]   cache_wdata;
    logic [31:0]    cache_wbe;
    tag_entry_t     cache_info_write;
    logic           cache_info_we;

    // FSM
    cache_state_t cache_state;

    // BRAM init (Vivado picks this up as INIT_xx parameters)
    initial begin
        for (int i = 0; i < NUM_SETS; i++) cache[i]           = '0;
        for (int i = 0; i < NUM_SETS; i++) cache_info_bram[i] = '0;
    end

    // -------------------------------------------------------------------------
    // Address decomposition
    // -------------------------------------------------------------------------
    wire  [INDEX_BITS-1:0]  requested_line;
    wire  [TAG_BITS-1:0]    tag;
    wire  [OFFSET_BITS-3:0] requested_block;  // word index within line
    logic [OFFSET_BITS-3:0] requested_block_q;

    assign requested_block = addr[2+:OFFSET_BITS-2];
    assign requested_line  = addr[OFFSET_BITS+:INDEX_BITS];
    assign tag             = addr[OFFSET_BITS+INDEX_BITS+:TAG_BITS];

    // -------------------------------------------------------------------------
    // Control / status outputs
    // -------------------------------------------------------------------------
    assign stall       = (cache_state != CACHE_LOOKUP) && (rd_en || wr_en);
    assign miss        = ((tag != cache_info.tag) || !cache_info.valid) && (rd_en || wr_en);
    assign dirty_evict = (miss && cache_info.dirty);

    // -------------------------------------------------------------------------
    // Write-port datapath (combinational)
    // -------------------------------------------------------------------------
    always_comb begin
        cache_wdata        = '0;
        cache_wbe          = '0;
        cache_info_write   = '0;
        cache_info_we      = 1'b0;

        cache_evicted_data = cache_line;
        evicted_addr       = {cache_info.tag, requested_line, requested_block, 2'b0};

        unique case (cache_load)
            2'b01: begin
                cache_wdata[127:0] = cache_load_data;
                cache_wbe[15:0]    = '1;
            end
            2'b10: begin
                cache_info_write.tag   = tag;
                cache_info_write.dirty = 1'b0;
                cache_info_write.valid = 1'b1;
                cache_info_we          = 1'b1;
                cache_wdata[255:128]   = cache_load_data;
                cache_wbe[31:16]       = '1;
            end
            default: begin
                if (wr_en && !miss && cache_state == CACHE_LOOKUP) begin
                    for (int i = 0; i < 8; i++) cache_wdata[i*32+:32] = wr_data;
                    cache_wbe[requested_block*4+:4] = byte_en;
                end
            end
        endcase
    end

    // -------------------------------------------------------------------------
    // Data BRAM — canonical byte-write template (UG901)
    //   * Unconditional registered read
    //   * Per-byte conditional write
    //   * NO reset on cache_line — it's the BRAM output register
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        for (int i = 0; i < 32; i++) begin
            if (cache_wbe[i])
                cache[requested_line][i*8+:8] <= cache_wdata[i*8+:8];
        end
        cache_line <= cache[requested_line];
    end

    // -------------------------------------------------------------------------
    // Tag BRAM — same template
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (cache_info_we)
            cache_info_bram[requested_line] <= cache_info_write;
        cache_info <= tag_entry_t'(cache_info_bram[requested_line]);
    end

    // -------------------------------------------------------------------------
    // FSM (no BRAM signals reset here)
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            cache_state       <= CACHE_OFF;
            requested_block_q <= '0;
        end else begin
            requested_block_q <= requested_block;
            case (cache_state)
                CACHE_OFF: begin
                    if (rd_en || wr_en) cache_state <= CACHE_LOOKUP;
                end
                CACHE_LOOKUP: begin
                    if (cache_info.valid && !miss) cache_state <= CACHE_ACCESS;
                    else                           cache_state <= CACHE_REFILL;
                end
                CACHE_ACCESS: cache_state <= CACHE_OFF;
                CACHE_REFILL: begin
                    // Exit refill once the upper half + tag have been written
                    if (cache_load == 2'b10) cache_state <= CACHE_LOOKUP;
                end
                default: cache_state <= CACHE_OFF;
            endcase
        end
    end

    assign rd_data = cache_line[requested_block_q*32+:32];

endmodule
