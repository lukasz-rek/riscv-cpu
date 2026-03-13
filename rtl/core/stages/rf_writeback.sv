/* verilator lint_off IMPORTSTAR */
import core_pkg::*;
/* verilator lint_on IMPORTSTAR */

module rf_writeback (
    output logic rf_wr_en,
    output logic [4:0] wr_addr,
    output logic [31:0] wr_data,
    /* verilator lint_off UNUSEDSIGNAL */
    input ctrl_signals_t in_ctrl_signals
    /* verilator lint_on UNUSEDSIGNAL */
);

    assign rf_wr_en = in_ctrl_signals.rf_wr_en;
    assign wr_data  = in_ctrl_signals.rf_wr_data;
    assign wr_addr  = in_ctrl_signals.rd;




endmodule
