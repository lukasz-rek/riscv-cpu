module top (
    input  logic clk,
    input  logic rst_n,
    // Debug outputs to prevent optimization
    output logic [31:0] debug_mem_addr1,
    output logic [31:0] debug_mem_data1,
    output logic        debug_mem_wr_en
);

    // Memory interface signals
    logic [31:0] mem_addr1;
    logic [31:0] mem_addr2;
    logic        mem_wr_en;
    logic [31:0] mem_wr_data;
    logic [31:0] mem_wr_addr;
    logic [31:0] mem_rd_data1;
    logic [31:0] mem_rd_data2;
    logic [ 3:0] mem_byte_en;

    // Instantiate core
    core cpu (
        .clk(clk),
        .rst_n(rst_n),
        .mem_addr1(mem_addr1),
        .mem_addr2(mem_addr2),
        .mem_wr_en(mem_wr_en),
        .mem_wr_data(mem_wr_data),
        .mem_wr_addr(mem_wr_addr),
        .mem_rd_data1(mem_rd_data1),
        .mem_rd_data2(mem_rd_data2),
        .mem_byte_en(mem_byte_en)
    );

    // Instantiate memory
    memory mem (
        .clk(clk),
        .addr1(mem_addr1),
        .addr2(mem_addr2),
        .wr_en(mem_wr_en),
        .wr_data(mem_wr_data),
        .wr_addr(mem_wr_addr),
        .rd_data1(mem_rd_data1),
        .rd_data2(mem_rd_data2),
        .byte_en(mem_byte_en)
    );

    // Connect debug outputs
    assign debug_mem_addr1 = mem_addr1;
    assign debug_mem_data1 = mem_rd_data1;
    assign debug_mem_wr_en = mem_wr_en;

endmodule