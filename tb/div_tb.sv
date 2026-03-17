module div_tb;


logic clk;
logic rst_n;

logic [31:0] a;
logic [31:0] b;
alu_op_t alu_op;
logic [31:0] result;

division_alu dut (
.clk(clk),
.rst_n(rst_n),
.a(a),
.b(b),
.alu_op(alu_op),
.result(result)
);

initial begin
    rst_n = 0;
    repeat(5) @(posedge clk);
    rst_n = 1;
end

initial begin
    clk = 0;
    forever #1 clk = ~clk;
end

parameter int UNSIGNED_LIMIT = 5; // test 0..999 × 0..999

initial begin

    $display("Starting");
    // Wait for reset to deassert
    @(posedge rst_n);
    repeat(2) @(posedge clk);

    alu_op = ALU_DIVU; // unsigned divide opcode

    for (logic [31:0] i = 0; i < UNSIGNED_LIMIT; i++) begin
        for (logic [31:0] j = 0; j < UNSIGNED_LIMIT; j++) begin
            a = i;
            b = j;
            @(posedge clk); // let DUT compute (assumes 1-cycle latency)
            #1;             // small settle time before sampling

            // --- self-check ---
            if (j == 0) begin
                // RISC-V spec: unsigned div-by-zero → all 1s
                if (result !== 32'hFFFF_FFFF)
                    $display("FAIL div-by-zero: %0d / %0d = %0h (expected FFFFFFFF)",
                             i, j, result);
            end else begin
                if (result !== (i / j))
                    $display("FAIL: %0d / %0d = %0h (expected %0h)",
                             i, j, result, i / j);
            end
        end
    end

    $display("Unsigned division sweep done.");
    $finish;
end

endmodule
