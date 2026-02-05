package core_pkg;


  // ALU operation codes - minimal set for RV32I
  typedef enum logic [3:0] {
    ALU_ADD,
    ALU_SUB,

    ALU_AND,
    ALU_XOR,
    ALU_OR,

    ALU_SLL,  // Shift Left logical
    ALU_SRL,
    ALU_SRA,  // Shif Right Arithmetic

    ALU_SLT,  // Set Less than
    ALU_SLTU
  } alu_op_t;


  typedef enum logic [6:0] {
    // All based on https://www.vicilogic.com/static/ext/RISCV/RV32I_BaseInstructionSet.pdf
    OP_B     = 7'b1100011,
    OP_J     = 7'b1101111,
    OP_S     = 7'b0100011,
    OP_R     = 7'b0110011,
    // 3 below handled together
    OP_I_MEM = 7'b0000011,
    OP_JALR  = 7'b1100111,
    OP_I_ALU = 7'b0010011,

    OP_LUI  = 7'b0110111,
    OP_AUI  = 7'b0010111,
    OP_FENC = 7'b0001111,
    OP_CALL = 7'b1110011
  } opcode_t;

  typedef enum logic [2:0] {
    // Equals funct3 of BRANCH
    BEQ  = 3'b000,
    BNE  = 3'b001,
    BLT  = 3'b100,
    BGE  = 3'b101,
    BLTU = 3'b110,
    BGEU = 3'b111
  } branch_cond_t;


endpackage
