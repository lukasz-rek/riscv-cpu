


package core_pkg;
    import csr_pkg::isr_cause_t;

    // ALU operation codes - minimal set for RV32I
    typedef enum logic [4:0] {
        ALU_OFF,  // ALU not doing anything, don't use the result during exec

        ALU_ADD,
        ALU_SUB,

        ALU_AND,
        ALU_XOR,
        ALU_OR,

        ALU_SLL,  // Shift Left logical
        ALU_SRL,
        ALU_SRA,  // Shif Right Arithmetic

        ALU_SLT,  // Set Less than
        ALU_SLTU,

        // Branching princess treatment
        ALU_BRANCH,

        // M extension ops
        ALU_MUL,
        ALU_MULH,
        ALU_MULHSU,
        ALU_MULHU,
        ALU_DIV,
        ALU_DIVU,
        ALU_REM,
        ALU_REMU

    } alu_op_t;

    typedef enum logic [2:0] {
        REG_OFF,
        REG,
        IMM,
        SHAMT  // preserve
    } rs2_source_t;

    typedef enum logic [3:0] {
        OFF,
        ALU_REG,
        ALU_MEM_ADDR_READ,
        ALU_MEM_ADDR_WRITE_B,
        ALU_MEM_ADDR_WRITE_H,
        ALU_MEM_ADDR_WRITE_W,
        ALU_PC_INCR,  // Used in few cases where we store next instr address
        ALU_JALR,
        ALU_CSR
    } rf_writeback_t;

    typedef enum logic [2:0] {
        L_OFF,
        LB,
        LH,
        LW,
        LBU,
        LHU
    } load_mask_t;




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

        // CSR stuff
        OP_SYSTEM = 7'b1110011,

        // FENCE
        OP_MISC_MEM = 7'b0001111,

        OP_LUI = 7'b0110111,
        OP_AUI = 7'b0010111
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

    typedef enum logic [2:0] {
        CSRRW  = 3'b001,
        CSRRS  = 3'b010,
        CSRRC  = 3'b011,
        CSRRWI = 3'b101,
        CSRRSI = 3'b110,
        CSRRCI = 3'b111
    } csr_type_t;

    typedef enum logic [1:0] {
        CSR_RW,
        CSR_SET,
        CSR_CLEAR
    } csr_op_t;

    typedef struct packed {
        // Register ops
        logic rf_wr_en;
        logic [31:0] rf_wr_data;
        logic rf_wr_data_valid;
        logic [4:0] rs1;
        logic [4:0] rs2;
        logic [4:0] rd;
        logic [31:0] imm;
        rs2_source_t rs2_src;

        // CSR
        logic csr_wr_en;
        logic csr_rd_en;
        logic [11:0] csr_addr;
        csr_type_t csr_type;
        csr_op_t csr_op;
        logic csr_imm;

        // Traps
        isr_cause_t trap_cause;
        logic [31:0] trap_val;
        logic trap_en;
        logic mret_en;

        // Branching
        logic branch_expects_zero;
        logic branch_instr;
        load_mask_t load_mask;

        // Store
        logic [31:0] mem_addr2;
        logic [31:0] mem_wr_addr;
        logic [31:0] mem_wr_data;
        logic mem_wr_en;
        logic [3:0] mem_byte_en;
        // Load
        logic mem_rd_en;
        logic [1:0] load_offset;
        logic rs1_forward_exec;
        logic rs2_forward_exec;
        logic mem_forward_exec;

        logic flush_I;


        // Alu
        alu_op_t alu_op;
        rf_writeback_t rf_writeback;

        // Timekeeping/Debug
        logic [6:0] opcode;
        logic [31:0] instr;
        logic [31:0] pc;  // Of instruction

    } ctrl_signals_t;
endpackage
