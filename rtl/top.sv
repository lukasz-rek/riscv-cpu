module top (
    input  logic clk,          // System clock
    input  logic rst_n,        // Active-low reset
    
    // Debug/output ports
    output logic [31:0] debug_pc,        // Current program counter
    output logic [31:0] debug_instr,     // Current instruction
    output logic [31:0] debug_alu_result, // ALU result
    output logic        debug_mem_write,  // Memory write enable
    output logic [31:0] debug_mem_addr,   // Memory address
    output logic [31:0] debug_mem_wdata,  // Memory write data
    output logic [31:0] debug_mem_rdata1, // Memory read data port 1
    output logic [31:0] debug_mem_rdata2  // Memory read data port 2
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

  // Connect debug signals
  assign debug_pc = cpu.pc;  // Need to expose pc from core
  assign debug_instr = mem_rd_data1;
  assign debug_alu_result = cpu.alu_result;  // Need to expose alu_result from core
  assign debug_mem_write = mem_wr_en;
  assign debug_mem_addr = mem_wr_addr;
  assign debug_mem_wdata = mem_wr_data;
  assign debug_mem_rdata1 = mem_rd_data1;
  assign debug_mem_rdata2 = mem_rd_data2;

endmodule
