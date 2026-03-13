/* verilator lint_off IMPORTSTAR */
import core_pkg::*;
/* verilator lint_on IMPORTSTAR */

module fetch (
    input logic clk,
    input logic rst_n,

    input logic [31:0] mem_instr_data,
    input logic [31:0] id_next_pc,
    input logic id_next_pc_en,

    output logic [31:0] id_instr_data,
    output logic [31:0] id_instr_pc,

    output logic [31:0] mem_instr_addr
);

    logic [31:0] pc;
    logic [31:0] next_pc;
    /*
Very simple idea
We just set instructions for next cycle and pass along one we have now.
Sometimes we might want to have diff next_pc (stalls, BTB) and ID can override
*/

    assign next_pc = (id_next_pc_en) ? id_next_pc : pc + 4;
    assign mem_instr_addr = (rst_n) ? next_pc : 32'b0;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 0;
            id_instr_data <= 32'b0;
            id_instr_pc <= 32'b0;
        end else begin
            id_instr_pc   <= pc;
            id_instr_data <= mem_instr_data;
            pc <= next_pc;
        end

    end


endmodule
