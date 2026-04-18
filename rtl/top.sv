
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
    logic [1:0] byte_counter;
    logic uart_en;
    logic fifo_full;


    // Memory signals
    logic [31:0] addr_d;
    logic [31:0] wr_addr;
    logic [31:0] wr_data;
    logic wr_en;
    logic rd_en_d;
    logic [31:0] rd_data_d;
    logic [31:0] rd_data_i;
    logic stall_D;
    logic stall_I;




    axi_master #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .START_ADDR(36'h8_4000_0000)
    ) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .addr_i   (32'h0),
        .addr_d   (addr_d),
        .wr_addr  (wr_addr),
        .wr_data  (wr_data),
        .byte_en  (4'hF),
        .wr_en    (wr_en),
        .rd_en_i  (1'b0),
        .rd_en_d  (rd_en_d),
        .rd_data_i(rd_data_i),
        .rd_data_d(rd_data_d),
        .stall_I  (stall_I),
        .stall_D  (stall_D),
        .m_axi    (m_axi)
    );

    typedef enum logic [2:0] {
        UART_OFF,
        UART_START_READ,
        UART_READ,
        UART_BYTES
    } state_t;

    state_t state;
    logic [31:0] latch_data;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            addr_d <= '0;
            rd_en_d <= '0;
            latch_data <= '0;
            state <= UART_OFF;
            byte_counter <= '0;
        end else begin
            uart_en <= 0;
            case (state)
                UART_OFF: begin
                    state   <= UART_START_READ;
                    rd_en_d <= 1;
                end
                UART_START_READ: begin
                    state <= UART_START_READ;
                    if (!stall_D) begin
                        // If no stall, then await data on next cycle
                        rd_en_d <= 0;
                        state   <= UART_READ;
                    end
                end
                UART_READ: begin
                    latch_data <= rd_data_d;
                    addr_d <= (addr_d == 32'h3FFF_FFFF) ? '0 : addr_d + 4;
                    state <= UART_BYTES;
                end
                UART_BYTES: begin
                    if (!fifo_full) begin
                        uart_en <= 1;
                        byte_counter <= byte_counter + 1;
                        case (byte_counter)
                            2'd0: out_data <= latch_data[7:0];
                            2'd1: out_data <= latch_data[15:8];
                            2'd2: out_data <= latch_data[23:16];
                            2'd3: out_data <= latch_data[31:24];
                        endcase
                        state <= (byte_counter == 2'd3) ? UART_OFF : UART_BYTES;
                    end
                end
                default: ;
            endcase
        end
    end


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
        .fifo_almost_full(fifo_full)
    );

endmodule
