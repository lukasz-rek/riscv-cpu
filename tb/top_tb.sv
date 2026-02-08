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

    // Byte-to-word loader: hex file is one byte per line (little-endian)
    logic [7:0] program_bytes [0:4095];

    // Test sequence
    initial begin
        // Load program (byte-per-line hex) and assemble into 32-bit words
        for (int i = 0; i < 4096; i++) program_bytes[i] = 0;
        $readmemh("code/build/program.hex", program_bytes);
        for (int i = 0; i < 1024; i++) begin
            dut.bram_mem.mem[i] = {program_bytes[i*4+3], program_bytes[i*4+2],
                                   program_bytes[i*4+1], program_bytes[i*4]};
        end

        $display("mem[0] = %08h", dut.bram_mem.mem[0]);
        $display("mem[1] = %08h", dut.bram_mem.mem[1]);
        $display("mem[2] = %08h", dut.bram_mem.mem[2]);
        $display("mem[3] = %08h", dut.bram_mem.mem[3]);

        // Reset sequence
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;

        // Run until done signal or timeout
        fork
            begin
                // Wait for done signal (0xDEADBEEF) at byte address 0x80001004
                // Wraps to word index 1025 in 64K-word BRAM (addr[17:2])
                wait(dut.bram_mem.mem[1025] == 32'hDEADBEEF);
                $display("Program completed at time %0t", $time);

                // Check result at word index 1024 (byte address 0x80001000)
                result = dut.bram_mem.mem[1024];

                $display("Result: %0d (expected: 2)", result);

                if (result == 2) begin
                    $display("TEST PASSED");
                end else begin
                    $display("TEST FAILED");
                end

                $finish;
            end

            begin
                // Timeout after 30000 cycles (multi-cycle core: 2-3 cycles per instr)
                repeat(30000) @(posedge clk);
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
