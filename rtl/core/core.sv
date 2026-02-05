module core (
    input  logic        clk,
    input  logic        rst_n,
    // Memory interface
    output logic [31:0] mem_addr1,
    output logic [31:0] mem_addr2,
    output logic        mem_wr_en,
    output logic [31:0] mem_wr_data,
    output logic [31:0] mem_wr_addr,
    input  logic [31:0] mem_rd_data1,
    input  logic [31:0] mem_rd_data2,
    output logic [ 3:0] mem_byte_en
);
  logic [31:0] instruction;
  logic [31:0] pc, next_pc;

  logic [ 6:0] opcode;
  logic [ 4:0] rd;
  logic [ 4:0] rs1;
  logic [ 4:0] rs2;
  logic [ 2:0] funct3;
  logic [ 6:0] funct7;
  logic [20:0] imm;

  // Control signals
  /*
    write to pc
    I auipc, adds immediate to pc
    II branch, jump
    branch_condition
    I when to write to pc
    load_memory
    I load memory to some register
    write_memory
    I write register to memory

    1st alu src is always rs1
    2nd alu src might be immediate or rs2

    reg_write
    rs2_immediate
    alu_op

  */

  // 1st: Fetch
  assign instruction = mem_rd_data1;
  assign mem_addr1 = pc;

  // 2nd: Decode
  assign opcode = instruction[6:0];
  assign funct3 = instruction[14:12];
  assign funct7 = instruction[31:25];
  assign rd = instruction[11:7];
  assign rs1 = instruction[19:15];
  assign rs2 = instruction[24:20];

  // General control signals
  logic [31:0] mem_mask;


  // ALU signals and instance
  logic [31:0] alu_op_a;
  logic [31:0] alu_op_b;
  alu_op_t alu_op;
  logic [31:0] alu_result;
  logic alu_zero;
  alu alu_inst (
      .a(alu_op_a),
      .b(alu_op_b),
      .alu_op(alu_op),
      .result(alu_result),
      .zero(alu_zero)
  );

  // Register file signals and instance
  logic [31:0] rs1_data;
  logic [31:0] rs2_data;
  logic rs_wr_en;
  logic [31:0] rs_wr_data;
  register_file regfile_inst (
      .clk(clk),
      .rst_n(rst_n),
      .rs1_addr(rs1),
      .rs2_addr(rs2),
      .rs1_data(rs1_data),
      .rs2_data(rs2_data),
      .wr_en(rs_wr_en),
      .wr_addr(rd),
      .wr_data(rs_wr_data)
  );


  // Immediate assigned based on instr type

  always_comb begin
    rs_wr_en  = 0;
    mem_wr_en = 0;

    alu_op_a  = rs1_data;
    next_pc   = pc + 4;
    case (opcode)
      OP_B: begin
        imm = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
        alu_op_b = rs2_data;
        case (funct3)
          BNE, BEQ:   alu_op = ALU_SUB;
          BLT, BGT:   alu_op = ALU_SLT;
          BLTU, BGTU: alu_op = ALU_SLTU;
        endcase
        // For operations set above, these results mean branching
        case (funct3)
          BNE, BLT, BLTU: branch_taken = (alu_result != 32'b0) ? 1'b1 : 0'b1;
          BEQ, BGT, BGTU: branch_taken = (alu_result == 32'b0) ? 1'b1 : 0'b1;
        endcase
        if (branch_taken == 1'b1) begin
          next_pc = pc + imm;
        end
      end
      OP_J: begin
        imm = {
          {12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0
        };
        rs_wr_en = 1;
        rs_wr_data = pc + 4;
        next_pc = pc + imm;
      end
      OP_S: begin
        mem_wr_en = 1;
        imm = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
        alu_op = ALU_ADD;
        alu_op_b = imm;
        mem_wr_addr = alu_result;
        case (funct3)
          // byte, halfword, word
          3'b000: mem_byte_en = 4'b0001;
          3'b001: mem_byte_en = 4'b0011;
          3'b010: mem_byte_en = 4'b1111;
        endcase
        mem_wr_data = rs2_data;
      end
      OP_R: begin
        alu_op_b = rs2_data;
        case (funct3)
          3'b000: alu_op = (funct7 == 7'b0100000) ? ALU_SUB : ALU_ADD;
          3'b001: alu_op = ALU_SLL;
          3'b010: alu_op = ALU_SLT;
          3'b011: alu_op = ALU_SLTU;
          3'b100: alu_op = ALU_XOR;
          3'b101: alu_op = (funct7 == 7'b0100000) ? ALU_SRA : ALU_SRL;
          3'b110: alu_op = ALU_OR;
          3'b111: alu_op = ALU_AND;
        endcase
        rs_wr_en   = 1;
        rs_wr_data = alu_result;
      end
      OP_I_MEM, OP_JALR, OP_I_ALU: begin
        imm = {{20{instruction[31]}}, instruction[31:20]};
        rs_wr_en = 1;
        case (opcode)
          OP_I_MEM: begin
            mem_addr2 = rs1_data + imm;
            case (funct3)
              3'b000: rs_wr_data = {{24{mem_rd_data2[7]}}, mem_rd_data2[7:0]};
              3'b001: rs_wr_data = {{16{mem_rd_data2[15]}}, mem_rd_data2[15:0]};
              3'b010: rs_wr_data = mem_rd_data2;
              3'b100: rs_wr_data = {24'b0, mem_rd_data2[7:0]};
              3'b101: rs_wr_data = {16'b0, mem_rd_data2[15:0]};
            endcase
          end
          OP_JALR: begin
            rs_wr_data = pc + 4;
            next_pc = rs1_data + imm;
          end
          OP_I_ALU: begin
            rs_wr_data = alu_result;
            case (funct3)
              3'b000: alu_op = ALU_ADD;
              3'b010: alu_op = ALU_SLT;
              3'b011: alu_op = ALU_SLTU;
              3'b100: alu_op = ALU_XOR;
              3'b110: alu_op = ALU_OR;
              3'b111: alu_op = ALU_AND;
              3'b001: alu_op = ALU_SLL;
              3'b101: begin
                alu_op   = (funct7 == 7'b0100000) ? ALU_SRA : ALU_SRL;
                alu_op_b = rs2;  // SHAMT taken directly
              end
            endcase
          end
        endcase
      end
      OP_LUI, OP_AUI: begin
        imm = {instruction[31:12], 12'b0};
        rs_wr_en = 1;
        rs_wr_data = (opcode == OP_LUI) ? imm : imm + pc;
      end
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc <= 32'h0;
    end else begin
      pc <= next_pc;

    end
  end


endmodule
