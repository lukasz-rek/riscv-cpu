module alu (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [3:0]  alu_op,
    output logic [31:0] result,
    output logic        zero
);

    assign result = 32'h0;
    assign zero = 1'b1;

endmodule
