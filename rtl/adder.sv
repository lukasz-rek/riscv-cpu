// Simple adder module
module adder (
    input wire [31:0] a,
    input wire [31:0] b,
    output reg [31:0] result
);

    always @(*) begin
        result = a + b;
    end

endmodule
