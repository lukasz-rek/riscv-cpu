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

    output logic minstret_incr,

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
    output logic freeze,

    // Trap handling
    // output logic trap_en,
    // output isr_cause_t trap_cause,
    // output logic [31:0] trap_pc,
    // output logic [31:0] trap_val,
    // output logic mret_en,

    input logic trap_taken,
    input logic [31:0] trap_target,
    input logic trap_pending
);

    logic [31:0] instruction;

    logic [6:0] opcode;
    logic [4:0] rd;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [31:0] imm;
    logic [11:0] funct12;

    // Used for comibnational stuff and clocked once later
    ctrl_signals_t temp_signals;

    assign instruction = instr_data;

    // 2nd: Decode
    assign opcode = instruction[6:0];
    assign funct3 = instruction[14:12];
    assign funct7 = instruction[31:25];
    assign rd = instruction[11:7];
    assign rs1 = instruction[19:15];
    assign rs2 = instruction[24:20];
    assign funct12 = instruction[31:20];

    logic flush_latch_q;
    logic [31:0] flush_pc_q;
    logic trap_service;

    // First actually decode the signals
    always_comb begin
        next_pc_en = 0;
        imm = '0;
        next_pc = '0;
        temp_signals = 0;
        freeze = '0;
        minstret_incr = 0;
        trap_service = 0;
        if (!valid) begin

        end else if (flush_latch_q) begin
            // If we're on valid instruction (no in progress I miss)
            next_pc_en = 1;
            next_pc = flush_pc_q;
        end else if (trap_taken) begin
            next_pc_en = 1;
            next_pc = trap_target;
            trap_service = 1;
        end else if (exec_stall) begin
            next_pc_en = 1;
            next_pc = instr_pc;
        end else if (stall_D) begin
            next_pc_en = 1;
            next_pc = instr_pc;
            freeze = 1;

        end else begin

            temp_signals.pc = instr_pc;
            temp_signals.instr = instr_data;

            temp_signals.rs1 = rs1;
            temp_signals.rs2 = rs2;
            temp_signals.opcode = opcode;


            temp_signals.rd = rd;
            // $write("PC: %h, INSTR: %h\n", instr_pc, instr_data);
            minstret_incr = 1;

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
                    temp_signals.rs2_src = IMM;

                    case (opcode)
                        OP_I_MEM: begin
                            temp_signals.alu_op = ALU_ADD;
                            temp_signals.rf_writeback = ALU_MEM_ADDR_READ;
                            temp_signals.mem_rd_en = 1;
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

                            temp_signals.rf_writeback = ALU_JALR;

                            // Already set what we're goind to store in register_file
                            temp_signals.rf_wr_data = instr_pc + 4;
                            temp_signals.rf_wr_data_valid = 1;

                        end
                        OP_I_ALU: begin
                            temp_signals.rf_writeback = ALU_REG;
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
                    temp_signals.rf_wr_data_valid = 1;
                end
                OP_SYSTEM: begin
                    if (funct3 != '0) begin
                        temp_signals.rf_wr_en = 1;
                        temp_signals.rf_writeback = ALU_CSR;
                        temp_signals.csr_addr = instruction[31:20];
                        temp_signals.csr_wr_en = 1;
                        temp_signals.csr_rd_en = 1;

                        // Always perform cast, if wrong value, catch in following switch/case
                        temp_signals.csr_type = csr_type_t'(funct3);
                        imm = {27'b0, rs1};
                        case (funct3)
                            CSRRW, CSRRWI: begin
                                temp_signals.csr_op = CSR_RW;
                            end
                            CSRRS, CSRRSI: begin
                                temp_signals.csr_op = CSR_SET;
                            end
                            CSRRC, CSRRCI: begin
                                temp_signals.csr_op = CSR_CLEAR;
                            end
                            default: ;
                        endcase
                        // Decide imm
                        case (funct3)
                            CSRRW, CSRRS, CSRRC: temp_signals.csr_imm = 0;
                            CSRRWI, CSRRSI, CSRRCI: temp_signals.csr_imm = 1;
                            default: ;
                        endcase
                        if (temp_signals.csr_op == CSR_RW && rd == '0) begin
                            temp_signals.csr_rd_en = 0;
                        end else if (((temp_signals.csr_op == CSR_SET) || (temp_signals.csr_op == CSR_CLEAR)) &&
                        (rs1 == '0) ) begin
                            temp_signals.csr_wr_en = 0;
                        end
                    end else begin
                        case (funct12)
                            12'd0: begin
                                temp_signals.trap_en = 1;
                                temp_signals.trap_cause = M_CALL;
                            end
                            12'd1: begin
                                temp_signals.trap_en = 1;
                                temp_signals.trap_cause = BREAKPOINT;
                            end
                            12'b001100000010: temp_signals.mret_en = 1;
                            default: ;
                        endcase
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
            flush_latch_q <= 0;
            flush_pc_q <= '0;
        end else begin

            // If flush asserted, save latch values
            if (flush) begin
                flush_latch_q <= 1;
                flush_pc_q <= flush_pc;
            end else if ((instr_pc == flush_pc_q) && valid) begin
                // Possibly clear flush_latch if we got requested address as valid isntr
                flush_latch_q <= 0;
            end

            if (trap_taken && trap_service) begin
                ctrl_signals <= '0;
            end else if (exec_stall || stall_D) begin
                ctrl_signals <= ctrl_signals;
            end else if (!valid || flush || flush_latch_q) begin
                ctrl_signals <= '0;
            end else begin
                // We get a new instruction

                ctrl_signals <= temp_signals;
            end

        end
    end

endmodule
