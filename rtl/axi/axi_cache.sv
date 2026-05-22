
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

    // Initialize cache + bookkeeping
    (* ram_style = "block" *) logic [255:0] cache[NUM_SETS];
    logic [255:0] cache_line;
    logic [255:0] cache_wdata;
    logic [31:0] cache_wbe;

    tag_entry_t cache_info_q[NUM_SETS];  // TAG, VALID, DIRTY
    tag_entry_t cache_info;
    cache_state_t cache_state;

    // Handle the lookup
    wire [INDEX_BITS-1:0] requested_line;
    logic [INDEX_BITS-1:0] prev_requested_line;
    wire [TAG_BITS-1:0] tag;
    wire [OFFSET_BITS-3:0] requested_block;  // Shorter by 2 bits cause we're selecting words only
    logic [OFFSET_BITS-3:0] requested_block_q;

    wire consecutive_read;

    assign requested_block = addr[2+:OFFSET_BITS-2];
    assign requested_line = addr[OFFSET_BITS+:INDEX_BITS];
    assign tag = addr[OFFSET_BITS+INDEX_BITS+:TAG_BITS];

    // Handle stall indication
    assign consecutive_read = (prev_requested_line == requested_line) && !miss;

    assign stall = !(cache_state == CACHE_LOOKUP || (cache_state == CACHE_ACCESS && consecutive_read));

    assign miss = (tag != cache_info.tag) || !cache_info.valid;
    assign dirty_evict = (miss && cache_info.dirty);


    // Intermediate signals so BRAM is properly inferred
    always_comb begin
        cache_wdata = '0;
        cache_wbe = '0;

        cache_evicted_data = cache_line;
        evicted_addr = {cache_info.tag, requested_line, requested_block, 2'b0};
        if (cache_load == 2'b01) begin
            cache_wdata[127:0] = cache_load_data;
            cache_wbe[15:0]    = '1;
        end else if (cache_load == 2'b10) begin
            cache_wdata[255:128] = cache_load_data;
            cache_wbe[31:16]     = '1;
        end else if (wr_en && !miss) begin
            for (int i = 0; i < 8; i++) cache_wdata[i*32+:32] = wr_data;
            cache_wbe[requested_block*4+:4] = byte_en;
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            requested_block_q <= 0;
            cache_line <= '0;
            cache_state <= CACHE_OFF;
            prev_requested_line <= '0;
        end else begin
            requested_block_q <= requested_block;
            case (cache_state)
                CACHE_OFF:
                if (rd_en || wr_en) begin
                    cache_state <= CACHE_LOOKUP;
                    cache_info <= cache_info_q[requested_line];
                    prev_requested_line <= requested_line;
                end
                CACHE_LOOKUP: begin
                    // If it's valid, perform action
                    // I invalid, go into refill actions
                    if (cache_info.valid && !miss) begin
                        cache_state <= CACHE_ACCESS;
                        cache_line  <= cache[requested_line];
                        if (wr_en) cache_info_q[requested_line].dirty <= 1'b1;
                    end else begin
                        cache_state <= CACHE_REFILL;
                    end
                end
                CACHE_ACCESS:
                if ((rd_en) && consecutive_read) begin
                    // Since the exposed line is requested, we can continue with serving data
                    cache_state <= CACHE_ACCESS;
                end else cache_state <= CACHE_OFF;
                CACHE_REFILL: begin
                    if (cache_load != 2'b00) begin
                        if (cache_load == 2'b10) begin
                            cache_info_q[requested_line].valid <= 1'b1;
                            cache_info.valid <= 1'b1;
                            cache_info_q[requested_line].dirty <= 1'b0;
                            cache_info.dirty <= 1'b0;
                            cache_info_q[requested_line].tag <= tag;
                            cache_info.tag <= tag;
                            // Exit refill state
                            cache_state <= CACHE_LOOKUP;
                        end
                    end
                end
                default: ;
            endcase

            if (wr_en) cache_info_q[requested_line].dirty <= 1'b1;

            // Handle BRAM write-byte-enable
            for (int i = 0; i < 32; i++)
            if (cache_wbe[i]) cache[requested_line][i*8+:8] <= cache_wdata[i*8+:8];

        end

    end
    assign rd_data = cache_line[requested_block_q*32+:32];
endmodule
