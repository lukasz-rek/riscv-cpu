
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
    input logic cache_load_1,
    input logic cache_load_2,
    input logic [127:0] cache_load_data,


    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  miss,
    output logic                  dirty_evict
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
    logic [31:0] cache[CACHE_LINE_SIZE][NUM_SETS];
    tag_entry_t cache_info[NUM_SETS];  // TAG, VALID, DIRTY

    // Handle the lookup
    wire [INDEX_BITS-1:0] requested_line;
    wire [TAG_BITS-1:0] tag;
    wire [OFFSET_BITS-3:0] requested_block;  // Shorter by 2 bits cause we're selecting words only

    assign requested_block = addr[2+:OFFSET_BITS-2];
    assign requested_line = addr[OFFSET_BITS+:INDEX_BITS];
    assign tag = addr[OFFSET_BITS+INDEX_BITS+:TAG_BITS];

    assign miss = ((cache_info[requested_line].tag != tag || !cache_info[requested_line].valid )
        && (rd_en || wr_en));

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_SETS; i++) begin
                cache_info[i].valid <= 0;
            end
            dirty_evict <= 1'b0;
            rd_data <= 32'b0;
        end else begin
            if (cache_load_1 || cache_load_2) begin
                // Depending on which beat we are on, we need diff base
                automatic int base = cache_load_1 ? 0 : 4;
                for (int i = 0; i < 4; i++) begin
                    cache[base+i][requested_line] <= cache_load_data[i*32+:32];
                end
                // Will be written twice but oh well
                cache_info[requested_line].valid <= 1'b1;
                cache_info[requested_line].dirty <= 1'b0;
                cache_info[requested_line].tag   <= tag;
            end else if (miss || rd_en) begin
                // Output what we'll likely be evicting soon
                // or just normal data
                rd_data <= cache[requested_block][requested_line];
                dirty_evict <= miss ? cache_info[requested_line].dirty : 1'b0;
            end else if (wr_en) begin
                // Modify data, set dirty
                if (byte_en[0]) cache[requested_block][requested_line][7:0] <= wr_data[7:0];
                if (byte_en[1]) cache[requested_block][requested_line][15:8] <= wr_data[15:8];
                if (byte_en[2]) cache[requested_block][requested_line][23:16] <= wr_data[23:16];
                if (byte_en[3]) cache[requested_block][requested_line][31:24] <= wr_data[31:24];

                cache_info[requested_line].dirty <= 1'b1;
            end
        end
    end

endmodule
