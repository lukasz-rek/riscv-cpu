module core (
    input  logic        clk,
    input  logic        rst_n,
    // Memory interface
    output logic [31:0] mem_addr1,
    output logic [31:0] mem_addr2,
    output logic        mem_wr_en,
    output logic [31:0] mem_wr_data,
    input  logic [31:0] mem_rd_data1,
    input  logic [31:0] mem_rd_data2,
    output logic [ 3:0] mem_byte_en
);
  logic [31:0] instruction;
  logic [31:0] pc, next_pc;

  logic [6:0] opcode;
  logic [4:0] rd;
  logic [4:0] rs1;
  logic [4:0] rs2;
  logic [2:0] funct3;
  logic [6:0] funct7;
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

  logic pc_write;
  branch_cond_t branch_condition;
  logic mem_write;
  logic reg_write;
  logic mem_load;
  logic pc_save;
  logic [31:0] load_mask;
  logic load_sext;
  alu_op_t alu_op;
  alu_src_t alu_src;


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
  // Immediate assigned based on instr type

  always_comb begin
    // Defaults:
    mem_write = 0;
    mem_load = 0;
    
    case (opcode)
      // LUI
      OP_LUI: begin
        reg_write = 1;
        // TODO: read imm
      end
      // AUIPC
      OP_ADD_UPPER: begin
        pc_write = 1;
        pc_save  = 1;
        // TODO: read imm
      end
      // JAL
      OP_JAL: begin
        pc_write = 1;
        alu_op   = ALU_ADD;
        alu_src  = ALU_SRC_PC;
      end
      // All branches
      OP_BRANCH: begin
        case (funct3)
          3'b000: branch_condition = BEQ;
          3'b001: branch_condition = BNE;
          3'b100: branch_condition = BLT;
          3'b101: branch_condition = BGE;
          3'b110: branch_condition = BLTU;
          3'b111: branch_condition = BGEU;
        endcase
      end
      // JALR
      OP_JALR: begin
        pc_write  = 1;
        reg_write = 1;
        pc_save   = 1;
        alu_src   = ALU_SRC_PC_IMM;
        // add immediate + reg, save ret
      end
      OP_MEM_LOAD: begin
        mem_load = 1;
        alu_src  = ALU_SRC_IMM;
        // Loading bytes
        if ((funct3 == 3'b000) || (funct3 == 3'b100)) begin
          load_mask = {24'b0, 8'b1};
        end
        // Loading halfwords
        if ((funct3 == 3'b001) || (funct3 == 3'b101)) begin
          load_mask = {16'b0, 16'b1};
        end
        // Needing sext
        if ((funct3 == 3'b100) || (funct3 == 3'b101)) begin
          load_sext = 1'b1;
        end
      end
      OP_I_REG_SH: begin
        reg_write = 1;
        if ((funct3 == 3'b001) || (funct3 == 3'b101)) begin
          alu_src = ALU_SRC_SHAMT;
        end else alu_src = ALU_SRC_IMM;
        /// TODO: read imm
        case (funct3)
          3'b000: alu_op = ALU_ADD;
          3'b010: alu_op = ALU_SLT;
          3'b011: alu_op = ALU_SLTU;
          3'b100: alu_op = ALU_XOR;
          3'b110: alu_op = ALU_OR;
          3'b111: alu_op = ALU_AND;
          3'b001: alu_op = ALU_SLL;
          3'b101: alu_op = (funct7 == 7'b0100000) ? ALU_SRA : ALU_SRL;
        endcase

      end
      OP_MEM_STR: begin
        mem_write = 1;

      end
      OP_I_REG2: begin

      end
    endcase
    
  end

  // 3rd Execute

  // 4th Write to memory

  // 5th Write to regfile



  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc <= 32'h0;
    end else begin
      pc <= next_pc;
      
    end
  end


endmodule
