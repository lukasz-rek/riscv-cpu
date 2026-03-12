/* verilator lint_off IMPORTSTAR */
import core_pkg::*;
/* verilator lint_on IMPORTSTAR */

module decode (
    input logic clk,
    input logic rst_n,

    input logic [31:0] instr_data,
    input logic [31:0] instr_pc,

    // Used to correct IF if we have stalls/flushes
    output logic [31:0] next_pc,
    output logic next_pc_en,

    // Register file stuff
    output logic [ 4:0] rs1_addr,
    output logic [ 4:0] rs2_addr,
    input  logic [31:0] rs1_data,
    input  logic [31:0] rs2_data,

    output ctrl_signals_t ctrl_signals
);

    logic [31:0] instruction;

    logic [ 6:0] opcode;
    logic [ 4:0] rd;
    logic [ 4:0] rs1;
    logic [ 4:0] rs2;
    logic [ 2:0] funct3;
    logic [ 6:0] funct7;
    logic [31:0] imm;


    assign instruction = instr_data;

    // 2nd: Decode
    assign opcode = instruction[6:0];
    assign funct3 = instruction[14:12];
    assign funct7 = instruction[31:25];
    assign rd = instruction[11:7];
    assign rs1 = instruction[19:15];
    assign rs2 = instruction[24:20];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            next_pc <= 32'b0;
            next_pc_en <= 0;
            ctrl_signals <= 0;
        end else begin
            // Control signals defaults
            ctrl_signals.rf_wr_en <= 0;
            ctrl_signals.mem_wr_en <= 0;
            ctrl_signals.alu_op_a <= rs1_data;
            ctrl_signals.pc <= instr_pc;
            ctrl_signals.instr <= instr_data;
            ctrl_signals.rd <= rd;
            rs1_addr <= rs1;
            rs2_addr <= rs2;
            ctrl_signals.alu_op <= ALU_OFF;
            ctrl_signals.rf_writeback <= OFF;
            case (opcode)
                OP_B: begin
                    imm <= {
                        {20{instruction[31]}},
                        instruction[7],
                        instruction[30:25],
                        instruction[11:8],
                        1'b0
                    };
                    ctrl_signals.alu_op_b <= rs2_data;
                    case (funct3)
                        BNE, BEQ: ctrl_signals.alu_op <= ALU_SUB;
                        BLT, BGE: ctrl_signals.alu_op <= ALU_SLT;
                        BLTU, BGEU: ctrl_signals.alu_op <= ALU_SLTU;
                        default: ;
                    endcase
                    // TODO: figure this out in exec
                    // For operations set above, these results mean branching
                    // case (funct3)
                    //     BNE, BLT, BLTU: branch_taken <= !alu_zero;
                    //     BEQ, BGE, BGEU: branch_taken <= alu_zero;
                    //     default: ;
                    // endcase
                    // if (branch_taken <=<= 1'b1) begin
                    //     next_pc <= pc + imm;
                    // end
                end
                OP_J: begin
                    imm <= {
                        {12{instruction[31]}},
                        instruction[19:12],
                        instruction[20],
                        instruction[30:21],
                        1'b0
                    };
                    ctrl_signals.rf_wr_en <= 1;
                    ctrl_signals.alu_op <= ALU_ADD;
                    ctrl_signals.rf_writeback <= ALU_PC_INCR;
                    next_pc <= instr_pc + imm;
                    next_pc_en <= 1;
                end
                OP_S: begin
                    ctrl_signals.mem_wr_en <= 1;
                    imm <= {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
                    ctrl_signals.alu_op <= ALU_ADD;
                    ctrl_signals.alu_op_b <= imm;
                    ctrl_signals.rf_writeback <= ALU_MEM_ADDR_WRITE;
                    case (funct3)
                        3'b000: begin  // SB — replicate byte, shift byte_en to correct lane
                            // ctrl_signals.mem_byte_en <= 4'b0001 << alu_result[1:0];
                            ctrl_signals.mem_wr_data <= {4{rs2_data[7:0]}};
                        end
                        3'b001: begin  // SH — replicate halfword, shift byte_en
                            // ctrl_signals.mem_byte_en <= 4'b0011 << {alu_result[1], 1'b0};
                            ctrl_signals.mem_wr_data <= {2{rs2_data[15:0]}};
                        end
                        3'b010: begin  // SW
                            // ctrl_signals.mem_byte_en <= 4'b1111;
                            ctrl_signals.mem_wr_data <= rs2_data;
                        end
                        default: ;
                    endcase
                end
                OP_R: begin
                    ctrl_signals.alu_op_b <= rs2_data;
                    if (funct7 == 7'b0000001) begin
                        // Handle M extension
                        case (funct3)
                            3'b000:  ctrl_signals.alu_op <= ALU_MUL;
                            3'b001:  ctrl_signals.alu_op <= ALU_MULH;
                            3'b010:  ctrl_signals.alu_op <= ALU_MULHSU;
                            3'b011:  ctrl_signals.alu_op <= ALU_MULHU;
                            3'b100:  ctrl_signals.alu_op <= ALU_DIV;
                            3'b101:  ctrl_signals.alu_op <= ALU_DIVU;
                            3'b110:  ctrl_signals.alu_op <= ALU_REM;
                            3'b111:  ctrl_signals.alu_op <= ALU_REMU;
                            default;
                        endcase
                    end else begin
                        case (funct3)
                            3'b000:
                            ctrl_signals.alu_op <= (funct7 == 7'b0100000) ? ALU_SUB : ALU_ADD;
                            3'b001: ctrl_signals.alu_op <= ALU_SLL;
                            3'b010: ctrl_signals.alu_op <= ALU_SLT;
                            3'b011: ctrl_signals.alu_op <= ALU_SLTU;
                            3'b100: ctrl_signals.alu_op <= ALU_XOR;
                            3'b101:
                            ctrl_signals.alu_op <= (funct7 == 7'b0100000) ? ALU_SRA : ALU_SRL;
                            3'b110: ctrl_signals.alu_op <= ALU_OR;
                            3'b111: ctrl_signals.alu_op <= ALU_AND;
                            default: ;
                        endcase
                    end
                    ctrl_signals.rf_wr_en <= 1;
                    ctrl_signals.rf_writeback <= ALU_REG;
                end
                OP_I_MEM, OP_JALR, OP_I_ALU: begin
                    imm <= {{20{instruction[31]}}, instruction[31:20]};
                    case (opcode)
                        OP_I_MEM: begin
                            ctrl_signals.rf_writeback <= ALU_MEM_ADDR_READ;
                            ctrl_signals.alu_op_b <= imm;
                        end
                        OP_JALR: begin
                            ctrl_signals.rf_wr_en <= 1;
                            ctrl_signals.alu_op <= ALU_ADD;
                            ctrl_signals.rf_writeback <= ALU_PC_INCR;
                            next_pc <= rs1_data + imm;
                            next_pc_en <= 1;
                        end
                        OP_I_ALU: begin
                            ctrl_signals.rf_wr_en <= 1;
                            ctrl_signals.rf_writeback <= ALU_REG;
                            ctrl_signals.alu_op_b <= imm;
                            case (funct3)
                                3'b000:  ctrl_signals.alu_op <= ALU_ADD;
                                3'b010:  ctrl_signals.alu_op <= ALU_SLT;
                                3'b011:  ctrl_signals.alu_op <= ALU_SLTU;
                                3'b100:  ctrl_signals.alu_op <= ALU_XOR;
                                3'b110:  ctrl_signals.alu_op <= ALU_OR;
                                3'b111:  ctrl_signals.alu_op <= ALU_AND;
                                3'b001:  ctrl_signals.alu_op <= ALU_SLL;
                                3'b101: begin
                                    ctrl_signals.alu_op   <= (funct7 == 7'b0100000) ? ALU_SRA : ALU_SRL;
                                    ctrl_signals.alu_op_b <= {27'b0, rs2};  // SHAMT taken directly
                                end
                                default: ;
                            endcase
                        end
                        default: ;
                    endcase
                end
                OP_LUI, OP_AUI: begin
                    imm <= {instruction[31:12], 12'b0};
                    ctrl_signals.rf_wr_en <= 1;
                    ctrl_signals.rf_wr_data <= (opcode == OP_LUI) ? imm : imm + instr_pc;
                end
                OP_SYSTEM: begin
                    if (funct3 == 3'b010 && rs1_data == 32'b0) begin
                        ctrl_signals.rf_wr_en <= 1;
                        // ctrl_signals.rf_wr_data <= cycle_count;
                    end
                end
                default: ;
            endcase
        end
    end

endmodule
