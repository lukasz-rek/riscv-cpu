/* verilator lint_off IMPORTSTAR */
import core_pkg::*;
/* verilator lint_on IMPORTSTAR */

module fetch (
    input logic clk,
    input logic rst_n,

    input logic [31:0] mem_instr_data,
    input logic [31:0] next_pc,
    input logic next_pc_en,

    output logic [31:0] id_instr_data,
    output logic [31:0] id_instr_pc,

    output logic [31:0] mem_instr_addr
);

    logic [31:0] pc;

    /*
Very simple idea
We just set instructions for next cycle and pass along one we have now.
Sometimes we might want to have diff next_pc (stalls, BTB) and ID can override
*/

    assign id_instr_data = mem_instr_data;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 0;
        end else begin
            id_instr_pc   <= pc;
            if (next_pc_en) begin
                // ID override active
                pc <= next_pc;
            end else begin
                // Normal operation
                pc <= pc + 4;
            end

            mem_instr_addr <= pc + 4;
        end

    end


endmodule
