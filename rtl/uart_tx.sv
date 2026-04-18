module uart_tx #(
    parameter CLK_FREQ   = 95_000_000,
    parameter BAUD       = 115200,
    parameter UART_ADDR  = 32'h000_10000,
    parameter FIFO_DEPTH = 64
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [ 7:0] data,
    input  logic        uart_en,
    input  logic [31:0] mem_wr_addr,      // Used to snoop on writes
    output logic        tx,
    output logic        fifo_almost_full
);

    // UART operations
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD;
    localparam CNT_WIDTH = $clog2(CLKS_PER_BIT);
    localparam PTR_W = $clog2(FIFO_DEPTH);

    typedef enum logic [1:0] {
        IDLE,
        START,
        DATA,
        STOP
    } state_t;

    state_t                            state;
    logic   [$clog2(CLKS_PER_BIT)-1:0] clk_cnt;
    logic   [                     2:0] bit_idx;
    logic   [                     7:0] shift_reg;

    // UART FIFO
    logic   [                     7:0] fifo      [FIFO_DEPTH];
    logic [PTR_W:0] wr_ptr, rd_ptr;  // extra bit for full/empty detection

    wire fifo_empty = (wr_ptr == rd_ptr);
    wire fifo_push = uart_en && (mem_wr_addr == UART_ADDR);
    wire [PTR_W:0] fifo_count = wr_ptr - rd_ptr;

    assign fifo_almost_full = (fifo_count >= FIFO_DEPTH - 1);
    // assign fifo_full = (wr_ptr[PTR_W-1:0] == rd_ptr[PTR_W-1:0]) && (wr_ptr[PTR_W] != rd_ptr[PTR_W]);


    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state     <= IDLE;
            tx        <= 1'b1;
            clk_cnt   <= '0;
            bit_idx   <= '0;
            shift_reg <= '0;
            wr_ptr    <= '0;
            rd_ptr    <= '0;
        end else begin
            // FIFO

            if (fifo_push) begin
                fifo[wr_ptr[PTR_W-1:0]] <= data;
                wr_ptr <= wr_ptr + 1;
            end
            // UART states
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    if (!fifo_empty) begin
                        shift_reg <= fifo[rd_ptr[PTR_W-1:0]];
                        rd_ptr    <= rd_ptr + 1;
                        state     <= START;
                        clk_cnt   <= '0;
                        // synthesis translate_off
                        $write("%c", fifo[rd_ptr[PTR_W-1:0]]);
                        // synthesis translate_on
                    end
                end

                START: begin
                    tx <= 1'b0;
                    if (clk_cnt == CNT_WIDTH'(CLKS_PER_BIT - 1)) begin
                        clk_cnt <= '0;
                        bit_idx <= '0;
                        state   <= DATA;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                DATA: begin
                    tx <= shift_reg[bit_idx];
                    if (clk_cnt == CNT_WIDTH'(CLKS_PER_BIT - 1)) begin
                        clk_cnt <= '0;
                        if (bit_idx == 7) begin
                            state <= STOP;
                        end else begin
                            bit_idx <= bit_idx + 1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                STOP: begin
                    tx <= 1'b1;
                    if (clk_cnt == CNT_WIDTH'(CLKS_PER_BIT - 1)) begin
                        state   <= IDLE;
                        clk_cnt <= '0;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end
            endcase
        end
    end

endmodule
