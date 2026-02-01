// Testbench for adder module
module adder_tb;

    // Signals
    reg [31:0] a;
    reg [31:0] b;
    wire [31:0] result;

    // Instantiate the adder
    adder uut (
        .a(a),
        .b(b),
        .result(result)
    );

    // Test cases
    initial begin
        // Initialize inputs
        a = 0;
        b = 0;

        // Test case 1: 0 + 0 = 0
        #10;
        $display("Test 1: %d + %d = %d", a, b, result);
        if (result !== 0) $error("Test 1 failed");

        // Test case 2: 5 + 3 = 8
        a = 5;
        b = 3;
        #10;
        $display("Test 2: %d + %d = %d", a, b, result);
        if (result !== 8) $error("Test 2 failed");

        // Test case 3: 100 + 200 = 300
        a = 100;
        b = 200;
        #10;
        $display("Test 3: %d + %d = %d", a, b, result);
        if (result !== 300) $error("Test 3 failed");

        // Test case 4: Maximum values
        a = 32'hFFFFFFFF;
        b = 32'hFFFFFFFF;
        #10;
        $display("Test 4: %h + %h = %h", a, b, result);
        if (result !== 32'hFFFFFFFE) $error("Test 4 failed");

        // Finish simulation
        #10;
        $display("All tests passed!");
        $finish;
    end

endmodule
