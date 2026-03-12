/* verilator lint_off IMPORTSTAR */
import core_pkg::*;
/* verilator lint_on IMPORTSTAR */

module rf_writeback (
    input logic clk,
    input logic rst_n,

    output logic rf_wr_en,
    output logic [4:0] wr_addr,
    output logic [31:0] wr_data,
    /* verilator lint_off UNUSEDSIGNAL */
    input ctrl_signals_t in_ctrl_signals
    /* verilator lint_on UNUSEDSIGNAL */
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rf_wr_en <= 0;
            wr_addr  <= 5'b0;
            wr_data  <= 32'b0;
        end else begin
            rf_wr_en <= in_ctrl_signals.rf_wr_en;
            wr_data  <= in_ctrl_signals.rf_wr_data;
            wr_addr  <= in_ctrl_signals.rd;
        end
    end


endmodule
