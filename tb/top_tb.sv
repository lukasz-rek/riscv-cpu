module top_tb;

    logic clk;
    logic rst_n;
    time     completion_time;
    real  completion_cycle;
    real  instr_count;

    /* verilator lint_off UNUSEDSIGNAL */
    logic uart_tx_pin;
    /* verilator lint_on UNUSEDSIGNAL */

    // Instantiate DUT
    top dut (
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx(uart_tx_pin)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #25 clk = ~clk;  // 50ns period = 20MHz
    end

    // Byte-to-word loader: hex file is one byte per line (little-endian)
    logic [7:0] program_bytes [0:32767];

    // Test sequence
    initial begin

        // Reset sequence
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;

        // Wait for done signal or timeout
        fork
            begin
                // Done flag at byte addr 0x1004 = word index 1025
                wait(dut.bram_mem.mem[16385] == 32'hDEADBEEF);

                completion_time  = $time;
                completion_cycle = dut.cpu.decode_stage.cycle_count;
                instr_count = dut.cpu.decode_stage.instr_count;
                // Wait for UART FIFO to drain and last byte to finish
                wait(dut.uart.fifo_empty);
                repeat(10) @(posedge clk);
                $display("Program completed at cycle %0d (sim time %0t)", completion_cycle, completion_time);
                $display("CPI was ~ %0f", completion_cycle / instr_count);

                $finish;
            end

            begin
                repeat(500000000) @(posedge clk);
                $display("TIMEOUT - program did not complete");
                $finish;
            end
        join_any
    end

    // Optional: waveform dump
    // initial begin
    //     $dumpfile("logs/top_tb.fst");
    //     $dumpvars(0, top_tb);
    // end

endmodule
