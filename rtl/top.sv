
module top #(
    // parameter INIT_FILE = "code/build/program.hex"
    // parameter INIT_FILE = "code/coremark/build/coremark.hex"
) (
    input logic clk,
    input logic rst_n,

    axi_if.master m_axi,
    output logic uart_tx
);


    // UART
    localparam UART_ADDR = 32'h000_10000;
    logic [7 : 0] out_data;
    logic uart_en;
    logic fifo_full;
    // AXI
    typedef enum logic [2:0] {
        S_INIT,
        S_AR,   // Send Addr
        S_R,    // Wait for data
        S_UART, // Give to uart, if fifo full wait
        S_DONE,
        S_OFF
    } state_t;

    localparam START_ADDR = 36'h8_4000_0000;
    localparam END_ADDR = 36'h8_4000_0040; // 4 words

    state_t state;
    logic [35:0] addr;
    logic [31:0] rdata_buf;
    logic [1:0] byte_idx;
    logic [23:0] timeout;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_en <= 0;
            out_data <= '0;
            rdata_buf <= '0;
            addr <= START_ADDR;
            state <= S_INIT;
            byte_idx <= '0;
            timeout <= '0;
        end else begin
            uart_en <= 1'b0;

            case (state)
            S_INIT: begin
                timeout <= '0;
                state <= S_AR;
            end
            S_AR: begin
                if (m_axi.arready) begin
                    state <= S_R;
                    timeout <= '0;
                end else begin
                    timeout <= timeout + 1;
                    if (timeout[23]) begin
                        out_data <= 8'h42; // 'B'
                        uart_en <= 1;
                        state <= S_OFF;
                    end
                end
            end
            S_R: begin
                if (m_axi.rvalid) begin
                    rdata_buf <= m_axi.rdata;
                    byte_idx <= '0;
                    state <= S_UART;
                    timeout <= '0;
                end else begin
                    timeout <= timeout + 1;
                    if (timeout[23]) begin
                        out_data <= 8'h43; // 'C'
                        uart_en <= 1;
                        state <= S_OFF;
                    end
                end
            end
                S_UART: begin
                    // Send byte, increment if possible
                    if (!fifo_full) begin
                        uart_en <= 1;
                        case(byte_idx)
                            2'd0: out_data <= rdata_buf[7:0];
                            2'd1: out_data <= rdata_buf[15:8];
                            2'd2: out_data <= rdata_buf[23:16];
                            2'd3: out_data <= rdata_buf[31:24];
                        endcase
                        if (byte_idx < 2'd3) begin
                            byte_idx <= byte_idx + 1;
                        end else begin
                            // We're done, loop back but check if we're not DONE
                            addr <= addr + 16;
                            if ((addr + 16) < END_ADDR) begin
                                state <= S_AR;
                            end else begin
                                state <= S_OFF;
                            end
                        end
                    end
                    // Otherwise wait for FIFO to bless us
                end
                S_DONE: begin
                    if (!fifo_full) begin
                        uart_en <= 1;
                        out_data <= 8'h61;
                        state <= S_OFF;
                    end
                end
                S_OFF: begin
                    // CHIlL
                end

            endcase
        end
    end

    // ── AXI AR channel ──
        assign m_axi.araddr  = addr;
        assign m_axi.arlen   = 8'd0;          // single beat
        assign m_axi.arsize  = 3'b010;        // 4 bytes
        assign m_axi.arburst = 2'b01;         // INCR (don't-care for len=0)
        assign m_axi.arlock  = 1'b0;
        assign m_axi.arcache = 4'b0011;       // normal non-cacheable bufferable
        assign m_axi.arprot  = 3'b000;
        assign m_axi.arvalid = (state == S_AR);
        assign m_axi.arid    = '0;
        assign m_axi.arqos   = '0;
        assign m_axi.aruser  = 1'b0;

        // ── AXI R channel ──
            assign m_axi.rready  = (state == S_R);

    // ── Tie off AXI write channels (unused) ──
       assign m_axi.awaddr  = '0;
       assign m_axi.awlen   = '0;
       assign m_axi.awsize  = '0;
       assign m_axi.awburst = '0;
       assign m_axi.awlock  = 1'b0;
       assign m_axi.awcache = '0;
       assign m_axi.awprot  = '0;
       assign m_axi.awvalid = 1'b0;
       assign m_axi.awid    = '0;
       assign m_axi.awqos   = '0;
       assign m_axi.awuser  = 1'b0;
       assign m_axi.wdata   = '0;
       assign m_axi.wstrb   = '0;
       assign m_axi.wlast   = 1'b0;
       assign m_axi.wvalid  = 1'b0;
       assign m_axi.bready  = 1'b1;

    uart_tx #(
        .CLK_FREQ(58_000_000),
        .BAUD(115200)
    ) uart (
        .clk(clk),
        .rst_n(rst_n),
        .data(out_data),
        .tx(uart_tx),
        .uart_en(uart_en),  // this can only trigger if we're writing to MMIO
        .mem_wr_addr(UART_ADDR),
        .fifo_full(fifo_full)
    );

endmodule
