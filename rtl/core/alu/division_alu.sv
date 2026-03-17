/* verilator lint_off IMPORTSTAR */
import core_pkg::*;
/* verilator lint_on IMPORTSTAR */



module division_alu (
    input clk,
    input rst_n,

    input logic [31:0] a,
    input logic [31:0] b,
    input alu_op_t alu_op,

    output logic [31:0] result
);
    assign result = (b == '0) ? '1 : a / b;

endmodule
