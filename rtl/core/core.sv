/* verilator lint_off IMPORTSTAR */
import core_pkg::*;
/* verilator lint_on IMPORTSTAR */

module core (
    input logic        clk,
    input logic        rst_n,
    // Memory interface
    input logic [31:0] mem_rd_data1,
    input logic [31:0] mem_rd_data2,
    input logic        stall_I,
    input logic        stall_D,

    output logic        rd_en_d,
    output logic        rd_en_i,
    output logic [31:0] mem_addr1,
    output logic [31:0] mem_addr2,
    output logic        mem_wr_en,
    output logic [31:0] mem_wr_data,
    output logic [ 3:0] mem_byte_en
);



    logic [31:0] if_id_instr;
    logic [31:0] if_id_pc;
    logic [31:0] next_pc;
    logic next_pc_en;




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
        .mem_enable(rd_en_i)
    );

    // Register file signals and instance
    logic [4:0] rs1;
    logic [4:0] rs1_id;
    logic [4:0] rs2;
    logic [4:0] rd;
    logic [31:0] rs1_data;
    logic [31:0] rs1_id_data;
    logic [31:0] rs2_data;
    logic rf_wr_en;
    logic [31:0] rf_wr_data;
    register_file regfile_inst (
        .clk  (clk),
        .rst_n(rst_n),

        .rs1_addr(rs1),
        .rs2_addr(rs2),
        .rs1_id_addr(rs1_id),

        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .rs1_id_data(rs1_id_data),

        .exec_forward_result(ex_id_frwrd_ctrl),
        .mem_forward_result (ex_mem_ctrl),
        .rf_forward_result  (rd_if_forward_ctrl),


        .wr_en  (rf_wr_en),
        .wr_addr(rd),
        .wr_data(rf_wr_data)
    );



    ctrl_signals_t id_ex_ctrl;
    ctrl_signals_t ex_id_frwrd_ctrl;
    logic ex_id_flush;
    ctrl_signals_t rd_if_forward_ctrl;
    logic [31:0] ex_id_flush_pc;
    logic exec_stall;
    logic decode_stall;

    assign decode_stall = exec_stall || stall_D;
    decode decode_stage (
        .clk  (clk),
        .rst_n(rst_n),

        .instr_data(if_id_instr),
        .instr_pc  (if_id_pc),
        .rs1_addr  (rs1_id),
        .rs1_data  (rs1_id_data),

        .next_pc(next_pc),
        .next_pc_en(next_pc_en),



        .flush(ex_id_flush),
        .flush_pc(ex_id_flush_pc),

        .exec_stall(decode_stall),

        .ctrl_signals(id_ex_ctrl)

    );



    ctrl_signals_t ex_mem_ctrl;

    exec exec_stage (
        .clk  (clk),
        .rst_n(rst_n),

        .in_ctrl_signals (id_ex_ctrl),
        .out_ctrl_signals(ex_mem_ctrl),

        .forward_result(ex_id_frwrd_ctrl),
        .rs1_addr(rs1),
        .rs2_addr(rs2),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .stall(stall_D),

        .flush(ex_id_flush),
        .flush_pc(ex_id_flush_pc),
        .exec_stall(exec_stall)
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
        .stall(stall_D),
        .mem_enable(rd_en_d),

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
