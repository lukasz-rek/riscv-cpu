module register_file_tb;
    logic clk;
    logic rst_n;
    logic [4:0] rs1_addr, rs2_addr;
    logic [31:0] rs1_data, rs2_data;
    logic wr_en;
    logic [4:0] rd_addr;
    logic [31:0] rd_data;

    register_file dut (.*);

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        // Reset
        rst_n = 0;
        wr_en = 0;
        #20;
        rst_n = 1;
        #10;

        // Try to write to x0
        @(posedge clk);
        wr_en = 1;
        rd_addr = 0;
        rd_data = 32'hDEADBEEF;
        @(posedge clk);
        wr_en = 0;

        // Read from x0
        @(posedge clk);
        rs1_addr = 0;
        #1; // Let combinational logic settle
        
        if (rs1_data == 0)
            $display("PASS: x0 reads as 0");
        else
            $display("FAIL: x0 reads as %h", rs1_data);

        $finish;
    end
endmodule
