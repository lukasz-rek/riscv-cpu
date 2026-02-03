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
    OP_LOAD_UPPER = 7'b0110111,
    OP_ADD_UPPER  = 7'b0010111,
    OP_JAL        = 7'b1101111,
    OP_BRANCH     = 7'b1100011,
    OP_JALR       = 7'b1100111,
    OP_MEM_LOAD   = 7'b0000011,
    OP_I_REG_SH   = 7'b0010011,
    OP_MEM_STR    = 7'b0100011,
    OP_I_REG2     = 7'b0110011,
    OP_FENCE      = 7'b0001111,
    OP_CALL_BREAK = 7'b1110011
  } opcode_t;

  typedef enum logic [2:0] {
    BEQ,
    BNE,
    BLT,
    BGE,
    BLTU,
    BGEU
  } branch_cond_t;

  typedef enum logic [2:0] {
    ALU_SRC_PC,
    ALU_SRC_RS2,
    ALU_SRC_IMM,
    ALU_SRC_SHAMT,
    ALU_SRC_PC_IMM  // Special case for AUIPC
  } alu_src_t;

endpackage
