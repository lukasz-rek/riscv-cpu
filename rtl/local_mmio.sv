module local_mmio (
    input logic clk,
    input logic rst_n,

    input logic [31:0] addr,
    input logic [31:0] wr_data,

    input logic rd_en,
    input logic wr_en,


    output logic rd_en_d,
    output logic wr_en_d,

    input logic [31:0] rd_data_d,
    output logic [31:0] rd_data,
    output logic mtime_isr,
    output logic msip_isr
);

    localparam logic [31:0] clint_base = 32'h0200_0000;

    logic [63:0] mtime;
    logic [63:0] mtimecmp;
    logic [63:0] mtimecmp_q;

    logic [31:0] mmio_rd_data;
    logic [31:0] mmio_rd_data_q;
    logic mmio_en;
    logic mmio_en_q;

    assign rd_data   = (mmio_en_q) ? mmio_rd_data_q : rd_data_d;

    assign mtime_isr = (mtime >= mtimecmp_q) ? 1 : 0;

    always_comb begin
        mmio_en = 0;
        rd_en_d = 0;
        wr_en_d = 0;
        mmio_rd_data = '0;
        mtimecmp = mtimecmp_q;
        if (rd_en || wr_en) begin
            mmio_en = 1;
            case (addr)
                clint_base: begin
                    mmio_rd_data = {31'b0, msip_isr};
                end
                clint_base + 32'h0000_4000: begin
                    // mtimecmp lo
                    if (wr_en) mtimecmp[31:0] = wr_data;
                    else mmio_rd_data = mtimecmp_q[31:0];
                end
                clint_base + 32'h0000_4004: begin
                    // mtimecmp hi
                    if (wr_en) mtimecmp[63:32] = wr_data;
                    else mmio_rd_data = mtimecmp_q[63:32];
                end
                clint_base + 32'h0000_BFF8: mmio_rd_data = mtime[31:0];
                clint_base + 32'h0000_BFFC: mmio_rd_data = mtime[63:32];
                default: begin
                    // If we didn't hit anything, pass through as normal mem access/external MMIO
                    mmio_en = 0;
                    rd_en_d = rd_en;
                    wr_en_d = wr_en;
                end
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            mtime <= '0;
            mtimecmp_q <= '1;
            mmio_en_q <= 0;
            msip_isr <= '0;
        end else begin
            mtime <= mtime + 1;
            mtimecmp_q <= mtimecmp;
            mmio_en_q <= mmio_en;
            mmio_rd_data_q <= mmio_rd_data;
            msip_isr <= (addr == clint_base && wr_en) ? wr_data[0] : msip_isr;
        end
    end

endmodule
