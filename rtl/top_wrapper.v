module top_wrapper (
    input  wire clk,
    input  wire rst_n,
    output wire uart_tx
);

    top #(
        .INIT_FILE("")
    ) top_inst (
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx(uart_tx)
    );

endmodule
