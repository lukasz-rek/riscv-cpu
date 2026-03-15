/* verilator lint_off IMPORTSTAR */
import core_pkg::*;
/* verilator lint_on IMPORTSTAR */

module core (
    input logic        clk,
    input logic        rst_n,
    // Memory interface
    input logic [31:0] mem_rd_data1,
    input logic [31:0] mem_rd_data2,

    output logic [31:0] mem_addr1,
    output logic [31:0] mem_addr2,
    output logic        mem_wr_en,
    output logic [31:0] mem_wr_data,
    output logic [31:0] mem_wr_addr,
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

        .mem_instr_addr(mem_addr1)
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

        .flush(ex_id_flush),
        .flush_pc(ex_id_flush_pc)
    );

    ctrl_signals_t mem_rf_ctrl;

    mem mem_stage (
        .clk  (clk),
        .rst_n(rst_n),

        .in_ctrl_signals(ex_mem_ctrl),

        .mem_addr2  (mem_addr2),
        .mem_wr_en  (mem_wr_en),
        .mem_wr_data(mem_wr_data),
        .mem_wr_addr(mem_wr_addr),
        .mem_byte_en(mem_byte_en),

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












    // // Multi-cycle state machine for BRAM latency
    // typedef enum logic [1:0] {
    //     S_FETCH,   // Wait for BRAM to deliver instruction
    //     S_EXEC,    // Decode + execute
    //     S_LOAD_WB  // Wait for BRAM load data, write back to register
    // } state_t;
    // state_t state;

    // logic [31:0] instruction;
    // logic [31:0] pc, next_pc;
    // logic [31:0] cycle_count;

    // logic branch_taken;
    // logic [6:0] opcode;
    // logic [4:0] rd;
    // logic [4:0] rs1;
    // logic [4:0] rs2;
    // logic [2:0] funct3;
    // logic [6:0] funct7;
    // logic [31:0] imm;

    // // Saved byte offset for load writeback
    // logic [1:0] load_offset;

    // // 1st: Fetch
    // assign instruction = mem_rd_data1;
    // assign mem_addr1 = pc;

    // // 2nd: Decode
    // assign opcode = instruction[6:0];
    // assign funct3 = instruction[14:12];
    // assign funct7 = instruction[31:25];
    // assign rd = instruction[11:7];
    // assign rs1 = instruction[19:15];
    // assign rs2 = instruction[24:20];

    // // ALU signals and instance
    // logic [31:0] alu_op_a;
    // logic [31:0] alu_op_b;
    // alu_op_t alu_op;
    // logic [31:0] alu_result;
    // logic alu_zero;
    // alu alu_inst (
    //     .a(alu_op_a),
    //     .b(alu_op_b),
    //     .alu_op(alu_op),
    //     .result(alu_result),
    //     .zero(alu_zero)
    // );




    // // Immediate assigned based on instr type

    // always_comb begin
    //     // Defaults
    //     rs_wr_en = 0;
    //     mem_wr_en = 0;
    //     branch_taken = 0;
    //     alu_op_b = 32'b0;
    //     alu_op_a = rs1_data;
    //     next_pc = pc + 4;
    //     mem_addr2 = 32'b0;
    //     mem_wr_addr = 32'b0;
    //     mem_wr_data = 32'b0;
    //     mem_byte_en = 4'b0;
    //     imm = 32'b0;
    //     alu_op = ALU_ADD;
    //     rs_wr_data = 32'b0;

    //     if (state == S_LOAD_WB) begin
    //         // Load writeback: select correct bytes from the word BRAM returned
    //         rs_wr_en = 1;
    //         case (funct3)
    //             3'b000:
    //             case (load_offset)  // LB
    //                 2'd0: rs_wr_data = {{24{mem_rd_data2[7]}}, mem_rd_data2[7:0]};
    //                 2'd1: rs_wr_data = {{24{mem_rd_data2[15]}}, mem_rd_data2[15:8]};
    //                 2'd2: rs_wr_data = {{24{mem_rd_data2[23]}}, mem_rd_data2[23:16]};
    //                 2'd3: rs_wr_data = {{24{mem_rd_data2[31]}}, mem_rd_data2[31:24]};
    //             endcase
    //             3'b001:
    //             case (load_offset[1])  // LH
    //                 1'b0: rs_wr_data = {{16{mem_rd_data2[15]}}, mem_rd_data2[15:0]};
    //                 1'b1: rs_wr_data = {{16{mem_rd_data2[31]}}, mem_rd_data2[31:16]};
    //             endcase
    //             3'b010: rs_wr_data = mem_rd_data2;  // LW
    //             3'b100:
    //             case (load_offset)  // LBU
    //                 2'd0: rs_wr_data = {24'b0, mem_rd_data2[7:0]};
    //                 2'd1: rs_wr_data = {24'b0, mem_rd_data2[15:8]};
    //                 2'd2: rs_wr_data = {24'b0, mem_rd_data2[23:16]};
    //                 2'd3: rs_wr_data = {24'b0, mem_rd_data2[31:24]};
    //             endcase
    //             3'b101:
    //             case (load_offset[1])  // LHU
    //                 1'b0: rs_wr_data = {16'b0, mem_rd_data2[15:0]};
    //                 1'b1: rs_wr_data = {16'b0, mem_rd_data2[31:16]};
    //             endcase
    //             default: ;
    //         endcase

    //     end else if (state == S_EXEC) begin
    //         case (opcode)
    //             OP_B: begin
    //                 imm = {
    //                     {20{instruction[31]}},
    //                     instruction[7],
    //                     instruction[30:25],
    //                     instruction[11:8],
    //                     1'b0
    //                 };
    //                 alu_op_b = rs2_data;
    //                 case (funct3)
    //                     BNE, BEQ: alu_op = ALU_SUB;
    //                     BLT, BGE: alu_op = ALU_SLT;
    //                     BLTU, BGEU: alu_op = ALU_SLTU;
    //                     default: ;
    //                 endcase
    //                 // For operations set above, these results mean branching
    //                 case (funct3)
    //                     BNE, BLT, BLTU: branch_taken = !alu_zero;
    //                     BEQ, BGE, BGEU: branch_taken = alu_zero;
    //                     default: ;
    //                 endcase
    //                 if (branch_taken == 1'b1) begin
    //                     next_pc = pc + imm;
    //                 end
    //             end
    //             OP_J: begin
    //                 imm = {
    //                     {12{instruction[31]}},
    //                     instruction[19:12],
    //                     instruction[20],
    //                     instruction[30:21],
    //                     1'b0
    //                 };
    //                 rs_wr_en = 1;
    //                 rs_wr_data = pc + 4;
    //                 next_pc = pc + imm;
    //             end
    //             OP_S: begin
    //                 mem_wr_en = 1;
    //                 imm = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
    //                 alu_op = ALU_ADD;
    //                 alu_op_b = imm;
    //                 mem_wr_addr = alu_result;
    //                 case (funct3)
    //                     3'b000: begin  // SB — replicate byte, shift byte_en to correct lane
    //                         mem_byte_en = 4'b0001 << alu_result[1:0];
    //                         mem_wr_data = {4{rs2_data[7:0]}};
    //                     end
    //                     3'b001: begin  // SH — replicate halfword, shift byte_en
    //                         mem_byte_en = 4'b0011 << {alu_result[1], 1'b0};
    //                         mem_wr_data = {2{rs2_data[15:0]}};
    //                     end
    //                     3'b010: begin  // SW
    //                         mem_byte_en = 4'b1111;
    //                         mem_wr_data = rs2_data;
    //                     end
    //                     default: ;
    //                 endcase
    //             end
    //             OP_R: begin
    //                 alu_op_b = rs2_data;
    //                 if (funct7 == 7'b0000001) begin
    //                     // Handle M extension
    //                     case (funct3)
    //                         3'b000:  alu_op = ALU_MUL;
    //                         3'b001:  alu_op = ALU_MULH;
    //                         3'b010:  alu_op = ALU_MULHSU;
    //                         3'b011:  alu_op = ALU_MULHU;
    //                         3'b100:  alu_op = ALU_DIV;
    //                         3'b101:  alu_op = ALU_DIVU;
    //                         3'b110:  alu_op = ALU_REM;
    //                         3'b111:  alu_op = ALU_REMU;
    //                         default;
    //                     endcase
    //                 end else begin
    //                     case (funct3)
    //                         3'b000:  alu_op = (funct7 == 7'b0100000) ? ALU_SUB : ALU_ADD;
    //                         3'b001:  alu_op = ALU_SLL;
    //                         3'b010:  alu_op = ALU_SLT;
    //                         3'b011:  alu_op = ALU_SLTU;
    //                         3'b100:  alu_op = ALU_XOR;
    //                         3'b101:  alu_op = (funct7 == 7'b0100000) ? ALU_SRA : ALU_SRL;
    //                         3'b110:  alu_op = ALU_OR;
    //                         3'b111:  alu_op = ALU_AND;
    //                         default: ;
    //                     endcase
    //                 end
    //                 rs_wr_en   = 1;
    //                 rs_wr_data = alu_result;
    //             end
    //             OP_I_MEM, OP_JALR, OP_I_ALU: begin
    //                 imm = {{20{instruction[31]}}, instruction[31:20]};
    //                 case (opcode)
    //                     OP_I_MEM: begin
    //                         // Drive load address; writeback deferred to S_LOAD_WB
    //                         mem_addr2 = rs1_data + imm;
    //                     end
    //                     OP_JALR: begin
    //                         rs_wr_en = 1;
    //                         rs_wr_data = pc + 4;
    //                         next_pc = rs1_data + imm;
    //                     end
    //                     OP_I_ALU: begin
    //                         rs_wr_en   = 1;
    //                         rs_wr_data = alu_result;
    //                         alu_op_b   = imm;
    //                         case (funct3)
    //                             3'b000:  alu_op = ALU_ADD;
    //                             3'b010:  alu_op = ALU_SLT;
    //                             3'b011:  alu_op = ALU_SLTU;
    //                             3'b100:  alu_op = ALU_XOR;
    //                             3'b110:  alu_op = ALU_OR;
    //                             3'b111:  alu_op = ALU_AND;
    //                             3'b001:  alu_op = ALU_SLL;
    //                             3'b101: begin
    //                                 alu_op   = (funct7 == 7'b0100000) ? ALU_SRA : ALU_SRL;
    //                                 alu_op_b = {27'b0, rs2};  // SHAMT taken directly
    //                             end
    //                             default: ;
    //                         endcase
    //                     end
    //                     default: ;
    //                 endcase
    //             end
    //             OP_LUI, OP_AUI: begin
    //                 imm = {instruction[31:12], 12'b0};
    //                 rs_wr_en = 1;
    //                 rs_wr_data = (opcode == OP_LUI) ? imm : imm + pc;
    //             end
    //             OP_SYSTEM: begin
    //                 if (funct3 == 3'b010 && rs1_data == 32'b0) begin
    //                     rs_wr_en   = 1;
    //                     rs_wr_data = cycle_count;
    //                 end
    //             end
    //             default: ;
    //         endcase
    //     end
    //     // S_FETCH: all defaults apply — no side effects
    // end

    // always_ff @(posedge clk or negedge rst_n) begin
    //     if (!rst_n) begin
    //         pc <= 32'h0;
    //         state <= S_FETCH;
    //         load_offset <= 2'b0;
    //         cycle_count <= 32'b0;
    //     end else begin
    //         cycle_count <= cycle_count + 1;
    //         case (state)
    //             S_FETCH: state <= S_EXEC;
    //             S_EXEC: begin
    //                 if (opcode == OP_I_MEM) begin
    //                     // Load needs one more cycle for BRAM data
    //                     state <= S_LOAD_WB;
    //                     load_offset <= mem_addr2[1:0];
    //                 end else begin
    //                     state <= S_FETCH;
    //                     pc <= next_pc;
    //                 end
    //             end
    //             S_LOAD_WB: begin
    //                 state <= S_FETCH;
    //                 pc <= next_pc;  // pc + 4
    //             end
    //             default: state <= S_FETCH;
    //         endcase
    //     end
    // end


endmodule
