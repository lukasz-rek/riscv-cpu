module register_file #(
    parameter int XLEN = 32  // size of register
) (
    input  logic            clk,
    input  logic            rst_n,
    input  logic [     4:0] rs1_addr,
    input  logic [     4:0] rs2_addr,
    output logic [XLEN-1:0] rs1_data,
    output logic [XLEN-1:0] rs2_data,
    input  logic            wr_en,
    input  logic [     4:0] wr_addr,
    input  logic [XLEN-1:0] wr_data
);
  logic [XLEN-1:0] registers[31:0];
  // Reading can be combinational for now
  always_comb begin
    rs1_data = registers[rs1_addr];
    rs2_data = registers[rs2_addr];
  end

  // Writing
  always_ff @(posedge clk or negedge rst_n) begin : writeRegister
    if (!rst_n) begin
      for (int i = 0; i < 32; i++) registers[i] <= '0;
    end else if (wr_en && wr_addr != 0)
      // No writes to 0
      registers[wr_addr] <= wr_data;
  end
endmodule
