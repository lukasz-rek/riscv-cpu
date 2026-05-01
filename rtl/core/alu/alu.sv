/* verilator lint_off IMPORTSTAR */
import core_pkg::*;
/* verilator lint_on IMPORTSTAR */


module alu (
    input clk,
    input rst_n,

    input  logic    [31:0] a,
    input  logic    [31:0] b,
    input  alu_op_t        alu_op,
    output logic    [31:0] result,
    output logic           zero,
    output                 alu_active,
    output                 alu_result_en
);

    logic signed [32:0] a_q, b_q;
    logic signed [32:0] a_ext, b_ext;
    always_comb begin
        unique case (alu_op)
            ALU_MUL, ALU_MULH: begin a_ext = {a[31], a}; b_ext = {b[31], b}; end
            ALU_MULHSU:        begin a_ext = {a[31], a}; b_ext = {1'b0,  b}; end
            ALU_MULHU:         begin a_ext = {1'b0,  a}; b_ext = {1'b0,  b}; end
            default:           begin a_ext = '0;         b_ext = '0;         end
        endcase
        unique case (alu_op)
                ALU_MULH, ALU_MULHU, ALU_MULHSU: mul_out = mul_4[63:32];
                default:                          mul_out = mul_4[31:0];
            endcase
    end


    logic [63:0] mul_1, mul_2, mul_3, mul_4;
    logic [31:0] mul_out;

    logic [ 2:0] stage_counter_q;

    logic [31:0] comb_result;
    always_comb begin
        case (alu_op)
            ALU_ADD: comb_result = a + b;
            ALU_SUB: comb_result = a - b;
            ALU_AND: comb_result = a & b;
            ALU_XOR: comb_result = a ^ b;
            ALU_OR:  comb_result = a | b;
            // For shifts in slli, srli etc, only 5 bits used
            ALU_SLL: comb_result = a << b[4:0];
            ALU_SRL: comb_result = a >> b[4:0];
            ALU_SRA: comb_result = $signed(a) >>> b[4:0];

            // Signed comparisions
            ALU_SLT:  comb_result = {31'b0, $signed(a) < $signed(b)};
            ALU_SLTU: comb_result = {31'b0, a < b};

            // M extension ops
            // ALU_MUL: comb_result = ($signed(a) * $signed(b));  // Only keeps lowest so fine
            // ALU_MULH: comb_result = 32'((64'($signed(a)) * 64'($signed(b))) >> 32);
            // ALU_MULHSU: comb_result = 32'((64'($signed(a)) * 64'(b)) >> 32);
            // ALU_MULHU: comb_result = 32'((64'(a) * 64'(b)) >> 32);
            ALU_MUL, ALU_MULH, ALU_MULHSU, ALU_MULHU: comb_result = mul_out;
            default: comb_result = 32'h0;
        endcase
    end

    assign zero   = (result == 32'h0);
    assign result = comb_result;


    logic alu_mul;
    assign alu_mul = (alu_op == ALU_MUL) || (alu_op == ALU_MULH)
    || (alu_op == ALU_MULHSU) || (alu_op == ALU_MULHU);

    assign alu_active = alu_mul;
    assign alu_result_en = (!alu_mul || (stage_counter_q == 3'd5));

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            mul_1 <= '0; mul_2 <= '0; mul_3 <= '0; mul_4 <= '0;
            stage_counter_q <= '0;
        end else begin
            if (alu_mul) begin
                a_q <= a_ext;
                b_q <= b_ext;
                mul_1 <=  64'(a_q * b_q);
                mul_2 <= mul_1;
                mul_3 <= mul_2;
                mul_4 <= mul_3;
                stage_counter_q <= (stage_counter_q == 3'd5) ? '0 : stage_counter_q + 3'd1;
            end
        end
    end
endmodule
