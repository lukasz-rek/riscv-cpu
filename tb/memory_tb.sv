module memory_tb;
    logic clk;
    logic [31:0] addr1;
    logic [31:0] addr2;
    logic wr_en;
    logic [31:0] wr_data;
    logic [31:0] rd_data1;
    logic [31:0] rd_data2;
    logic [3:0] byte_en;

    memory dut (.*);

    // Clock
    initial clk = 0;
    always #5 clk = ~clk;

    // Initialize memory with some test data
    initial begin
        // Write some known values at specific addresses
        dut.mem[0] = 8'h11;
        dut.mem[1] = 8'h22;
        dut.mem[2] = 8'h33;
        dut.mem[3] = 8'h44;
        
        dut.mem[4] = 8'hAA;
        dut.mem[5] = 8'hBB;
        dut.mem[6] = 8'hCC;
        dut.mem[7] = 8'hDD;
    end

    initial begin
        wr_en = 0;
        byte_en = 4'b0000;
        #10;

        // Read word at address 0
        addr1 = 32'h0;
        #1; // Let combinational logic settle
        assert(rd_data1 == 32'h44332211) 
            $display("PASS: addr 0x%h = 0x%h", addr1, rd_data1);
        else 
            $error("FAIL: addr 0x%h = 0x%h, expected 0x44332211", addr1, rd_data1);

        // Read word at address 4
        addr1 = 32'h4;
        #1;
        assert(rd_data1 == 32'hDDCCBBAA)
            $display("PASS: addr 0x%h = 0x%h", addr1, rd_data1);
        else
            $error("FAIL: addr 0x%h = 0x%h, expected 0xDDCCBBAA", addr1, rd_data1);

        #20;
        $finish;
    end
endmodule
