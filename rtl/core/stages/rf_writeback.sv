/* verilator lint_off IMPORTSTAR */
import core_pkg::*;
/* verilator lint_on IMPORTSTAR */

module rf_writeback (
    output logic rf_wr_en,
    output logic [5:0] wr_addr,
    output logic [31:0] wr_data,
    input logic [31:0] mem_read,
    /* verilator lint_off UNUSEDSIGNAL */
    input ctrl_signals_t in_ctrl_signals,
    /* verilator lint_on UNUSEDSIGNAL */
    output ctrl_signals_t current_ctrl_signals
);

    assign rf_wr_en = in_ctrl_signals.rf_wr_en && in_ctrl_signals.rf_wr_data_valid;
    assign wr_addr  = in_ctrl_signals.rd;

    always_comb begin
        wr_data = '0;
        if (in_ctrl_signals.rf_writeback == ALU_MEM_ADDR_READ) begin
            if (in_ctrl_signals.reservation_type == RESERVATION_STORE) begin
                wr_data = in_ctrl_signals.rf_wr_data;  // Propagate sc.w result
            end else begin
                case (in_ctrl_signals.load_mask)
                    LB:
                    case (in_ctrl_signals.mem_addr2[1:0])
                        2'd0: wr_data = {{24{mem_read[7]}}, mem_read[7:0]};
                        2'd1: wr_data = {{24{mem_read[15]}}, mem_read[15:8]};
                        2'd2: wr_data = {{24{mem_read[23]}}, mem_read[23:16]};
                        2'd3: wr_data = {{24{mem_read[31]}}, mem_read[31:24]};
                    endcase
                    LH:
                    case (in_ctrl_signals.mem_addr2[1])
                        1'b0: wr_data = {{16{mem_read[15]}}, mem_read[15:0]};
                        1'b1: wr_data = {{16{mem_read[31]}}, mem_read[31:16]};
                    endcase
                    LW: wr_data = mem_read;
                    LBU:
                    case (in_ctrl_signals.mem_addr2[1:0])
                        2'd0: wr_data = {24'b0, mem_read[7:0]};
                        2'd1: wr_data = {24'b0, mem_read[15:8]};
                        2'd2: wr_data = {24'b0, mem_read[23:16]};
                        2'd3: wr_data = {24'b0, mem_read[31:24]};
                    endcase
                    LHU:
                    case (in_ctrl_signals.mem_addr2[1])
                        1'b0: wr_data = {16'b0, mem_read[15:0]};
                        1'b1: wr_data = {16'b0, mem_read[31:16]};
                    endcase

                    default: ;
                endcase
            end
        end else begin
            wr_data = in_ctrl_signals.rf_wr_data;
        end
        current_ctrl_signals = in_ctrl_signals;
        current_ctrl_signals.rf_wr_data = wr_data;
    end


endmodule
