
package csr_pkg;

    typedef enum logic [1:0] {
        U_MODE,  // User
        S_MODE,  // Supervisor
        R_MODE,  // Reserved
        M_MODE   // Machine
    } csr_privilege_t;



    // CSR definitions
    typedef struct packed {
        logic [1:0]  mxl;
        logic [3:0]  zero;
        logic [25:0] extensions;
    } misa_t;

    typedef struct packed {
        logic sd;
        logic [5:0] wpri_3;
        logic sdt;
        logic spelp;
        logic tsr;
        logic tw;
        logic tvm;
        logic mxr;
        logic sum;
        logic mprv;
        logic [1:0] xs;
        logic [1:0] fs;
        logic [1:0] mpp;
        logic [1:0] vs;
        logic spp;
        logic mpie;
        logic ube;
        logic spie;
        logic wpri_2;
        logic mie;
        logic wpri_1;
        logic sie;
        logic wpri_0;
    } mstatus_t;

    typedef struct packed {
        logic [20:0] wpri_2;
        logic mdt;
        logic mpelp;
        logic wpri_1;
        logic mpv;
        logic gva;
        logic mbe;
        logic sbe;
        logic [3:0] wpri_0;
    } mstatush_t;

    typedef struct packed {
        logic [29:0] base;
        logic [1:0]  mode;
    } mtvec_t;

    typedef struct packed {logic [31:0] isr;} mie_t;

    typedef struct packed {logic [31:0] isr;} mip_t;

    typedef struct packed {logic [31:0] pc;} mepc_t;

    typedef struct packed {
        logic isr;
        logic [30:0] code;
    } mcause_t;

    localparam CAUSE_ISR = 1'b1;
    localparam CAUSE_TRAP = 1'b0;

    typedef enum logic [31:0] {
        M_SOFTWARE_ISR = {CAUSE_ISR, 31'd3},
        INSTR_ADDR_MALIGN = {CAUSE_TRAP, 31'd0},
        INSTR_ACCESS_FAULT = {CAUSE_TRAP, 31'd1},
        ILLEGAL_INSTR = {CAUSE_TRAP, 31'd2},
        BREAKPOINT = {CAUSE_TRAP, 31'd3},
        LOAD_ADDR_MALIGN = {CAUSE_TRAP, 31'd4},
        LOAD_ACCESS_FAULT = {CAUSE_TRAP, 31'd5},
        U_CALL = {CAUSE_TRAP, 31'd8},
        S_CALL = {CAUSE_TRAP, 31'd9},
        M_CALL = {CAUSE_TRAP, 31'd11},
        DOUBLE_TRAP = {CAUSE_TRAP, 31'd16}
    } isr_cause_t;

    typedef struct packed {logic [31:0] scratch;} mscratch_t;

    typedef struct packed {logic [31:0] value;} mtval_t;



endpackage
