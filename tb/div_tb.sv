module div_tb;

/* verilator lint_off IMPORTSTAR */
import core_pkg::*;
/* verilator lint_on IMPORTSTAR */

logic clk;
logic rst_n;

logic [31:0] a;
logic [31:0] b;
alu_op_t alu_op;
logic [31:0] result;

division_alu dut (
.clk(clk),
.rst_n(rst_n),
.a(a),
.b(b),
.alu_op(alu_op),
.result(result)
);

initial begin
    rst_n = 0;
    repeat(5) @(posedge clk);
    rst_n = 1;
end

initial begin
    clk = 0;
    forever #2 clk = ~clk;
end

parameter int UNSIGNED_LIMIT = 1000;

initial begin

    $display("Starting");

    @(posedge rst_n);
    repeat(2) @(posedge clk);


    for (logic [31:0] i = 0; i < UNSIGNED_LIMIT; i++) begin
        for (logic [31:0] j = 0; j < UNSIGNED_LIMIT; j++) begin
            @(posedge clk);
            #1;
            alu_op = ALU_DIVU;
            a = i;
            b = j;
            repeat(33) @(posedge clk);
            // Let it settle
            #1;

            // --- self-check ---
            if (j == 0) begin
                // RISC-V spec: unsigned div-by-zero → all 1s
                if (result !== 32'hFFFF_FFFF) begin
                    $display("FAIL div-by-zero: %0d / %0d = %0h (expected FFFFFFFF)",
                             i, j, result);
                    i = UNSIGNED_LIMIT + 1;
                    j = UNSIGNED_LIMIT + 1;
                end
            end else
                if (result !== (i / j)) begin
                    $display("FAIL: %0d / %0d = %0h (expected %0h)",
                             i, j, result, i / j);
                    i = UNSIGNED_LIMIT + 1;
                    j = UNSIGNED_LIMIT + 1;
            end
        end
    end

    $display(" ====== Unsigned division SUCCESS!!. ====== ");

    for (logic [31:0] i = 0; i < UNSIGNED_LIMIT; i++) begin
        for (logic [31:0] j = 0; j < UNSIGNED_LIMIT; j++) begin
            @(posedge clk);
            #1;
            alu_op = ALU_REMU;
            a = i;
            b = j;
            repeat(33) @(posedge clk);
            // Let it settle
            #1;

            // --- self-check ---
            if (j == 0) begin
                // RISC-V spec: unsigned div-by-zero → all 1s
                if (result !== a) begin
                    $display("FAIL div-by-zero: %0d / %0d = %0h (expected %0d)",
                             i, j, result, i);
                    i = UNSIGNED_LIMIT + 1;
                    j = UNSIGNED_LIMIT + 1;
                end
            end else
                if (result !== (i % j)) begin
                    $display("FAIL: %0d / %0d = %0h (expected %0h)",
                             i, j, result, i % j);
                    i = UNSIGNED_LIMIT + 1;
                    j = UNSIGNED_LIMIT + 1;
            end
        end
    end

    @(posedge clk);

    $display(" ====== Unsigned remainder SUCCESS!!. ====== ");
    $finish;
end

// Optional: waveform dump
// initial begin
//     $dumpfile("logs/div_tb.fst");
//     $dumpvars(0, div_tb);
// end

endmodule
