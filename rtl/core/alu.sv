/* verilator lint_off IMPORTSTAR */
import core_pkg::*;
/* verilator lint_on IMPORTSTAR */


module alu (
    input  logic    [31:0] a,
    input  logic    [31:0] b,
    input  alu_op_t        alu_op,
    output logic    [31:0] result,
    output logic           zero
);

  always_comb begin
    case (alu_op)
      ALU_ADD: result = a + b;
      ALU_SUB: result = a - b;
      ALU_AND: result = a & b;
      ALU_XOR: result = a ^ b;
      ALU_OR:  result = a | b;
      // For shifts in slli, srli etc, only 5 bits used
      ALU_SLL: result = a << b[4:0];
      ALU_SRL: result = a >> b[4:0];
      ALU_SRA: result = $signed(a) >>> b[4:0];

      // Signed comparisions
      ALU_SLT:  result = {31'b0, $signed(a) < $signed(b)};
      ALU_SLTU: result = {31'b0, a < b};
      default:  result = 32'h0;
    endcase
  end

  assign zero = (result == 32'h0);
endmodule
