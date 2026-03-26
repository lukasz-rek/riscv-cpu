/* verilator lint_off IMPORTSTAR */
import core_pkg::*;
/* verilator lint_on IMPORTSTAR */

typedef enum logic [1:0] {
    DIV_OFF,
    MID,
    FINAL
} div_states_t;


module division_alu (
    input clk,
    input rst_n,

    input logic [31:0] a,
    input logic [31:0] b,
    input alu_op_t alu_op,

    output logic [31:0] result,
    output logic result_en
);
    /*
        Performs nonrestoring division. Needs at most 32 cycles + 1 for adjusting sign at the end.
        It it's unsigned, it's simple, for unsigned we gotta try some BSD tricks

        1 - When correct alu_op gets set then
            * Load d and its negative from op_b
            * Load z into remainder latch as it will be our working variable
            * Check for overflow
        2 - Middle round 1-32:

        3 - Final 33:
            * Reset counter
            * Correct remaineder if needed
            * output

        z = (d * q) + s
    */
    logic signed [64:0] remainder;  // s, but this is also the working sum;
    logic signed [64:0] remainder_q;

    logic signed [64:0] divisor;  // d
    logic signed [64:0] divisor_n;

    // logic [31:0] dividend; // z
    logic [31:0] quotient_q;

    // 1 means we subtract which is the initial operation
    logic quotient_digit;
    logic quotient_digit_q;

    // We need 32 cycles of ops + 2 for adjustments
    logic [5:0] state_count;
    logic running;
    logic signed_op;
    logic overflow;

    // State signals for easier decisions
    logic MIDDLE;
    logic zero_detected;

    // Internal variables for readability
    logic [64:0] rem_shifted;


    assign MIDDLE = state_count < 33 && state_count > 0;

    assign running = (alu_op == ALU_DIVU || alu_op == ALU_REMU
        || alu_op == ALU_DIV || alu_op == ALU_REM) ? 1 : 0;

    assign signed_op = (alu_op == ALU_DIV || alu_op == ALU_REM);


    always_latch begin
        if (state_count == 0) zero_detected = 0;
        else if (remainder == 0 && MIDDLE) zero_detected = 1;
        if (running && !signed_op && state_count == 0) begin
            divisor   = {1'b0, b, 32'b0};
            divisor_n = (divisor ^ '1) + 1;
            overflow  = (b == '0);
        end else if (running && signed_op && state_count == 0) begin
            divisor   = {b[31], b, 32'b0};
            divisor_n = (divisor ^ '1) + 1;
            // Only when dividing over zero or lowest negative number over -1
            overflow  = (b == '0 || (a == 32'h8000_0000 && b == '1));
        end
    end

    always_comb begin
        result_en = 0;
        result = '0;
        remainder = '0;
        quotient_digit = 0;
        rem_shifted = '0;
        if (running && signed_op) begin
            result_en = 0;
            if (MIDDLE && !overflow) begin

                rem_shifted = remainder_q << 1;
                quotient_digit = (rem_shifted[64] == divisor[64]);
                remainder = (rem_shifted[64] == divisor[64]) ? rem_shifted + divisor_n : rem_shifted + divisor;
            end else begin
                result_en = 1;
                if (overflow) result = (alu_op == ALU_REM) ? a : '1;
                else if (alu_op == ALU_DIV) begin
                    // Conversion needed for quotient if sign(r) != sign(z) + some exceptions
                    if ((remainder_q[64] != a[31] || zero_detected) && remainder_q != '0) begin
                        if (remainder_q[64] == b[31]) begin
                            result = (quotient_q << 1) + 2;
                        end else begin
                            result = (quotient_q << 1);
                        end
                    end else begin
                        result = (quotient_q << 1) + 1;
                    end
                end else begin
                    // Conversion needed for remainder
                    if ((remainder_q[64] != a[31] || zero_detected) && remainder_q != '0) begin
                        if (remainder_q[64] == b[31]) begin
                            result = 32'(64'(remainder_q + divisor_n) >> 32);
                        end else begin
                            result = 32'(64'(remainder_q + divisor) >> 32);
                        end
                    end else begin
                        result = 32'(64'(remainder_q) >> 32);
                    end
                end
            end

        end else if (running) begin
            result_en = 0;
            if (MIDDLE && !overflow) begin
                // Middle
                remainder = (quotient_digit_q) ? (remainder_q << 1) + divisor_n : (remainder_q << 1) + divisor;
                quotient_digit = (remainder >= 0);
            end else begin
                // Output result and reset
                result_en = 1;
                if (overflow) result = (alu_op == ALU_REMU) ? a : '1;
                else if (alu_op == ALU_DIVU) result = quotient_q;
                else
                    result = ($signed(
                        remainder_q[63:32]
                    ) >= 0) ? remainder_q[63:32] : remainder_q[63:32] + b;

            end
        end else begin

        end
    end


    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state_count <= '0;
            quotient_digit_q <= '1;
            remainder_q <= '0;
            quotient_q <= '0;
        end else if (running) begin
            state_count <= state_count + 1;
            if (state_count == 0) begin
                remainder_q <= (signed_op) ? {{33{a[31]}}, a} : {33'b0, a};
                quotient_digit_q <= '1;
                quotient_q <= '0;
            end else if (MIDDLE) begin
                quotient_digit_q <= quotient_digit;
                quotient_q <= {quotient_q[30:0], quotient_digit};
                remainder_q <= remainder;
            end else begin
                state_count <= 0;
            end
        end

    end

endmodule
