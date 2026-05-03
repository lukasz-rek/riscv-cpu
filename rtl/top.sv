
module top #(
    // parameter INIT_FILE = "code/build/program.hex"
    // parameter INIT_FILE = "code/coremark/build/coremark.hex"
) (
    input logic clk,
    input logic rst_n,

    axi_if.master m_axi,
    output logic uart_tx
);


    // UART
    localparam UART_ADDR = 32'h0001_0000;
    logic fifo_full;
    logic uart_rd_sel;

    // Memory signals
    logic [31:0] addr_d;
    logic [31:0] addr_i;

    logic [31:0] mem_wr_data;

    logic mem_wr_en;
    logic rd_en_d;
    logic rd_en_d_sel;  // Needed for MMIO
    logic rd_en_i;
    logic [3:0] byte_en_d;

    logic [31:0] mem_rd_data_d;  // Needed for MMIO

    logic [31:0] rd_data_d;

    logic [31:0] rd_data_i;
    logic stall_D;
    logic stall_I;

    always_ff @(posedge clk) begin
        if (!rst_n) uart_rd_sel <= 1'b0;
        else uart_rd_sel <= (addr_d == UART_ADDR);
    end

    core cpu (
        .clk(clk),
        .rst_n(rst_n),
        .mem_addr1(addr_i),
        .mem_addr2(addr_d),
        .mem_wr_en(mem_wr_en),
        .mem_wr_data(mem_wr_data),
        .mem_rd_data1(rd_data_i),
        .mem_rd_data2(mem_rd_data_d),
        .mem_byte_en(byte_en_d),
        .stall_I(stall_I),
        .stall_D(stall_D),
        .rd_en_d(rd_en_d),
        .rd_en_i(rd_en_i)
    );

    assign rd_en_d_sel   = (addr_d == UART_ADDR) ? 0 : rd_en_d;
    assign mem_rd_data_d = uart_rd_sel ? {31'b0, fifo_full} : rd_data_d;

    logic axi_wr_en;

    assign axi_wr_en = (addr_d == UART_ADDR) ? 0 : mem_wr_en;

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
        .wr_en    (axi_wr_en),
        .rd_en_i  (rd_en_i),
        .rd_en_d  (rd_en_d_sel),
        .rd_data_i(rd_data_i),
        .rd_data_d(rd_data_d),
        .stall_I  (stall_I),
        .stall_D  (stall_D),
        .m_axi    (m_axi)
    );

    uart_tx #(
        .CLK_FREQ(80_000_000),
        .BAUD(115200)
    ) uart (
        .clk(clk),
        .rst_n(rst_n),
        .data(mem_wr_data[7:0]),
        .tx(uart_tx),
        .uart_en(mem_wr_en),  // this can only trigger if we're writing to MMIO
        .mem_wr_addr(addr_d),
        .fifo_almost_full(fifo_full)
    );

endmodule
