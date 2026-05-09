
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


endpackage
;
