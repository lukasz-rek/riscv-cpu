
module axi_cache #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,

    localparam int CACHE_LINE_SIZE = 8,  // 256 b always
    parameter int CACHE_SIZE = 4,  // In 4KB blocks

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
    output logic                  miss,
    output logic                  dirty_evict,
    output logic [         127:0] cache_evicted_data
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

    // Initialize cache + bookkeeping
    (* ram_style = "block" *) logic [255:0] cache[NUM_SETS];
    tag_entry_t cache_info[NUM_SETS];  // TAG, VALID, DIRTY

    logic miss_state_q;
    logic evicted_count_q;

    // Handle the lookup
    wire [INDEX_BITS-1:0] requested_line;
    wire [TAG_BITS-1:0] tag;
    wire [OFFSET_BITS-3:0] requested_block;  // Shorter by 2 bits cause we're selecting words only

    assign requested_block = addr[2+:OFFSET_BITS-2];
    assign requested_line = addr[OFFSET_BITS+:INDEX_BITS];
    assign tag = addr[OFFSET_BITS+INDEX_BITS+:TAG_BITS];

    // If tag doesn't match or line is invalid but only when we're actually requesting sth, keep it up during eviction cycle
    wire first_miss;

    assign first_miss = ((cache_info[requested_line].tag != tag || !cache_info[requested_line].valid )
        && (rd_en || wr_en) && !miss_state_q);
    assign dirty_evict = first_miss && cache_info[requested_line].dirty;

    assign miss = first_miss || miss_state_q;


    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_SETS; i++) begin
                cache_info[i].valid <= 0;
            end
            rd_data <= 32'b0;
            miss_state_q <= 0;
            evicted_count_q <= 0;
        end else begin
            // Some defaults to not propagate gibberish
            rd_data <= '0;
            cache_evicted_data <= '0;
            if (first_miss) begin
                miss_state_q <= 1;
            end
            if (cache_load != 2'b00) begin
                // Depending on which beat we are on, we need diff base
                automatic int base = (cache_load == 2'b01) ? 0 : 4;
                for (int i = 0; i < 4; i++) begin
                    cache[requested_line][(base+i)*32+:32] <= cache_load_data[i*32+:32];
                end
                if (cache_load == 2'b10) begin
                    cache_info[requested_line].valid <= 1'b1;
                    cache_info[requested_line].dirty <= 1'b0;
                    cache_info[requested_line].tag <= tag;
                    // Clear missed state
                    miss_state_q <= 0;
                    rd_data <= cache[requested_line][requested_block*32+:32];
                end
            end else if ((first_miss && dirty_evict) || miss_state_q) begin
                // Handle 2 miss cycles needed to output all evicted data
                // Note that this should happen only if line is dirty
                if (first_miss) begin
                    cache_evicted_data <= cache[requested_line][127:0];
                    evicted_count_q <= 1;
                end else if (evicted_count_q) begin
                    cache_evicted_data <= cache[requested_line][255:128];
                    evicted_count_q <= 0;
                end else cache_evicted_data <= '0;
            end else if (rd_en) begin
                // Plain read
                rd_data <= cache[requested_line][requested_block*32+:32];
            end else if (wr_en) begin
                // Modify data, set dirty
                for (int i = 0; i < 4; i++) begin
                        if (byte_en[i])
                            cache[requested_line][requested_block*32 + i*8 +: 8] <= wr_data[i*8 +: 8];
                    end
                    cache_info[requested_line].dirty <= 1'b1;
            end
        end

    end


endmodule
