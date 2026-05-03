/* verilator lint_off IMPORTSTAR */
import core_pkg::*;
/* verilator lint_on IMPORTSTAR */

module mem (
    input logic clk,
    input logic rst_n,
    input ctrl_signals_t in_ctrl_signals,

    output logic [31:0] mem_addr2,
    output logic        mem_wr_en,
    output logic [31:0] mem_wr_data,
    output logic [ 3:0] mem_byte_en,
    output logic        mem_enable,

    input logic stall_D,
    output ctrl_signals_t out_ctrl_signals
);


    always_comb begin
        mem_addr2   = (in_ctrl_signals.mem_wr_en) ? in_ctrl_signals.mem_wr_addr : in_ctrl_signals.mem_addr2;
        mem_wr_en = in_ctrl_signals.mem_wr_en;
        mem_wr_data = in_ctrl_signals.mem_wr_data;
        mem_byte_en = in_ctrl_signals.mem_byte_en;
        mem_enable = in_ctrl_signals.mem_rd_en;
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            out_ctrl_signals <= 0;
        end else begin
            out_ctrl_signals <= in_ctrl_signals;
            if (mem_enable) begin
                out_ctrl_signals.rf_wr_data_valid <= (!stall_D) ? 1 : 0;
            end
        end
    end


endmodule
