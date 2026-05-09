/* verilator lint_off IMPORTSTAR */
import csr_pkg::*;
/* verilator lint_on IMPORTSTAR */

module csr_regfile (
    input logic clk,
    input logic rst_n,

    input logic [11 : 0] csr_addr,
    input logic csr_rd_en,
    input logic csr_wr_en,

    input  logic [31:0] csr_wr_data,
    output logic [31:0] csr_rd_data,

    // Rest of information
    input logic minstret_incr
);

    // Decode addr
    logic current_csr_read_only;
    csr_privilege_t current_csr_priv_bits;

    assign current_csr_read_only = (csr_addr[11:10] == 2'b11);
    assign current_csr_priv_bits = csr_privilege_t'(csr_addr[9:8]);

    // State
    csr_privilege_t privilege;

    // CSRs
    localparam misa_t MISA_VALUE = '{
        mxl: 2'b01,  // RV32
        zero: 4'b0,
        extensions:
        26'h0 | (
        1 << 8
        )  // I
        | (
        1 << 12
        )  // M
    };  // misa
    logic [63:0] mcycle;
    logic [63:0] minstret;

    // Reads + sanitize
    always_comb begin
        if (!csr_rd_en && !csr_wr_en) begin
            ;  // Do nothing
        end else if (current_csr_priv_bits > privilege) begin
            // TODO: throw exception
        end else if (current_csr_read_only && csr_wr_en) begin
            // TODO: throw exception
        end else begin

            case (csr_addr)
                // Machine Information Registers
                // Machine Trap Setup
                12'h301: csr_rd_data = MISA_VALUE;
                // Machine Counters/Timers
                12'hC00, 12'hC01: csr_rd_data = mcycle[31:0];
                12'hC80, 12'hC81: csr_rd_data = mcycle[63:32];
                12'hC02: csr_rd_data = minstret[31:0];
                12'hC82: csr_rd_data = minstret[63:32];
                default: ;
            endcase

        end

    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            // Zero all CSRs
            mcycle <= '0;
            minstret <= '0;
            privilege <= M_MODE;
        end else begin
            mcycle   <= mcycle + 1;
            minstret <= (minstret_incr) ? minstret + 1 : minstret;
            if (csr_wr_en) begin

            end
        end
    end

endmodule
