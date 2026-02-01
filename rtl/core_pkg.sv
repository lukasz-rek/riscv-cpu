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

endpackage
