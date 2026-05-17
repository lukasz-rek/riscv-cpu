/* verilator lint_off IMPORTSTAR */
import csr_pkg::*;
/* verilator lint_on IMPORTSTAR */

module csr_regfile (
    input logic clk,
    input logic rst_n,

    input logic [11 : 0] csr_addr,
    input logic csr_rd_en,
    input logic csr_wr_en,

    input  logic [31:0] csr_wr_data,
    output logic [31:0] csr_rd_data,

    // Rest of information
    input logic minstret_incr,

    // Trap handling
    input logic trap_en,
    input isr_cause_t trap_cause,
    /* verilator lint_off UNUSEDSIGNAL */
    input logic [31:0] trap_pc,
    /* verilator lint_on UNUSEDSIGNAL */
    input logic [31:0] trap_val,
    input logic mret_en,

    output logic trap_taken,
    output logic [31:0] trap_target,
    output logic trap_pending,

    // ISR signals
    input logic mtime_isr

);

    // Decode addr
    logic current_csr_read_only;
    csr_privilege_t current_csr_priv_bits;

    assign current_csr_read_only = (csr_addr[11:10] == 2'b11);
    assign current_csr_priv_bits = csr_privilege_t'(csr_addr[9:8]);


    assign trap_taken = trap_en | mret_en;
    assign trap_target = mret_en ? mepc_q.pc :
                         (mtvec_q.mode == 2'b01) ? // If vector mode, BASE + 4 * CAUSE
        {mtvec_q.base, 2'b00} + (32'(mcause_q.code) << 2) : {mtvec_q.base, 2'b00};

    // State
    csr_privilege_t privilege;

    // CSRs
    localparam misa_t MISA_VALUE = '{
        mxl: 2'b01,  // RV32
        zero: 4'b0,
        extensions:
        26'h0 | (
        1 << 8
        )  // I
        | (
        1 << 12
        )  // M
    };  // misa
    logic [63:0] mcycle;
    logic [63:0] minstret;
    // verilog_format: off
    /* verilator lint_off UNUSEDSIGNAL */
    mstatus_t mstatus; mstatus_t mstatus_q; mstatus_t mstatus_temp;
    mstatush_t mstatush; mstatush_t mstatush_q;
    mtvec_t mtvec; mtvec_t mtvec_q; mtvec_t mtvec_temp;
    mie_t mie; mie_t mie_q;
    mip_t mip; mip_t mip_q;
    mepc_t mepc; mepc_t mepc_q;
    mcause_t mcause; mcause_t mcause_q;
    mscratch_t mscratch; mscratch_t mscratch_q;
    mtval_t mtval; mtval_t mtval_q;
    /* verilator lint_on UNUSEDSIGNAL */
    // verilog_format: on

    // True iff any isr is waiting
    logic isr_pending;
    // Depending on what combination of isr+trap triggered decodes right one
    isr_cause_t prioritised_isr_cause;

    assign isr_pending = mstatus_q.mie & ((mie_q & mip) != '0);

    // Handle isr/trap cause
    always_comb begin
        prioritised_isr_cause = HW_ERROR;
        trap_pending = isr_pending;
        if (isr_pending) begin
            // trap_pending = 1;
            if (mip[7]) prioritised_isr_cause = M_MACHINE_TIMER;
            else prioritised_isr_cause = trap_cause;
        end else if (trap_taken) begin
            // trap_pending = 1;
            prioritised_isr_cause = trap_cause;
        end
    end

    // Reads + sanitize writes
    always_comb begin
        csr_rd_data = '0;

        // verilog_format: off
        mstatus = mstatus_q; mstatus_temp = '0;
        mstatush = mstatus_q;
        mtvec = mtvec_q; mtvec_temp = '0;
        mie = mie_q;
        mip = '0;
        mip[7] = mtime_isr;
        mepc = mepc_q;
        mcause = mcause_q;
        mscratch = mscratch_q;
        mtval = mtval_q;
        // verilog_format: on

        if (!csr_rd_en && !csr_wr_en) begin
            ;  // Do nothing
        end else if (current_csr_priv_bits > privilege) begin
            // TODO: throw exception
        end else if (current_csr_read_only && csr_wr_en) begin
            // TODO: throw exception
        end else begin

            case (csr_addr)
                // Machine Information Registers
                // Machine Trap Setup
                12'h300: begin
                    csr_rd_data  = mstatus_q;
                    mstatus_temp = mstatus_t'(csr_wr_data);

                    mstatus.mie  = mstatus_temp.mie;
                end
                12'h301: csr_rd_data = MISA_VALUE;
                12'h304: begin
                    csr_rd_data = mie_q;
                    mie = mie_t'(csr_wr_data);
                end
                12'h305: begin
                    csr_rd_data = mtvec_q;
                    mtvec_temp  = mtvec_t'(csr_wr_data);

                    if (mtvec_temp.mode <= 2'd1) begin
                        mtvec.mode = mtvec_temp.mode;
                    end
                    mtvec.base = mtvec_temp.base;

                end
                12'h310: begin
                    csr_rd_data = mstatush;
                end
                // Machine Trap Handling
                12'h340: csr_rd_data = mscratch_q;
                12'h341: begin
                    csr_rd_data = mepc_q;

                    mepc = csr_wr_data;
                end
                12'h342: csr_rd_data = mcause_q;
                12'h343: csr_rd_data = mtval_q;
                12'h344: csr_rd_data = mip_q;
                // Machine Counters/Timers
                12'hC00, 12'hC01: csr_rd_data = mcycle[31:0];
                12'hC80, 12'hC81: csr_rd_data = mcycle[63:32];
                12'hC02: csr_rd_data = minstret[31:0];
                12'hC82: csr_rd_data = minstret[63:32];
                default: ;
            endcase

        end



    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            // Zero all CSRs
            mcycle <= '0;
            minstret <= '0;
            privilege <= M_MODE;
            mstatus_q <= '0;
            mie_q <= '0;
        end else begin
            mcycle   <= mcycle + 1;
            minstret <= (minstret_incr) ? minstret + 1 : minstret;
            if (trap_en) begin
                mepc_q.pc <= trap_pc;
                mcause_q <= mcause_t'(prioritised_isr_cause);
                mtval_q <= mtval_t'(trap_val);

                mstatus_q.mpie <= mstatus_q.mie;
                mstatus_q.mie <= 1'b0;
                mstatus_q.mpp <= privilege;
                privilege <= M_MODE;
            end else if (mret_en) begin
                mstatus_q.mie <= mstatus_q.mpie;
                mstatus_q.mpie <= 1'b1;
                privilege <= csr_privilege_t'(mstatus_q.mpp);
                mstatus_q.mpp <= M_MODE;
            end else if (csr_wr_en) begin
                mstatus_q <= mstatus;
                mstatush_q <= mstatush;
                mtvec_q <= mtvec;
                mie_q <= mie;
                mip_q <= mip;
                mepc_q <= mepc;
                mcause_q <= mcause;
                mscratch_q <= mscratch;
                mtval_q <= mtval;
            end
        end
    end

endmodule
