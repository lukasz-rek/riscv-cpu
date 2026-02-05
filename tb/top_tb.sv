module top_tb;

    logic clk;
    logic rst_n;
    logic [31:0] result;

    // Instantiate DUT
    top dut (
        .clk(clk),
        .rst_n(rst_n)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns period = 100MHz
    end

    // Test sequence
    initial begin
        // Load program into memory
        $readmemh("code/build/program.hex", dut.mem.mem);
        
        $display("mem[0] = %02x", dut.mem.mem[0]);
        $display("mem[1] = %02x", dut.mem.mem[1]);
        $display("mem[2] = %02x", dut.mem.mem[2]);
        $display("mem[3] = %02x", dut.mem.mem[3]);

        // Reset sequence
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        
        // Run until done signal or timeout
        fork
            begin
                // Wait for done signal at 0x80001004
                // Wait for done signal at 0x80001004
wait(dut.mem.mem[32'h80001004 + 0] == 8'hEF &&
     dut.mem.mem[32'h80001004 + 1] == 8'hBE &&
     dut.mem.mem[32'h80001004 + 2] == 8'hAD &&
     dut.mem.mem[32'h80001004 + 3] == 8'hDE);
$display("Program completed at time %0t", $time);

// Check result at 0x80001000
result = {dut.mem.mem[32'h80001000 + 3],
          dut.mem.mem[32'h80001000 + 2],
          dut.mem.mem[32'h80001000 + 1],
          dut.mem.mem[32'h80001000 + 0]};
                
                $display("Result: %0d (expected: 2)", result);
                
                if (result == 2) begin
                    $display("TEST PASSED");
                end else begin
                    $display("TEST FAILED");
                end
                
                $finish;
            end
            
            begin
                // Timeout after 10000 cycles
                repeat(10000) @(posedge clk);
                $display("TIMEOUT - program did not complete");
           $display("Result: %0d (expected: 2)", result);
                $finish;
            end
        join_any
    end

    // Optional: waveform dump
    initial begin
        $dumpfile("logs/top_tb.fst");
        $dumpvars(0, top_tb);
    end

endmodule
