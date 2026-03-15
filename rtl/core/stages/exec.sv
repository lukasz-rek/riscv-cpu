/* verilator lint_off IMPORTSTAR */
import core_pkg::*;
/* verilator lint_on IMPORTSTAR */

module exec (
    input logic clk,
    input logic rst_n,

    input  ctrl_signals_t in_ctrl_signals,
    output ctrl_signals_t out_ctrl_signals,

    output ctrl_signals_t forward_result,

    /* verilator lint_off UNUSEDSIGNAL */
    input ctrl_signals_t rf_forward_signals,
    /* verilator lint_on UNUSEDSIGNAL */

    output logic flush,
    output logic [31:0] flush_pc
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

    ctrl_signals_t temp_signals;
    assign forward_result = temp_signals;

    always_comb begin
        alu_op_a = in_ctrl_signals.alu_op_a;
        alu_op_b = in_ctrl_signals.alu_op_b;
        alu_op = in_ctrl_signals.alu_op;
        flush = 0;
        flush_pc = '0;

        temp_signals = in_ctrl_signals;
        case (in_ctrl_signals.rf_writeback)
            ALU_REG: begin
                temp_signals.rf_wr_data = alu_result;
            end
            ALU_MEM_ADDR_WRITE_B, ALU_MEM_ADDR_WRITE_H, ALU_MEM_ADDR_WRITE_W: begin
                temp_signals.mem_wr_addr = alu_result;
                if (in_ctrl_signals.rf_writeback == ALU_MEM_ADDR_WRITE_B) begin
                    temp_signals.mem_byte_en = 4'b0001 << alu_result[1:0];
                end else if (in_ctrl_signals.rf_writeback == ALU_MEM_ADDR_WRITE_H) begin
                    temp_signals.mem_byte_en = 4'b0011 << {alu_result[1], 1'b0};
                end
            end
            ALU_MEM_ADDR_READ: begin
                temp_signals.mem_addr2 = alu_result;
            end
            ALU_PC_INCR: begin
                alu_op_a = in_ctrl_signals.pc;
                alu_op_b = 4;
                temp_signals.rf_wr_data = alu_result;
            end
            default: ;
        endcase

        // Handle possible flush
        if (alu_zero != in_ctrl_signals.branch_expects_zero && in_ctrl_signals.branch_instr) begin
            // We done goofed up, we need to fluuuuuuuuuuuuuuuush
            flush = 1;
            flush_pc = in_ctrl_signals.pc;
            temp_signals = '0;  // Insert no ops later
        end

    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_ctrl_signals <= 0;
        end else begin
            out_ctrl_signals <= temp_signals;
        end
    end


endmodule
