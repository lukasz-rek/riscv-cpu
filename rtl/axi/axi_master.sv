
module axi_master #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter logic [35:0] START_ADDR = 36'h8_4000_0000,
    // Cache params
    parameter int CACHE_LINE_SIZE = 8, // In words so 4B
    parameter int CACHE_SIZE = 4, // In 4KB blocks

    // Derive cache sizes
    localparam int LINE_BYTES = CACHE_LINE_SIZE * 4,
    localparam int OFFSET_BITS = $clog2(LINE_BYTES),
    localparam int NUM_SETS     = (CACHE_SIZE * 4096) / LINE_BYTES,
    localparam int INDEX_BITS   = $clog2(NUM_SETS),
    localparam int TAG_BITS     = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS
) (
    input logic clk,
    input logic rst_n,

    // Memory interface
    input  logic [ADDR_WIDTH-1:0] addr1,
    input  logic [ADDR_WIDTH-1:0] addr2,
    input  logic [ADDR_WIDTH-1:0] wr_addr,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic [DATA_WIDTH-1:0] rd_data1,
    output logic [DATA_WIDTH-1:0] rd_data2,
    input  logic [           3:0] byte_en,


    output logic stall_I,
    output logic stall_D,
    // AXI connections
    axi_if.master m_axi
);
// Print into about cache for easier debug
// synth translate_off
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
// synth translate_on





endmodule
