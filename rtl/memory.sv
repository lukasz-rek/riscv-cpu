module memory #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int MEM_SIZE   = 4096  // in bytes
) (
    input  logic                  clk,
    // 2 ports are needed so both instructions and 
    input  logic [ADDR_WIDTH-1:0] addr1,
    input  logic [ADDR_WIDTH-1:0] addr2,     // Also used for writes
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic [DATA_WIDTH-1:0] rd_data1,
    output logic [DATA_WIDTH-1:0] rd_data2,
    input  logic [           3:0] byte_en    // for byte/halfword/word access
);

  logic [7:0] mem[MEM_SIZE-1:0];

  always_comb begin
    rd_data1 = {mem[addr1+3], mem[addr1+2], mem[addr1+1], mem[addr1]};
    rd_data2 = {mem[addr2+3], mem[addr2+2], mem[addr2+1], mem[addr2]};
  end

  always_ff @(posedge clk) begin
    if (wr_en) begin
      if (byte_en[0]) mem[addr2] <= wr_data[7:0];
      if (byte_en[1]) mem[addr2+1] <= wr_data[15:8];
      if (byte_en[2]) mem[addr2+2] <= wr_data[23:16];
      if (byte_en[3]) mem[addr2+3] <= wr_data[31:24];
    end
  end
endmodule
