/* verilator lint_off IMPORTSTAR */
import core_pkg::*;
/* verilator lint_on IMPORTSTAR */

module exec (
    input logic clk,
    input logic rst_n,

    input  ctrl_signals_t in_ctrl_signals,
    output ctrl_signals_t out_ctrl_signals,

    // output ctrl_signals_t forward_result,

    // Register file stuff
    output logic [ 4:0] rs1_addr,
    output logic [ 4:0] rs2_addr,
    input  logic [31:0] rs1_data,
    input  logic [31:0] rs2_data,

    input logic freeze,
    input logic stall_D,

    output logic flush,
    output logic exec_stall,
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

    logic div_result_en;
    logic [31:0] div_alu_result;
    logic alu_div_active;
    division_alu division_alu (
        .clk  (clk),
        .rst_n(rst_n),

        .a(alu_op_a),
        .b(alu_op_b),
        .alu_op(alu_op),
        .result(div_alu_result),
        .result_en(div_result_en)
    );

    ctrl_signals_t temp_signals;
    // assign forward_result = temp_signals;

    assign rs1_addr = in_ctrl_signals.rs1;
    assign rs2_addr = in_ctrl_signals.rs2;

    assign alu_div_active = (alu_op == ALU_DIV || alu_op == ALU_DIVU || alu_op == ALU_REM || alu_op == ALU_REMU);


    always_comb begin
        // Assign correct operands
        alu_op_a = rs1_data;
        alu_op_b = '0;

        case (in_ctrl_signals.rs2_src)
            REG: alu_op_b = rs2_data;
            IMM: alu_op_b = in_ctrl_signals.imm;
            SHAMT: alu_op_b = {27'b0, rs2_addr};
            default: ;
        endcase

        alu_op = in_ctrl_signals.alu_op;
        flush = 0;
        flush_pc = '0;
        exec_stall = '0;

        temp_signals = in_ctrl_signals;
        case (in_ctrl_signals.rf_writeback)
            ALU_REG: begin
                temp_signals.rf_wr_data = alu_result;
            end
            ALU_MEM_ADDR_WRITE_B, ALU_MEM_ADDR_WRITE_H, ALU_MEM_ADDR_WRITE_W: begin
                temp_signals.mem_wr_addr = alu_result;
                if (in_ctrl_signals.rf_writeback == ALU_MEM_ADDR_WRITE_B) begin
                    temp_signals.mem_byte_en = 4'b0001 << alu_result[1:0];
                    temp_signals.mem_wr_data = {4{rs2_data[7:0]}};
                end else if (in_ctrl_signals.rf_writeback == ALU_MEM_ADDR_WRITE_H) begin
                    temp_signals.mem_byte_en = 4'b0011 << {alu_result[1], 1'b0};
                    temp_signals.mem_wr_data = {2{rs2_data[15:0]}};
                end else begin
                    temp_signals.mem_wr_data = rs2_data;
                    temp_signals.mem_byte_en = 4'b1111;
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

        // Handle exec stalls
        if (alu_div_active && !div_result_en) begin
            exec_stall   = 1;
            temp_signals = '0;
        end else if (alu_div_active && div_result_en) begin
            // We have a result from division, so we can move forward
            temp_signals.rf_wr_data = div_alu_result;
        end

    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            out_ctrl_signals <= 0;
        end else begin
            if (stall_D) begin
                out_ctrl_signals <= out_ctrl_signals;
            end else if (freeze) begin
                out_ctrl_signals <= '0;
            end else begin
                out_ctrl_signals <= temp_signals;
            end
        end
    end


endmodule
