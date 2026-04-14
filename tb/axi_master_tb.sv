`timescale 1ns / 1ps

module axi_master_tb;
    logic clk;
    logic rst_n;

    logic [31:0] addr1, addr2, wr_addr;
    logic        wr_en;
    logic [31:0] wr_data;
    logic [31:0] rd_data1, rd_data2;
    logic [ 3:0] byte_en;
    logic        stall_I, stall_D;

    axi_if m_axi();

    axi_master dut (
        .clk(clk),
        .rst_n(rst_n),
        .addr1('0),
        .addr2('0),
        .wr_addr('0),
        .wr_en(1'b0),
        .wr_data('0),
        .rd_data1(rd_data1),
        .rd_data2(rd_data2),
        .byte_en('0),
        .stall_I(stall_I),
        .stall_D(stall_D),
        .m_axi(m_axi)
    );

    // 10ns period = 100MHz
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
        #200;
        $finish;
    end

    initial begin
        $dumpfile("axi_master_tb.vcd");
        $dumpvars(0, axi_master_tb);
    end
endmodule
