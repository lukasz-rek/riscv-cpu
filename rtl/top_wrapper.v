module top_wrapper (
    input  wire clk,
    input  wire rst_n
);

    top #(
        .INIT_FILE("")
    ) top_inst (
        .clk(clk),
        .rst_n(rst_n)
    );

endmodule
