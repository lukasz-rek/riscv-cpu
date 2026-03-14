module top #(
    // parameter INIT_FILE = "/home/luki/Projekty/cpu/code/build/program.hex"
    parameter INIT_FILE = "/home/luki/Projekty/cpu/code/coremark/build/coremark.hex"
) (
    input  logic clk,
    input  logic rst_n,
    output logic uart_tx
);
    localparam UART_ADDR = 32'h000_10000;
    // Memory interface signals
    logic [31:0] mem_addr1;
    logic [31:0] mem_addr2;
    logic        mem_wr_en;
    logic [31:0] mem_wr_data;
    logic [31:0] mem_wr_addr;
    logic [31:0] mem_rd_data1;
    logic [31:0] mem_rd_data2;
    logic [ 3:0] mem_byte_en;

    // Instantiate core
    (* dont_touch = "true" *)
    core cpu (
        .clk(clk),
        .rst_n(rst_n),
        .mem_addr1(mem_addr1),
        .mem_addr2(mem_addr2),
        .mem_wr_en(mem_wr_en),
        .mem_wr_data(mem_wr_data),
        .mem_wr_addr(mem_wr_addr),
        .mem_rd_data1(mem_rd_data1),
        .mem_rd_data2(mem_rd_data2),
        .mem_byte_en(mem_byte_en)
    );

    // Instantiate memory
    logic [31:0] bram_rd_data2;

    (* dont_touch = "true" *) memory #(
        .INIT_FILE(INIT_FILE)
    ) bram_mem (
        .clk(clk),
        .addr1(mem_addr1),
        .addr2(mem_addr2),
        .wr_en(mem_wr_en),
        .wr_data(mem_wr_data),
        .wr_addr(mem_wr_addr),
        .rd_data1(mem_rd_data1),
        .rd_data2(bram_rd_data2),
        .byte_en(mem_byte_en)
    );

    logic fifo_full;
    logic uart_rd_sel;

    // Handle checking if UART is busy
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) uart_rd_sel <= 1'b0;
        else uart_rd_sel <= (mem_addr2 == UART_ADDR);
    end

    assign mem_rd_data2 = uart_rd_sel ? {31'b0, fifo_full} : bram_rd_data2;


    uart_tx #(
        .CLK_FREQ(23_000_000),
        .BAUD(115200)
    ) uart (
        .clk(clk),
        .rst_n(rst_n),
        .data(mem_wr_data[7:0]),
        .tx(uart_tx),
        .uart_en(mem_wr_en),  // this can only trigger if we're writing to MMIO
        .mem_wr_addr(mem_wr_addr),
        .fifo_full(fifo_full)
    );

endmodule
