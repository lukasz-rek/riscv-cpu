/* verilator lint_off IMPORTSTAR */
import core_pkg::*;
import csr_pkg::*;
/* verilator lint_on IMPORTSTAR */

module core (
    input logic        clk,
    input logic        rst_n,
    // Memory interface
    input logic [31:0] mem_rd_data1,
    input logic [31:0] mem_rd_data2,
    input logic        stall_I,
    input logic        stall_D,

    output logic flush_I,

    output logic        rd_en_d,
    output logic        rd_en_i,
    output logic [31:0] mem_addr1,
    output logic [31:0] mem_addr2,
    output logic        mem_wr_en,
    output logic [31:0] mem_wr_data,
    output logic [ 3:0] mem_byte_en,

    // ISRs
    input logic mtime_isr,
    input logic uart_isr
);



    logic [31:0] if_id_instr;
    logic [31:0] if_id_pc;
    logic [31:0] next_pc;
    logic next_pc_en;
    logic valid;



    fetch fetch_stage (
        .clk  (clk),
        .rst_n(rst_n),

        .mem_instr_data(mem_rd_data1),
        .id_next_pc(next_pc),
        .id_next_pc_en(next_pc_en),

        .id_instr_data(if_id_instr),
        .id_instr_pc  (if_id_pc),

        .mem_instr_addr(mem_addr1),
        .stall(stall_I),
        .mem_enable(rd_en_i),
        .valid(valid)
    );

    // Register file signals and instance
    logic [ 5:0] rs1;
    logic [ 5:0] rs2;
    logic [ 5:0] rd;
    logic [31:0] rs1_data;
    logic [31:0] rs2_data;
    logic rs1_valid, rs2_valid;
    logic rf_wr_en;
    logic [31:0] rf_wr_data;
    register_file regfile_inst (
        .clk  (clk),
        .rst_n(rst_n),

        .rs1_addr(rs1),
        .rs2_addr(rs2),

        .rs1_data(rs1_data),
        .rs2_data(rs2_data),

        .rs1_valid(rs1_valid),
        .rs2_valid(rs2_valid),

        .exec_forward_result(ex_mem_ctrl),
        .mem_forward_result (rd_if_forward_ctrl),
        // .rf_forward_result  (rd_if_forward_ctrl),


        .wr_en  (rf_wr_en),
        .wr_addr(rd),
        .wr_data(rf_wr_data)
    );


    // CSR file instance
    logic [11:0] csr_addr;
    logic csr_rd_en;
    logic csr_wr_en;
    logic [31:0] csr_wr_data;
    logic [31:0] csr_rd_data;
    logic minstret_incr;

    // Trap handling
    logic trap_en;
    logic isr_en;
    isr_cause_t trap_cause;
    logic [31:0] trap_pc;
    logic [31:0] isr_pc;
    logic [31:0] trap_val;
    logic mret_en;

    logic trap_taken;
    logic [31:0] trap_target;
    logic isr_pending;

    csr_regfile csr_regfile (
        .clk  (clk),
        .rst_n(rst_n),

        .csr_addr (csr_addr),
        .csr_rd_en(csr_rd_en),
        .csr_wr_en(csr_wr_en),

        .csr_wr_data(csr_wr_data),
        .csr_rd_data(csr_rd_data),

        .minstret_incr(minstret_incr),

        .trap_en(trap_en | isr_en),
        .trap_cause(trap_cause),
        .trap_pc((trap_en) ? trap_pc : isr_pc),
        .trap_val(trap_val),
        .mret_en(mret_en),

        .trap_taken  (trap_taken),
        .trap_target (trap_target),
        .trap_pending(isr_pending),

        .mtime_isr(mtime_isr),
        .uart_isr (uart_isr)
    );



    ctrl_signals_t id_ex_ctrl;
    // ctrl_signals_t ex_id_frwrd_ctrl;
    logic ex_id_flush;
    ctrl_signals_t rd_if_forward_ctrl;
    logic [31:0] ex_id_flush_pc;
    logic exec_stall;
    logic trap_stall;
    logic freeze;
    logic id_ex_trap_service;

    decode decode_stage (
        .clk  (clk),
        .rst_n(rst_n),

        .instr_data(if_id_instr),
        .instr_pc  (if_id_pc),

        .next_pc(next_pc),
        .next_pc_en(next_pc_en),



        .flush(ex_id_flush),
        .flush_pc(ex_id_flush_pc),

        .exec_stall(exec_stall),
        .stall_I(stall_I),
        .stall_D(stall_D),
        // .ctrl_rf_write(rd_if_forward_ctrl),

        .ctrl_signals(id_ex_ctrl),
        .valid(valid),
        .freeze(freeze),
        .minstret_incr(minstret_incr),

        .trap_stall(trap_stall),
        .trap_taken(trap_taken),
        .trap_target(trap_target),
        .isr_pending(isr_pending),
        .isr_pc(isr_pc),
        .isr_en(isr_en),
        .trap_service(id_ex_trap_service)
    );



    ctrl_signals_t ex_mem_ctrl;

    exec exec_stage (
        .clk  (clk),
        .rst_n(rst_n),

        .in_ctrl_signals (id_ex_ctrl),
        .out_ctrl_signals(ex_mem_ctrl),

        // .forward_result(ex_id_frwrd_ctrl),
        .rs1_addr (rs1),
        .rs2_addr (rs2),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data),
        .rs1_valid(rs1_valid),
        .rs2_valid(rs2_valid),

        .csr_addr (csr_addr),
        .csr_rd_en(csr_rd_en),
        .csr_wr_en(csr_wr_en),

        .csr_wr_data(csr_wr_data),
        .csr_rd_data(csr_rd_data),

        .trap_en(trap_en),
        .trap_cause(trap_cause),
        .trap_pc(trap_pc),
        .trap_val(trap_val),
        .mret_en(mret_en),


        .freeze (freeze),
        .stall_D(stall_D),

        .trap_stall(trap_stall),
        .flush(ex_id_flush),
        .flush_pc(ex_id_flush_pc),
        .exec_stall(exec_stall),
        .trap_service(id_ex_trap_service)

    );

    ctrl_signals_t mem_rf_ctrl;

    mem mem_stage (
        .clk  (clk),
        .rst_n(rst_n),

        .in_ctrl_signals(ex_mem_ctrl),

        .mem_addr2(mem_addr2),
        .mem_wr_en(mem_wr_en),
        .mem_wr_data(mem_wr_data),
        .mem_byte_en(mem_byte_en),
        .mem_enable(rd_en_d),
        .stall_D(stall_D),
        .flush_I(flush_I),

        .out_ctrl_signals(mem_rf_ctrl)
    );


    rf_writeback rf_stage (
        // .clk  (clk),
        // .rst_n(rst_n),

        .rf_wr_en(rf_wr_en),
        .wr_addr (rd),
        .wr_data (rf_wr_data),
        .mem_read(mem_rd_data2),

        .in_ctrl_signals(mem_rf_ctrl),
        .current_ctrl_signals(rd_if_forward_ctrl)
    );


endmodule
