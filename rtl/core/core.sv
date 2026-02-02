module core (
    input  logic        clk,
    input  logic        rst_n,
    // Memory interface
    output logic [31:0] mem_addr,
    output logic        mem_wr_en,
    output logic [31:0] mem_wr_data,
    input  logic [31:0] mem_rd_data,
    output logic [ 3:0] mem_byte_en
);
  logic [31:0] instruction;
  logic [31:0] pc;



  // 1st: Decode
  assign instruction = mem_rd_data;



endmodule
