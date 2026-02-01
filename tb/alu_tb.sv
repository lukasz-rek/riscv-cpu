module alu_tb;
    logic [31:0] a, b;
    logic [3:0]  alu_op;
    logic [31:0] result;
    logic        zero;

    // ALU operations
    localparam ALU_ADD = 4'h0;
    localparam ALU_SUB = 4'h1;

    // Instantiate ALU
    alu uut (
        .a(a),
        .b(b),
        .alu_op(alu_op),
        .result(result),
        .zero(zero)
    );

    initial begin
        $dumpfile("waveform.fst");
        $dumpvars(0, alu_tb);

        // Test 1: 1 + 1 = 2
        a = 32'd1;
        b = 32'd1;
        alu_op = ALU_ADD;
        #10;
        $display("Test ADD: %d + %d = %d (expected 2)", a, b, result);
        if (result !== 32'd2) $error("ADD test failed!");

        // Test 2: 5 + 3 = 8
        a = 32'd5;
        b = 32'd3;
        alu_op = ALU_ADD;
        #10;
        $display("Test ADD: %d + %d = %d (expected 8)", a, b, result);
        if (result !== 32'd8) $error("ADD test failed!");

        // Test 3: 10 - 3 = 7
        a = 32'd10;
        b = 32'd3;
        alu_op = ALU_SUB;
        #10;
        $display("Test SUB: %d - %d = %d (expected 7)", a, b, result);
        if (result !== 32'd7) $error("SUB test failed!");

        #10;
        $display("All tests completed!");
        $finish;
    end

endmodule
