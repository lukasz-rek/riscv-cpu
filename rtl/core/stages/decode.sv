/* verilator lint_off IMPORTSTAR */
import core_pkg::*;
/* verilator lint_on IMPORTSTAR */

typedef enum logic [2:0] {
    AMO_OFF,
    AMO_LOAD_TO_HIDDEN,
    AMO_HOLD_RD,
    AMO_OP,
    AMO_STORE,
    AMO_MOVE_RD
} amo_state_t;


module decode (
    input logic clk,
    input logic rst_n,

    input logic [31:0] instr_data,
    (* MARK_DEBUG = "TRUE" *) input logic [31:0] instr_pc,
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

    input logic trap_stall,
    input logic trap_taken,
    input logic [31:0] trap_target,
    input logic isr_pending,

    output logic isr_en,
    output logic [31:0] isr_pc,
    output logic trap_service  // Indicates to exec to clear reservation
);

    (* MARK_DEBUG = "TRUE" *) logic [31:0] instruction;

    logic [6:0] opcode;
    logic [5:0] rd;
    logic [5:0] rs1;
    logic [5:0] rs2;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [31:0] imm;
    logic [11:0] funct12;
    logic [4:0] funct5;

    // Used for comibnational stuff and clocked once later
    ctrl_signals_t temp_signals;

    assign instruction = instr_data;

    // 2nd: Decode
    assign opcode = instruction[6:0];
    assign funct3 = instruction[14:12];
    assign funct7 = instruction[31:25];
    assign rd = {1'b0, instruction[11:7]};
    assign rs1 = {1'b0, instruction[19:15]};
    assign rs2 = {1'b0, instruction[24:20]};
    assign funct12 = instruction[31:20];
    assign funct5 = instruction[31:27];

    logic flush_latch_q;
    logic [31:0] flush_pc_q;

    amo_state_t amo_state_q;
    amo_state_t amo_state;


    // If handling falls through, make it illegal
    function automatic void illegal_instr(ref ctrl_signals_t s);
        s.trap_en    = 1'b1;
        s.trap_cause = ILLEGAL_INSTR;
        s.rf_wr_en   = 1'b0;
    endfunction

    // First actually decode the signals
    always_comb begin
        next_pc_en = 0;
        imm = '0;
        next_pc = '0;
        temp_signals = 0;
        freeze = '0;
        minstret_incr = 0;
        trap_service = 0;
        isr_en = 0;
        isr_pc = '0;
        amo_state = amo_state_q;


        // Without this, it sees circular logc in isr_pc changing in case of a trap
        if (isr_pending && valid && !exec_stall && !stall_D && !flush_latch_q && amo_state_q == AMO_OFF) begin
            isr_en = 1;
            isr_pc = (flush) ? flush_pc : instr_pc;
        end

        if (!valid) begin

        end else if (flush_latch_q) begin
            // If we're on valid instruction (no in progress I miss)
            next_pc_en = 1;
            next_pc = flush_pc_q;
        end else if (exec_stall) begin
            next_pc_en = 1;
            next_pc = instr_pc;
        end else if (stall_D) begin
            next_pc_en = 1;
            next_pc = instr_pc;
            freeze = 1;
        end else if (trap_taken || isr_en) begin

            next_pc_en = 1;
            next_pc = trap_target;
            trap_service = 1;
        end else begin

            temp_signals.pc = instr_pc;
            temp_signals.instr = instr_data;

            temp_signals.rs1 = rs1;
            temp_signals.rs2 = rs2;
            temp_signals.opcode = opcode;
            temp_signals.log_valid = 1;

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
                        default: illegal_instr(temp_signals);
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
                    if (next_pc[1:0] != 2'b00) begin
                        temp_signals.rf_wr_en = 0;
                        temp_signals.trap_en = 1;
                        temp_signals.trap_cause = INSTR_ADDR_MALIGN;
                        temp_signals.trap_val = next_pc;
                    end else next_pc_en = 1;
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
                        default: illegal_instr(temp_signals);
                    endcase
                end
                OP_R: begin
                    temp_signals.rs2_src = REG;
                    if (funct7 == 7'b0000001) begin
                        // Handle M extension
                        case (funct3)
                            3'b000: temp_signals.alu_op = ALU_MUL;
                            3'b001: temp_signals.alu_op = ALU_MULH;
                            3'b010: temp_signals.alu_op = ALU_MULHSU;
                            3'b011: temp_signals.alu_op = ALU_MULHU;
                            3'b100: temp_signals.alu_op = ALU_DIV;
                            3'b101: temp_signals.alu_op = ALU_DIVU;
                            3'b110: temp_signals.alu_op = ALU_REM;
                            3'b111: temp_signals.alu_op = ALU_REMU;
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
                                default: illegal_instr(temp_signals);
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
                                default: illegal_instr(temp_signals);
                            endcase
                        end
                        default: illegal_instr(temp_signals);
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
                        imm = {26'b0, rs1};
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
                            default: illegal_instr(temp_signals);
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
                            12'b000100000101: ;  // wfi is nop :/ sadge
                            default: illegal_instr(temp_signals);
                        endcase
                    end
                end
                OP_MISC_MEM: begin
                    if (funct3 == 3'b000) begin
                        // No-op, single hart so no care for cache-D coherency
                    end else if (funct3 == 3'b001) begin
                        // Initiate write-back of D cache dirty, invalidate all I
                        temp_signals.flush_I = 1'b1;
                    end else illegal_instr(temp_signals);
                end
                OP_AMO: begin
                    if (funct3 != 3'b010) begin

                    end else begin
                        case (funct5)
                            5'b00010: begin
                                // Conditional Load
                                temp_signals.alu_op = ALU_OFF;
                                temp_signals.rf_writeback = ALU_MEM_ADDR_READ;
                                temp_signals.mem_rd_en = 1;
                                temp_signals.rf_wr_en = 1;
                                temp_signals.load_mask = LW;
                                temp_signals.reservation_type = RESERVATION_LOAD;
                            end
                            5'b00011: begin
                                // Conditional Store
                                temp_signals.alu_op = ALU_OFF;
                                temp_signals.rf_writeback = ALU_MEM_ADDR_WRITE_W;
                                // Don't set mem wr en just yet, only after reservation confirmed in exec
                                temp_signals.rf_wr_en = 1;
                                temp_signals.reservation_type = RESERVATION_STORE;
                                temp_signals.rf_wr_data_valid = 1;
                            end
                            5'b00001, 5'b00000, 5'b01100, 5'b01000, 5'b00100,
                            5'b10100, 5'b11100, 5'b10000, 5'b11000: begin // Begin processing of atomic ops
                                next_pc_en = 1;
                                next_pc = instr_pc;  // Just hold the AMO until we're done
                                case (amo_state_q)
                                    AMO_OFF: begin
                                        amo_state = AMO_LOAD_TO_HIDDEN; // Start a load into special reg
                                        temp_signals.alu_op = ALU_ADD;
                                        temp_signals.rf_writeback = ALU_MEM_ADDR_READ;
                                        temp_signals.mem_rd_en = 1;
                                        temp_signals.rf_wr_en = 1;
                                        temp_signals.load_mask = LW;
                                        temp_signals.rs2_src = IMM;
                                        temp_signals.rd = 6'd32;  // First load into special reg
                                        imm = '0;
                                    end
                                    AMO_LOAD_TO_HIDDEN: begin
                                        amo_state = AMO_HOLD_RD; // Also move into another special, addi special1, special, 0
                                        temp_signals.alu_op = ALU_ADD;
                                        temp_signals.rs2_src = IMM;
                                        temp_signals.rf_writeback = ALU_REG;
                                        imm = '0;
                                        temp_signals.rs1 = 6'd32;
                                        temp_signals.rd = 6'd33;
                                        temp_signals.rf_wr_en = 1;
                                    end
                                    AMO_HOLD_RD: begin
                                        amo_state = AMO_OP;
                                        temp_signals.rs2_src = REG;
                                        temp_signals.rf_writeback = ALU_REG;
                                        temp_signals.rf_wr_en = 1;
                                        temp_signals.rs1 = 6'd32;  // special = special (op) rs2
                                        temp_signals.rd = 6'd32;
                                        case (funct5)
                                            // AMOSWAP - (practically) MV, ADD special, rs2, 0
                                            // so rs2 later gets stored into (rs1)
                                            5'b00001: begin
                                                temp_signals.alu_op = ALU_ADD;
                                                temp_signals.rs1 = '0;
                                            end
                                            // AMOADD - ADD
                                            5'b00000: temp_signals.alu_op = ALU_ADD;
                                            5'b01100: temp_signals.alu_op = ALU_AND;
                                            5'b01000: temp_signals.alu_op = ALU_OR;
                                            5'b00100: temp_signals.alu_op = ALU_XOR;
                                            5'b10100: temp_signals.alu_op = ALU_MAX;
                                            5'b11100: temp_signals.alu_op = ALU_MAXU;
                                            5'b10000: temp_signals.alu_op = ALU_MIN;
                                            5'b11000: temp_signals.alu_op = ALU_MINU;
                                            default:  illegal_instr(temp_signals);
                                        endcase
                                    end
                                    AMO_OP: begin
                                        amo_state = AMO_STORE;
                                        temp_signals.alu_op = ALU_ADD;
                                        temp_signals.rs2_src = IMM;
                                        temp_signals.rs2 = 6'd32;
                                        temp_signals.rf_writeback = ALU_MEM_ADDR_WRITE_W;
                                        temp_signals.mem_wr_en = 1;
                                        imm = '0;
                                    end
                                    AMO_STORE: begin
                                        amo_state = AMO_MOVE_RD;  // From another special to our
                                        temp_signals.alu_op = ALU_ADD;
                                        temp_signals.rs2_src = IMM;
                                        temp_signals.rf_writeback = ALU_REG;
                                        imm = '0;
                                        temp_signals.rs1 = 6'd33;
                                        temp_signals.rf_wr_en = 1;
                                    end
                                    AMO_MOVE_RD: begin
                                        amo_state  = AMO_OFF;
                                        next_pc_en = 0;
                                    end

                                    default: illegal_instr(temp_signals);
                                endcase
                            end
                            default: illegal_instr(temp_signals);
                        endcase
                    end
                end

                default: illegal_instr(temp_signals);
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
            amo_state_q <= AMO_OFF;
        end else begin

            amo_state_q <= amo_state;
            // If flush asserted, save latch values
            if (flush && !isr_en) begin
                flush_latch_q <= 1;
                flush_pc_q <= flush_pc;
            end else if ((instr_pc == flush_pc_q) && valid) begin
                // Possibly clear flush_latch if we got requested address as valid isntr
                flush_latch_q <= 0;
            end


            if (exec_stall || stall_D || (trap_stall && !trap_service)) begin
                ctrl_signals <= ctrl_signals;
            end else if (!valid || flush || flush_latch_q || isr_pending || trap_taken) begin
                ctrl_signals <= '0;
            end else begin
                // We get a new instruction

                ctrl_signals <= temp_signals;
            end

        end
    end

endmodule
