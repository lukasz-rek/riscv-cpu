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
    // Tell exec some goofy CSR access just happened
    output logic csr_bad,

    output logic trap_taken,
    output logic [31:0] trap_target,
    output logic trap_pending,

    // ISR signals
    input logic mtime_isr,
    input logic uart_isr
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
    mstatus_t mstatus; mstatus_t mstatus_q;
    mstatush_t mstatush; mstatush_t mstatush_q;
    mtvec_t mtvec; mtvec_t mtvec_q; mtvec_t mtvec_temp;
    mie_t mie; mie_t mie_q;
    mip_t mip; mip_t mip_q;
    mip_t eff_pending;
    mepc_t mepc; mepc_t mepc_q;
    mcause_t mcause; mcause_t mcause_q;
    mscratch_t mscratch; mscratch_t mscratch_q;
    mtval_t mtval; mtval_t mtval_q;
    medeleg_t medeleg; medeleg_t medeleg_q;
    medelegh_t medelegh; medelegh_t medelegh_q;
    mideleg_t mideleg; mideleg_t mideleg_q;
    mcounteren_t mcounteren; mcounteren_t mcounteren_q;
    // Supervisor CSRs
    sstatus_t sstatus_temp; sstatus_t sstatus_mask;
    assign sstatus_mask = 32'h818DE762; // Masks wpri fields
    sie_t sie_temp; sie_t sie_mask;
    assign sie_mask = 32'h0000_2222;
    sip_t sip_temp; sip_t sip_mask;
    assign sip_mask = 32'h0000_2222;
    stvec_t stvec; stvec_t stvec_q; stvec_t stvec_temp;
    sepc_t sepc; sepc_t sepc_q;
    scause_t scause; scause_t scause_q;
    stval_t stval; stval_t stval_q;
    sscratch_t sscratch; sscratch_t sscratch_q;
    satp_t satp; satp_t satp_q;
    scounteren_t scounteren; scounteren_t scounteren_q;
    /* verilator lint_on UNUSEDSIGNAL */
    // verilog_format: on

    // True iff any isr is waiting
    logic isr_pending;
    // Depending on what combination of isr+trap triggered decodes right one
    isr_cause_t prioritised_isr_cause;

    assign isr_pending = mstatus_q.mie & ((mie_q & mip) != '0);

    assign mip = (mip_t'(uart_isr) << 11) | (mip_t'(mtime_isr) << 7);
    assign eff_pending = mie_q & mip;  // Enabled and pending

    // Handle isr/trap cause
    always_comb begin
        prioritised_isr_cause = HW_ERROR;
        trap_pending = !csr_rd_en && !csr_wr_en && isr_pending;
        if (isr_pending) begin
            // Per spec it is MEI > MSI > MTI
            if (eff_pending[11]) prioritised_isr_cause = M_EXTERNAL_ISR;  // MEI
            else if (eff_pending[7]) prioritised_isr_cause = M_MACHINE_TIMER;  // MTI
            else prioritised_isr_cause = trap_cause;
        end else if (trap_taken) begin
            prioritised_isr_cause = trap_cause;
        end
    end

    // Reads + sanitize writes
    always_comb begin
        csr_rd_data = '0;
        csr_bad = 0;

        // verilog_format: off
        mstatus = mstatus_q;
        mstatush = mstatus_q;
        mtvec = mtvec_q; mtvec_temp = '0;
        mie = mie_q;
        mepc = mepc_q;
        mcause = mcause_q;
        mscratch = mscratch_q;
        mtval = mtval_q;
        // Supervisor
        sstatus_temp = '0;
        sie_temp = '0;
        sip_temp = '0;
        stvec = stvec_q; stvec_temp = '0;
        scounteren = scounteren_q;
        sscratch = sscratch_q;
        sepc = sepc_q;
        scause = scause_q;
        stval = stval_q;
        satp = satp_q;
        // verilog_format: on

        if (!csr_rd_en && !csr_wr_en) begin
            ;  // Do nothing
        end else if (current_csr_priv_bits > privilege) begin
            csr_bad = 1;
        end else if (current_csr_read_only && csr_wr_en) begin
            csr_bad = 1;
        end else begin

            case (csr_addr)
                // Supervisor Registers
                // Since some of them are the same as Machine ones
                // Then we need to strip inaccessible parts
                // Supervisor Trap Setup
                12'h100: begin
                    csr_rd_data = mstatus_q & sstatus_mask;

                    sstatus_temp = sstatus_t'(csr_wr_data) & sstatus_mask;
                    mstatus = (mstatus_q & ~sstatus_mask) | sstatus_temp;
                end
                12'h104: begin
                    csr_rd_data = mie_q & sie_mask;

                    sie_temp = sie_t'(csr_wr_data) & sie_mask;
                    mie = (mie_q & ~sie_mask) | sie_temp;
                end
                12'h105: begin
                    csr_rd_data = stvec_q;

                    stvec_temp  = stvec_t'(csr_wr_data);
                    if (stvec_temp.mode <= 2'd1) begin
                        stvec.mode = stvec_temp.mode;
                    end
                    stvec.base = stvec_temp.base;
                end
                12'h106: begin
                    csr_rd_data = scounteren_q;

                    scounteren  = scounteren_t'(csr_wr_data);
                end
                // Supervisor Trap Handling
                12'h140: begin
                    csr_rd_data = sscratch_q;

                    sscratch = csr_wr_data;
                end
                12'h141: begin
                    csr_rd_data = sepc_q;

                    sepc = csr_wr_data;
                    sepc[1:0] = 2'b00;
                end
                12'h142: begin
                    csr_rd_data = scause_q;

                    scause = csr_wr_data;
                end
                12'h143: begin
                    csr_rd_data = stval_q;

                    stval = csr_wr_data;
                end
                12'h144: begin
                    csr_rd_data = mip_q & sip_mask;

                end
                // Supervisor Address Protection and Translation
                12'h180: begin
                    csr_rd_data = satp_q;

                    satp = csr_wr_data;
                end
                // Machine Information Registers
                // Machine Trap Setup
                12'h300: begin
                    csr_rd_data = mstatus_q;
                    mstatus = mstatus_t'(csr_wr_data);
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
                12'h340: begin
                    csr_rd_data = mscratch_q;
                    mscratch = mscratch_t'(csr_wr_data);
                end
                12'h341: begin
                    csr_rd_data = mepc_q;

                    mepc = csr_wr_data;
                    mepc[1:0] = 2'b00;
                end
                12'h342: begin
                    csr_rd_data = mcause_q;
                    mcause = mcause_t'(csr_wr_data);
                end
                12'h343: begin
                    csr_rd_data = mtval_q;
                    mtval = mtval_t'(csr_wr_data);
                end
                12'h344: csr_rd_data = mip_q;
                // Machine Counters/Timers
                12'hB00, 12'hB01: csr_rd_data = mcycle[31:0];
                12'hB80, 12'hB81: csr_rd_data = mcycle[63:32];
                12'hB02: csr_rd_data = minstret[31:0];
                12'hB82: csr_rd_data = minstret[63:32];
                // Unprivileged Counters
                12'hC00, 12'hC01: csr_rd_data = mcycle[31:0];
                12'hC80, 12'hC81: csr_rd_data = mcycle[63:32];
                12'hC02: csr_rd_data = minstret[31:0];
                12'hC82: csr_rd_data = minstret[63:32];
                default: csr_bad = 1;
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
            mstatush_q <= '0;
            mtvec_q <= '0;
            mie_q <= '0;
            mip_q <= '0;
            mepc_q <= '0;
            mcause_q <= '0;
            mscratch_q <= '0;
            mtval_q <= '0;
            stvec_q <= '0;
            scounteren_q <= '0;
            sscratch_q <= '0;
            sepc_q <= '0;
            scause_q <= '0;
            stval_q <= '0;
            satp_q <= '0;
        end else begin
            mcycle <= mcycle + 1;
            mip_q <= mip;
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
                mepc_q <= mepc;
                mcause_q <= mcause;
                mscratch_q <= mscratch;
                mtval_q <= mtval;
                scounteren_q <= scounteren;
                stvec_q <= stvec;
                sscratch_q <= sscratch;
                sepc_q <= sepc;
                scause_q <= scause;
                stval_q <= stval;
                satp_q <= satp;
            end
        end
    end

endmodule
