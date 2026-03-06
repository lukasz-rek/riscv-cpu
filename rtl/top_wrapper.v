module top_wrapper (
    input  wire clk,
    input  wire rst_n,
    output wire uart_tx
);

    top top_inst (
        .clk(clk),
        .rst_n(1'b1),
        .uart_tx(uart_tx)
    );

endmodule
