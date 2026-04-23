/* verilator lint_off IMPORTSTAR */
import core_pkg::*;
/* verilator lint_on IMPORTSTAR */

module register_file #(
    parameter int XLEN = 32  // size of register
) (
    input logic clk,
    input logic rst_n,

    // Reading
    input  logic [     4:0] rs1_addr,
    input  logic [     4:0] rs2_addr,
    input  logic [     4:0] rs1_id_addr,
    output logic [XLEN-1:0] rs1_data,
    output logic [XLEN-1:0] rs2_data,
    output logic [XLEN-1:0] rs1_id_data,

    // Forwarding
    /* verilator lint_off UNUSEDSIGNAL */
    input ctrl_signals_t mem_forward_result,
    input ctrl_signals_t rf_forward_result,
    input ctrl_signals_t exec_forward_result,
    /* verilator lint_on UNUSEDSIGNAL */

    // Writing
    input logic            wr_en,
    input logic [     4:0] wr_addr,
    input logic [XLEN-1:0] wr_data
);
    logic [XLEN-1:0] registers[31:0];



    // Reading can be combinational for now
    always_comb begin

        // RS1
        if (mem_forward_result.rd == rs1_addr && rs1_addr != '0 && mem_forward_result.rf_wr_en ) begin
            rs1_data = mem_forward_result.rf_wr_data;
        end else if (rf_forward_result.rd == rs1_addr && rs1_addr != '0 && rf_forward_result.rf_wr_en) begin
            rs1_data = rf_forward_result.rf_wr_data;
        end else begin
            rs1_data = registers[rs1_addr];
        end

        // RS2
        if (mem_forward_result.rd == rs2_addr && rs2_addr != '0 && mem_forward_result.rf_wr_en ) begin
            rs2_data = mem_forward_result.rf_wr_data;
        end else if (rf_forward_result.rd == rs2_addr && rs2_addr != '0 && rf_forward_result.rf_wr_en) begin
            rs2_data = rf_forward_result.rf_wr_data;
        end else begin
            rs2_data = registers[rs2_addr];
        end

        // RS1 used in decode for JALR, needs to include lookahead from exec
        // Skip loads (ALU_MEM_ADDR_READ) — their rf_wr_data is 0, actual value
        // isn't available until writeback. Decode stalls JALR for the extra cycle.
        if (exec_forward_result.rd == rs1_id_addr && rs1_id_addr != '0 && exec_forward_result.rf_wr_en
            && exec_forward_result.rf_writeback != ALU_MEM_ADDR_READ) begin
            rs1_id_data = exec_forward_result.rf_wr_data;
        end else if (mem_forward_result.rd == rs1_id_addr && rs1_id_addr != '0 && mem_forward_result.rf_wr_en
            && mem_forward_result.rf_writeback != ALU_MEM_ADDR_READ) begin
            rs1_id_data = mem_forward_result.rf_wr_data;
        end else if (rf_forward_result.rd == rs1_id_addr && rs1_id_addr != '0 && rf_forward_result.rf_wr_en) begin
            rs1_id_data = rf_forward_result.rf_wr_data;
        end else begin
            rs1_id_data = registers[rs1_id_addr];
        end



    end

    // Writing
    always_ff @(posedge clk) begin : writeRegister
        if (!rst_n) begin
            for (int i = 0; i < 32; i++) registers[i] <= '0;
        end else if (wr_en && wr_addr != 0)
            // No writes to 0
            registers[wr_addr] <= wr_data;
    end
endmodule
