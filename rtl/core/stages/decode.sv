/* verilator lint_off IMPORTSTAR */
import core_pkg::*;
/* verilator lint_on IMPORTSTAR */

module decode (
    input logic clk,
    input logic rst_n,

    input logic [31:0] instr_data,
    input logic [31:0] instr_pc,
    input logic valid,
    // Used to correct IF if we have stalls/flushes
    output logic [31:0] next_pc,
    output logic next_pc_en,

    output logic [4:0] rs1_addr,
    input logic [31:0] rs1_data,
    // Flushing
    /* verilator lint_off UNUSEDSIGNAL */
    input logic flush,
    input logic [31:0] flush_pc,

    // Sometimes exec might force delays due to multi-cycle instr
    input logic exec_stall,
    input logic stall_I,
    input logic stall_D,
    /* verilator lint_on UNUSEDSIGNAL */
    output ctrl_signals_t ctrl_signals,
    output logic freeze
);

    logic [31:0] instruction;

    logic [6:0] opcode;
    logic [4:0] rd;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [31:0] imm;

    logic [31:0] cycle_count;
    logic [31:0] instr_count;

    // Used for comibnational stuff and clocked once later
    ctrl_signals_t temp_signals;

    // Keep track of data hazards, only use after load
    // logic [4:0] rd_buffer;
    // logic [4:0] rd_buffer_2;  // 2nd cycle tracking for JALR-after-load


    assign instruction = instr_data;

    // 2nd: Decode
    assign opcode = instruction[6:0];
    assign funct3 = instruction[14:12];
    assign funct7 = instruction[31:25];
    assign rd = instruction[11:7];
    assign rs1 = instruction[19:15];
    assign rs2 = instruction[24:20];

    // logic data_hazard;
    // assign data_hazard = (rs1 != 0 && rd_buffer == rs1) || (rs2 != 0 && rd_buffer == rs2);

    // JALR reads rs1 in decode — needs load data available in WB, not mem
    // logic jalr_load_hazard;
    // assign jalr_load_hazard = (opcode == OP_JALR) && (rs1 != 0) && (rd_buffer_2 == rs1);

    logic [1:0] state_counter_q;
    logic flush_latch_q;
    logic [31:0] flush_pc_q;

    // First actually decode the signals
    always_comb begin
        rs1_addr = rs1;
        next_pc_en = 0;
        imm = '0;
        next_pc = '0;
        temp_signals = 0;
        freeze = '0;

        if (valid && flush_latch_q) begin
            // If we're on valid instruction (no in progress I miss)
            next_pc_en = 1;
            next_pc = flush_pc_q;

        end else if (exec_stall) begin
            temp_signals = ctrl_signals;
            next_pc_en = 1;
            next_pc = instr_pc;
        end else if (state_counter_q != 2'b00) begin
            // We have no op
            temp_signals = '0;
            next_pc_en = 1;
            next_pc = instr_pc;
            // Check if we gotta stall
            // if (!valid) begin
            //     temp_signals = '0;
        end else if (stall_D) begin
            temp_signals = ctrl_signals;
            next_pc_en = 1;
            next_pc = instr_pc;
            freeze = 1;
        end else begin
            // end else if (data_hazard || jalr_load_hazard) begin
            //     temp_signals = '0;
            //     next_pc_en = (rst_n) ? '1 : '0;
            //     next_pc = instr_pc;
            // end else if (exec_stall) begin
            //     temp_signals = ctrl_signals;  // We want to keep same instruction
            //     next_pc_en = 1;
            //     next_pc = instr_pc;
            // end else begin
            //     temp_signals = '0;

            // $write("PC: %h, INSTR: %h\n", instr_pc, instr_data);

            temp_signals.pc = instr_pc;
            temp_signals.instr = instr_data;

            temp_signals.rs1 = rs1;
            temp_signals.rs2 = rs2;
            temp_signals.opcode = opcode;

            temp_signals.rd = rd;



            case (opcode)
                OP_B: begin
                    imm = {
                        {20{instruction[31]}},
                        instruction[7],
                        instruction[30:25],
                        instruction[11:8],
                        1'b0
                    };
                    temp_signals.rs2_src = REG;
                    temp_signals.branch_instr = 1;
                    case (funct3)
                        BNE, BEQ: temp_signals.alu_op = ALU_SUB;
                        BLT, BGE: temp_signals.alu_op = ALU_SLT;
                        BLTU, BGEU: temp_signals.alu_op = ALU_SLTU;
                        default: ;
                    endcase
                    // We always assume branch gets taken, unless we have a latched flush
                    next_pc = instr_pc + imm;
                    next_pc_en = 1;

                    case (funct3)
                        BNE, BLT, BLTU: temp_signals.branch_expects_zero = 0;
                        BEQ, BGE, BGEU: temp_signals.branch_expects_zero = 1;
                        default: ;
                    endcase
                end
                OP_J: begin
                    imm = {
                        {12{instruction[31]}},
                        instruction[19:12],
                        instruction[20],
                        instruction[30:21],
                        1'b0
                    };
                    temp_signals.rf_wr_en = 1;
                    temp_signals.alu_op = ALU_ADD;
                    temp_signals.rf_writeback = ALU_PC_INCR;
                    next_pc = instr_pc + imm;
                    next_pc_en = 1;
                end
                OP_S: begin
                    temp_signals.mem_wr_en = 1;
                    imm = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
                    temp_signals.alu_op = ALU_ADD;
                    temp_signals.rs2_src = IMM;

                    case (funct3)
                        3'b000: begin  // SB — replicate byte, shift byte_en to correct lane
                            temp_signals.rf_writeback = ALU_MEM_ADDR_WRITE_B;
                        end
                        3'b001: begin  // SH — replicate halfword, shift byte_en
                            temp_signals.rf_writeback = ALU_MEM_ADDR_WRITE_H;
                        end
                        3'b010: begin  // SW
                            temp_signals.rf_writeback = ALU_MEM_ADDR_WRITE_W;

                        end
                        default: ;
                    endcase
                end
                OP_R: begin
                    temp_signals.rs2_src = REG;
                    if (funct7 == 7'b0000001) begin
                        // Handle M extension
                        case (funct3)
                            3'b000:  temp_signals.alu_op = ALU_MUL;
                            3'b001:  temp_signals.alu_op = ALU_MULH;
                            3'b010:  temp_signals.alu_op = ALU_MULHSU;
                            3'b011:  temp_signals.alu_op = ALU_MULHU;
                            3'b100:  temp_signals.alu_op = ALU_DIV;
                            3'b101:  temp_signals.alu_op = ALU_DIVU;
                            3'b110:  temp_signals.alu_op = ALU_REM;
                            3'b111:  temp_signals.alu_op = ALU_REMU;
                            default;
                        endcase
                    end else begin
                        case (funct3)
                            3'b000:
                            temp_signals.alu_op = (funct7 == 7'b0100000) ? ALU_SUB : ALU_ADD;
                            3'b001: temp_signals.alu_op = ALU_SLL;
                            3'b010: temp_signals.alu_op = ALU_SLT;
                            3'b011: temp_signals.alu_op = ALU_SLTU;
                            3'b100: temp_signals.alu_op = ALU_XOR;
                            3'b101:
                            temp_signals.alu_op = (funct7 == 7'b0100000) ? ALU_SRA : ALU_SRL;
                            3'b110: temp_signals.alu_op = ALU_OR;
                            3'b111: temp_signals.alu_op = ALU_AND;
                            default: ;
                        endcase
                    end
                    temp_signals.rf_wr_en = 1;
                    temp_signals.rf_writeback = ALU_REG;
                end
                OP_I_MEM, OP_JALR, OP_I_ALU: begin
                    imm = {{20{instruction[31]}}, instruction[31:20]};
                    temp_signals.rf_wr_en = 1;

                    case (opcode)
                        OP_I_MEM: begin
                            temp_signals.alu_op = ALU_ADD;
                            temp_signals.rf_writeback = ALU_MEM_ADDR_READ;
                            temp_signals.mem_rd_en = 1;
                            temp_signals.rs2_src = IMM;
                            // Rf writeback needs to shift by addr[1:0]
                            case (funct3)
                                3'b000:  temp_signals.load_mask = LB;  // LB
                                3'b001:  temp_signals.load_mask = LH;  // LH
                                3'b010:  temp_signals.load_mask = LW;  // LW
                                3'b100:  temp_signals.load_mask = LBU;  // LBU
                                3'b101:  temp_signals.load_mask = LHU;  // LHU
                                default: ;
                            endcase
                        end
                        OP_JALR: begin
                            temp_signals.alu_op = ALU_ADD;
                            temp_signals.rf_writeback = ALU_PC_INCR;
                            // TODO: handle this at the end
                            // Force lsb 0 for alignment
                            next_pc = (rs1_data + imm) & ~32'b1;
                            next_pc_en = 1;
                        end
                        OP_I_ALU: begin
                            temp_signals.rf_writeback = ALU_REG;
                            temp_signals.rs2_src = IMM;
                            case (funct3)
                                3'b000:  temp_signals.alu_op = ALU_ADD;
                                3'b010:  temp_signals.alu_op = ALU_SLT;
                                3'b011:  temp_signals.alu_op = ALU_SLTU;
                                3'b100:  temp_signals.alu_op = ALU_XOR;
                                3'b110:  temp_signals.alu_op = ALU_OR;
                                3'b111:  temp_signals.alu_op = ALU_AND;
                                3'b001:  temp_signals.alu_op = ALU_SLL;
                                3'b101: begin
                                    temp_signals.alu_op   = (funct7 == 7'b0100000) ? ALU_SRA : ALU_SRL;
                                    temp_signals.rs2_src = SHAMT;
                                end
                                default: ;
                            endcase
                        end
                        default: ;
                    endcase
                end
                OP_LUI, OP_AUI: begin
                    imm = {instruction[31:12], 12'b0};
                    temp_signals.rf_wr_en = 1;
                    temp_signals.rf_wr_data = (opcode == OP_LUI) ? imm : imm + instr_pc;
                end
                OP_SYSTEM: begin
                    if (funct3 == 3'b010 && rs1_data == 32'b0) begin
                        temp_signals.rf_wr_en   = 1;
                        temp_signals.rf_wr_data = cycle_count;
                    end
                end
                default: ;
            endcase
            temp_signals.imm = imm;
        end
    end


    // Save the outputs for next stage


    always_ff @(posedge clk) begin
        if (!rst_n) begin
            ctrl_signals <= '0;
            cycle_count <= '0;
            instr_count <= '0;
            // rd_buffer    <= '0;
            // rd_buffer_2  <= '0;
            state_counter_q <= '0;
            flush_latch_q <= 0;
            flush_pc_q <= '0;
        end else begin

            state_counter_q <= (valid && !exec_stall && !stall_D) ? state_counter_q + 2'd1 : state_counter_q;

            // If flush asserted, save latch values
            if (flush) begin
                flush_latch_q <= 1;
                flush_pc_q <= flush_pc + 4;
            end else if ((instr_pc == flush_pc_q) && valid) begin
                // Possibly clear flush_latch if we got requested address as valid isntr
                flush_latch_q <= 0;
            end

            // Propagate rd buffer values
            ctrl_signals <= temp_signals;
            // rd_buffer <= (!data_hazard && !jalr_load_hazard && temp_signals.rf_writeback == ALU_MEM_ADDR_READ && !flush) ? rd : '0;
            // rd_buffer_2 <= rd_buffer;
            cycle_count  <= cycle_count + 1;
            // Handle instruction counting
            if (flush) begin
                instr_count <= instr_count - 1;
                // end else if (data_hazard || jalr_load_hazard || exec_stall) begin
            end else if (exec_stall) begin
                instr_count <= instr_count;
            end else begin
                instr_count <= instr_count + 1;
            end
        end
    end

endmodule
