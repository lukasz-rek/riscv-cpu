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
    forever #1 clk = ~clk;
end

parameter int UNSIGNED_LIMIT = 20;

initial begin

    $display("Starting");

    @(posedge rst_n);
    repeat(2) @(posedge clk);


    for (logic [31:0] i = 0; i < UNSIGNED_LIMIT; i++) begin
        for (logic [31:0] j = 0; j < UNSIGNED_LIMIT; j++) begin
            @(posedge clk);
            alu_op = ALU_DIVU;
            a = i;
            b = j;
            repeat(33) @(posedge clk);
            #1;


            // --- self-check ---
            if (j == 0) begin
                // RISC-V spec: unsigned div-by-zero → all 1s
                if (result !== 32'hFFFF_FFFF)
                    $display("FAIL div-by-zero: %0d / %0d = %0h (expected FFFFFFFF)",
                             i, j, result);
            end else
                if (result !== (i / j)) begin
                    $display("FAIL: %0d / %0d = %0h (expected %0h)",
                             i, j, result, i / j);
            end else begin
                $display("PASS: %0d / %0d = %0d", a, b, result);
            end
        end
    end

    $display("Unsigned division sweep done.");
    $finish;
end

// Optional: waveform dump
initial begin
    $dumpfile("logs/div_tb.fst");
    $dumpvars(0, div_tb);
end

endmodule
