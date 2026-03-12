/* verilator lint_off IMPORTSTAR */
import core_pkg::*;
/* verilator lint_on IMPORTSTAR */

module exec (
    input logic clk,
    input logic rst_n,

    input  ctrl_signals_t in_ctrl_signals,
    output ctrl_signals_t out_ctrl_signals
);


    logic [31:0] alu_op_a;
    logic [31:0] alu_op_b;
    alu_op_t alu_op;
    logic [31:0] alu_result;
    logic alu_zero;
    alu alu_inst (
        .a(alu_op_a),
        .b(alu_op_b),
        .alu_op(alu_op),
        .result(alu_result),
        .zero(alu_zero)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alu_op_a <= 32'b0;
            alu_op_b <= 32'b0;
            alu_op   <= ALU_OFF;
        end else begin
            out_ctrl_signals <= in_ctrl_signals;
            alu_op_a <= in_ctrl_signals.alu_op_a;
            alu_op_b <= in_ctrl_signals.alu_op_b;
            alu_op <= in_ctrl_signals.alu_op;
            case (in_ctrl_signals.rf_writeback)
                ALU_REG: begin
                    out_ctrl_signals.rf_wr_data <= alu_result;
                end
                ALU_MEM_ADDR_WRITE: begin
                    out_ctrl_signals.mem_wr_addr <= alu_result;
                end
                ALU_MEM_ADDR_READ: begin
                    out_ctrl_signals.mem_addr2 <= alu_result;
                end
                ALU_PC_INCR: begin
                    alu_op_a <= in_ctrl_signals.pc;
                    alu_op_b <= 4;
                    out_ctrl_signals.rf_wr_data <= alu_result;
                end
                default: ;
            endcase
        end
    end


endmodule
