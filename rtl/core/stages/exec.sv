/* verilator lint_off IMPORTSTAR */
import core_pkg::*;
import csr_pkg::*;
/* verilator lint_on IMPORTSTAR */

module exec (
    input logic clk,
    input logic rst_n,

    input  ctrl_signals_t in_ctrl_signals,
    output ctrl_signals_t out_ctrl_signals,

    // output ctrl_signals_t forward_result,

    // Register file stuff
    output logic [4:0] rs1_addr,
    output logic [4:0] rs2_addr,
    input logic [31:0] rs1_data,
    input logic [31:0] rs2_data,
    input logic rs1_valid,
    input logic rs2_valid,

    // CSR access
    output logic csr_rd_en,
    output logic csr_wr_en,
    output logic [11:0] csr_addr,
    input logic [31:0] csr_rd_data,
    output logic [31:0] csr_wr_data,

    // Trap signals
    output logic trap_en,
    output isr_cause_t trap_cause,
    output logic [31:0] trap_pc,
    output logic [31:0] trap_val,
    output logic mret_en,

    input logic freeze,
    input logic stall_D,

    output logic flush,
    output logic exec_stall,
    output logic trap_stall,
    output logic [31:0] flush_pc
);


    logic [31:0] alu_op_a;
    logic [31:0] alu_op_b;
    alu_op_t alu_op;
    logic [31:0] alu_result;
    logic alu_zero;
    logic alu_active;
    logic alu_result_en;
    alu alu_inst (
        .clk  (clk),
        .rst_n(rst_n),

        .a(alu_op_a),
        .b(alu_op_b),
        .alu_op(alu_op),
        .result(alu_result),
        .zero(alu_zero),
        .alu_active(alu_active),
        .alu_result_en(alu_result_en)
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

    // While a registered trap/mret redirect is in flight (trap_en/mret_en), the
    // instruction now sitting in EXEC is younger than the trapping one and must be
    // discarded. Its memory/RF writes are already killed via out_ctrl_signals, but
    // CSR writes, the branch flush, and exec_stall are *early* combinational outputs
    // that bypass that register, so they must be suppressed here.
    logic trap_servicing;
    assign trap_servicing = trap_en | mret_en;

    assign csr_addr = in_ctrl_signals.csr_addr;
    assign csr_rd_en = in_ctrl_signals.csr_rd_en && !trap_servicing;
    assign csr_wr_en = in_ctrl_signals.csr_wr_en && !trap_servicing;

    assign alu_div_active = (alu_op == ALU_DIV || alu_op == ALU_DIVU || alu_op == ALU_REM || alu_op == ALU_REMU);


    logic       [31:0] csr_input;

    // Combinational trap *detection* for the instruction currently in EXEC.
    // These are registered below before being driven onto the trap output ports
    // so the long exec->csr->decode->fetch redirect cone starts from a flop
    // instead of from the ALU result (was the worst setup path / the trap_en BUFGCE net).
    logic              trap_detect;
    logic              mret_detect;
    logic              trap_stall_d;
    isr_cause_t        trap_cause_d;
    logic       [31:0] trap_pc_d;
    logic       [31:0] trap_val_d;

    always_comb begin
        // Assign correct operands
        alu_op_a = rs1_data;
        alu_op_b = '0;
        flush = 0;
        flush_pc = '0;
        exec_stall = '0;
        trap_stall_d = 0;
        csr_input = '0;
        mret_detect = 0;
        trap_detect = 0;
        // Defaults keep these latch-free; only consumed when trap_detect=1.
        trap_cause_d = ILLEGAL_INSTR;
        trap_pc_d = '0;
        trap_val_d = '0;

        case (in_ctrl_signals.rs2_src)
            REG: alu_op_b = rs2_data;
            IMM: alu_op_b = in_ctrl_signals.imm;
            SHAMT: alu_op_b = {27'b0, rs2_addr};
            default: ;
        endcase

        // Handle stall when we don't have data yet
        // We can't start div or anything during this time
        if ((in_ctrl_signals.alu_op != ALU_OFF || in_ctrl_signals.rf_writeback == ALU_CSR) && (!rs1_valid || !rs2_valid)) begin
            alu_op = ALU_OFF;
            exec_stall = 1;
            temp_signals = '0;
        end else if (in_ctrl_signals.trap_en || in_ctrl_signals.mret_en) begin
            alu_op = ALU_OFF;
            temp_signals = '0;  // squash
            trap_stall_d = 1;
            if (in_ctrl_signals.trap_en) begin
                trap_detect = 1;
                trap_pc_d   = in_ctrl_signals.pc;
                if (in_ctrl_signals.trap_cause == BREAKPOINT) trap_val_d = in_ctrl_signals.pc;
                else if (in_ctrl_signals.trap_cause == ILLEGAL_INSTR)
                    trap_val_d = in_ctrl_signals.instr;
                else if (in_ctrl_signals.trap_cause == INSTR_ADDR_MALIGN)
                    trap_val_d = in_ctrl_signals.trap_val;
                else trap_val_d = '0;
                trap_cause_d = in_ctrl_signals.trap_cause;
            end else begin
                mret_detect = 1;
            end

        end else begin



            alu_op = in_ctrl_signals.alu_op;


            temp_signals = in_ctrl_signals;
            case (in_ctrl_signals.rf_writeback)
                ALU_REG: begin
                    temp_signals.rf_wr_data_valid = 1;
                    temp_signals.rf_wr_data = alu_result;
                end
                ALU_MEM_ADDR_WRITE_B, ALU_MEM_ADDR_WRITE_H, ALU_MEM_ADDR_WRITE_W: begin
                    temp_signals.mem_wr_addr = alu_result;
                    if (in_ctrl_signals.rf_writeback == ALU_MEM_ADDR_WRITE_B) begin
                        temp_signals.mem_byte_en = 4'b0001 << alu_result[1:0];
                        temp_signals.mem_wr_data = {4{rs2_data[7:0]}};
                    end else if (in_ctrl_signals.rf_writeback == ALU_MEM_ADDR_WRITE_H) begin
                        if (alu_result[0]) begin
                            trap_detect = 1;
                            trap_stall_d = 1;
                            trap_pc_d = in_ctrl_signals.pc;
                            trap_val_d = alu_result;
                            trap_cause_d = STORE_ADDR_MALIGN;
                        end else begin
                            temp_signals.mem_byte_en = 4'b0011 << {alu_result[1], 1'b0};
                            temp_signals.mem_wr_data = {2{rs2_data[15:0]}};
                        end
                    end else begin
                        if (alu_result[1:0] != 2'b00) begin
                            trap_detect = 1;
                            trap_stall_d = 1;
                            trap_pc_d = in_ctrl_signals.pc;
                            trap_val_d = alu_result;
                            trap_cause_d = STORE_ADDR_MALIGN;
                        end else begin
                            temp_signals.mem_wr_data = rs2_data;
                            temp_signals.mem_byte_en = 4'b1111;
                        end
                    end
                end
                ALU_MEM_ADDR_READ: begin
                    temp_signals.mem_addr2 = alu_result;
                    case (in_ctrl_signals.load_mask)
                        LW: begin
                            if (alu_result[1:0] != 2'b00) begin
                                trap_detect = 1;
                                trap_stall_d = 1;
                                trap_pc_d = in_ctrl_signals.pc;
                                trap_val_d = alu_result;
                                trap_cause_d = LOAD_ADDR_MALIGN;
                            end
                        end
                        LH, LHU: begin
                            if (alu_result[0]) begin
                                trap_detect = 1;
                                trap_stall_d = 1;
                                trap_pc_d = in_ctrl_signals.pc;
                                trap_val_d = alu_result;
                                trap_cause_d = LOAD_ADDR_MALIGN;
                            end
                        end
                        default: ;  // LB, LBU — byte access, always aligned
                    endcase
                end
                ALU_PC_INCR: begin
                    alu_op_a = in_ctrl_signals.pc;
                    alu_op_b = 4;
                    temp_signals.rf_wr_data = alu_result;
                    temp_signals.rf_wr_data_valid = 1;
                end
                ALU_JALR: begin
                    // Special case, we need ot jump to address calculated
                    // but check trap triggered
                    if (alu_result[1]) begin
                        trap_detect = 1;
                        trap_stall_d = 1;
                        trap_pc_d = in_ctrl_signals.pc;
                        trap_val_d = alu_result & ~32'b1;
                        trap_cause_d = INSTR_ADDR_MALIGN;
                    end else begin
                        flush = 1;
                        flush_pc = alu_result & ~32'b1;
                    end
                end
                ALU_CSR: begin
                    csr_input = (temp_signals.csr_imm) ? in_ctrl_signals.imm : rs1_data;
                    case (temp_signals.csr_op)
                        CSR_RW: begin
                            csr_wr_data = csr_input;
                            temp_signals.rf_wr_data = csr_rd_data;
                        end
                        CSR_SET: begin
                            // Store original value
                            temp_signals.rf_wr_data = csr_rd_data;
                            csr_wr_data = csr_rd_data | csr_input;
                        end
                        CSR_CLEAR: begin
                            temp_signals.rf_wr_data = csr_rd_data;
                            csr_wr_data = csr_rd_data & ~csr_input;
                        end
                        default: ;
                    endcase
                    temp_signals.rf_wr_data_valid = 1;
                end
                default: ;
            endcase

            // Handle possible flush
            if (alu_zero != in_ctrl_signals.branch_expects_zero && in_ctrl_signals.branch_instr) begin
                // We done goofed up, we need to fluuuuuuuuuuuuuuuush
                flush = 1;
                flush_pc = in_ctrl_signals.pc + 4;
                temp_signals = '0;  // Insert no ops later
            end

            // Handle exec stalls
            if ((alu_div_active && !div_result_en) || (alu_active && !alu_result_en)) begin
                exec_stall   = 1;
                temp_signals = '0;
            end else if (alu_div_active && div_result_en) begin
                // We have a result from division, so we can move forward
                temp_signals.rf_wr_data = div_alu_result;
                temp_signals.rf_wr_data_valid = 1;
            end else if (alu_active && alu_result_en) begin
                temp_signals.rf_wr_data = alu_result;
                temp_signals.rf_wr_data_valid = 1;
            end
        end

        // Suppress the younger instruction's early side-effects while a registered
        // trap/mret redirect is in flight. flush would otherwise hijack the redirect
        // (flush_latch outranks trap_taken in decode); exec_stall would block it and
        // drop the single-cycle trap pulse entirely.
        if (trap_servicing) begin
            flush = 1'b0;
            exec_stall = 1'b0;
        end

    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            out_ctrl_signals <= 0;
        end else begin
            if (stall_D) begin
                out_ctrl_signals <= out_ctrl_signals;
            end else if (freeze || trap_detect || mret_detect || trap_en || mret_en) begin
                // trap_detect/mret_detect: squash the faulting instruction itself (same
                // cycle it is detected). trap_en/mret_en: squash the younger instruction
                // that advanced into EXEC during the extra cycle before the (now
                // registered) redirect takes effect.
                out_ctrl_signals <= '0;
            end else begin
                out_ctrl_signals <= temp_signals;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Registered trap request.
    //
    // The trap outputs used to be combinational, which put the
    // load -> forward -> ALU -> trap_en -> csr -> decode -> fetch(PC) redirect on
    // a single ~21-level cone (and let Vivado promote trap_en onto a BUFGCE).
    // Registering them launches that redirect cone from a flop. Cost: the trap is
    // taken one cycle later, so the faulting instruction is still squashed
    // combinationally above (trap_detect), and the one younger instruction that
    // slips into EXEC is squashed via the registered trap_en/mret_en.
    //
    // The pulse gate (& ~(trap_en | mret_en)) keeps it a single-cycle event and
    // prevents a squashed wrong-path instruction from re-arming a spurious trap.
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            trap_en    <= 1'b0;
            mret_en    <= 1'b0;
            trap_stall <= 1'b0;
            trap_cause <= ILLEGAL_INSTR;
            trap_pc    <= '0;
            trap_val   <= '0;
        end else if (stall_D) begin
            // Hold the pending trap request across memory stalls.
            trap_en    <= trap_en;
            mret_en    <= mret_en;
            trap_stall <= trap_stall;
        end else begin
            trap_en    <= trap_detect  & ~(trap_en | mret_en);
            mret_en    <= mret_detect  & ~(trap_en | mret_en);
            trap_stall <= trap_stall_d & ~(trap_en | mret_en);
            trap_cause <= trap_cause_d;
            trap_pc    <= trap_pc_d;
            trap_val   <= trap_val_d;
        end
    end


endmodule
