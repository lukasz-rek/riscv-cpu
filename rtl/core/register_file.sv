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
    output logic [XLEN-1:0] rs1_data,
    output logic [XLEN-1:0] rs2_data,
    // Used to indicate whether forwarded things are oki
    output logic            rs1_valid,
    output logic            rs2_valid,

    // Forwarding basically snooping what mem and rf have rn
    /* verilator lint_off UNUSEDSIGNAL */
    input ctrl_signals_t mem_forward_result,
    // input ctrl_signals_t rf_forward_result,
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
        if (exec_forward_result.rd == rs1_addr && rs1_addr != '0 && exec_forward_result.rf_wr_en) begin
            rs1_data  = exec_forward_result.rf_wr_data;
            rs1_valid = exec_forward_result.rf_wr_data_valid;
        end else if (mem_forward_result.rd == rs1_addr && rs1_addr != '0 && mem_forward_result.rf_wr_en) begin
            rs1_data  = mem_forward_result.rf_wr_data;
            rs1_valid = mem_forward_result.rf_wr_data_valid;
        end else begin
            rs1_data  = registers[rs1_addr];
            rs1_valid = 1;
        end

        // RS2
        if (exec_forward_result.rd == rs2_addr && rs2_addr != '0 && exec_forward_result.rf_wr_en) begin
            rs2_data  = exec_forward_result.rf_wr_data;
            rs2_valid = exec_forward_result.rf_wr_data_valid;
        end else if (mem_forward_result.rd == rs2_addr && rs2_addr != '0 && mem_forward_result.rf_wr_en) begin
            rs2_data  = mem_forward_result.rf_wr_data;
            rs2_valid = mem_forward_result.rf_wr_data_valid;
        end else begin
            rs2_data  = registers[rs2_addr];
            rs2_valid = 1;
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
