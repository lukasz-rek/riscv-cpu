
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
    localparam UART_ADDR = 32'h000_10000;
    logic [7 : 0] out_data;
    logic uart_en;
    logic fifo_full;


    // Memory signals
    logic [31:0] addr_d;
    logic [31:0] wr_addr;
    logic [31:0] wr_data;
    logic wr_en;
    logic rd_en_d;
    logic [31:0] rd_data_d;
    logic [31:0] rd_data_i;
    logic stall_D;
    logic stall_I;




    axi_master #(
        .ADDR_WIDTH (32),
        .DATA_WIDTH (32),
        .START_ADDR (36'h8_4000_0000)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .addr_i    (32'h0),
        .addr_d    (addr_d),
        .wr_addr   (wr_addr),
        .wr_data   (wr_data),
        .byte_en   (4'hF),
        .wr_en     (wr_en),
        .rd_en_i   (1'b0),
        .rd_en_d   (rd_en_d),
        .rd_data_i (rd_data_i),
        .rd_data_d (rd_data_d),
        .stall_I   (stall_I),
        .stall_D   (stall_D),
        .m_axi     (m_axi)
    );

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            addr_d <= '0;
            rd_en_d <= '1;
        end else begin
            uart_en <= 0;
            if (!stall_D && !fifo_full) begin
                uart_en <= 1;
                out_data <= rd_data_d[7:0];
            end
        end
    end


    uart_tx #(
        .CLK_FREQ(58_000_000),
        .BAUD(115200)
    ) uart (
        .clk(clk),
        .rst_n(rst_n),
        .data(out_data),
        .tx(uart_tx),
        .uart_en(uart_en),  // this can only trigger if we're writing to MMIO
        .mem_wr_addr(UART_ADDR),
        .fifo_full(fifo_full)
    );

endmodule
