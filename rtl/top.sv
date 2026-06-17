
module top #(
    // parameter INIT_FILE = "code/build/program.hex"
    // parameter INIT_FILE = "code/coremark/build/coremark.hex"
) (
    input logic clk,
    input logic rst_n,
    input logic meip,
    input logic mtip,
    input logic msip,
    input logic seip,


    axi_if.master m_axi
);


    // Memory signals
    logic [31:0] addr_d;
    logic [31:0] addr_i;

    logic [31:0] mem_wr_data;

    logic mem_wr_en;
    logic rd_en_d;
    logic rd_en_i;
    logic [3:0] byte_en_d;


    logic [31:0] rd_data_d;

    logic [31:0] rd_data_i;
    logic stall_D;
    logic stall_I;

    logic flush_I;


    core cpu (
        .clk(clk),
        .rst_n(rst_n),
        .mem_addr1(addr_i),
        .mem_addr2(addr_d),
        .mem_wr_en(mem_wr_en),
        .mem_wr_data(mem_wr_data),
        .mem_rd_data1(rd_data_i),
        .mem_rd_data2(rd_data_d),
        .mem_byte_en(byte_en_d),
        .stall_I(stall_I),
        .stall_D(stall_D),
        .rd_en_d(rd_en_d),
        .rd_en_i(rd_en_i),
        .flush_I(flush_I),

        .mtime_isr(mtip),
        .meip_isr (meip),
        .msip_isr (msip),
        .seip_isr (seip)
    );


    axi_master #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .START_ADDR(36'h7_C000_0000)
    ) axi_m (
        .clk      (clk),
        .rst_n    (rst_n),
        .addr_i   (addr_i),
        .addr_d   (addr_d),
        .wr_data  (mem_wr_data),
        .byte_en  (byte_en_d),
        .wr_en    (mem_wr_en),
        .rd_en_i  (rd_en_i),
        .rd_en_d  (rd_en_d),
        .rd_data_i(rd_data_i),
        .rd_data_d(rd_data_d),
        .stall_I  (stall_I),
        .stall_D  (stall_D),
        .flush_I  (flush_I),
        .m_axi    (m_axi)
    );

endmodule
