/* verilator lint_off IMPORTSTAR */
import core_pkg::*;
/* verilator lint_on IMPORTSTAR */

module fetch (
    input logic clk,
    input logic rst_n,

    input logic [31:0] mem_instr_data,
    input logic [31:0] id_next_pc,
    input logic id_next_pc_en,
    input logic stall,

    output logic [31:0] id_instr_data,
    output logic [31:0] id_instr_pc,

    output logic mem_enable,
    output logic [31:0] mem_instr_addr
);

    logic [31:0] pc;
    logic [31:0] prev_pc;
    logic valid;
    // logic [31:0] next_pc;
    /*
Very simple idea
We just set instructions for next cycle and pass along one we have now.
Sometimes we might want to have diff next_pc (stalls, BTB) and ID can override
*/
    assign mem_instr_addr = (id_next_pc_en) ? id_next_pc : pc;
    assign id_instr_data = (valid) ? mem_instr_data : '0;
    assign id_instr_pc = prev_pc;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            pc <= 0;
            valid <= 0;
            prev_pc <= 0;
            mem_enable <= 0;
        end else begin
            mem_enable <= 1;
            pc <= (id_next_pc_en) ? id_next_pc + 4 : pc + 4;
            valid <= (stall) ? 0 : 1;
            prev_pc <= mem_instr_addr;
        end
    end


endmodule
