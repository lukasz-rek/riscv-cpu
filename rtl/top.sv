module top #(
    parameter INIT_FILE = ""
) (
    input  logic        clk,
    input  logic        rst_n,
    output logic        uart_tx
);

  // Memory interface signals
  logic [31:0] mem_addr1;
  logic [31:0] mem_addr2;
  logic        mem_wr_en;
  logic [31:0] mem_wr_data;
  logic [31:0] mem_wr_addr;
  logic [31:0] mem_rd_data1;
  logic [31:0] mem_rd_data2;
  logic [ 3:0] mem_byte_en;

  // Instantiate core
  (* dont_touch = "true" *) core cpu (
      .clk(clk),
      .rst_n(rst_n),
      .mem_addr1(mem_addr1),
      .mem_addr2(mem_addr2),
      .mem_wr_en(mem_wr_en),
      .mem_wr_data(mem_wr_data),
      .mem_wr_addr(mem_wr_addr),
      .mem_rd_data1(mem_rd_data1),
      .mem_rd_data2(mem_rd_data2),
      .mem_byte_en(mem_byte_en)
  );

  // Instantiate memory
  (* dont_touch = "true" *) memory #(
      .INIT_FILE(INIT_FILE)
  ) bram_mem (
      .clk(clk),
      .addr1(mem_addr1),
      .addr2(mem_addr2),
      .wr_en(mem_wr_en),
      .wr_data(mem_wr_data),
      .wr_addr(mem_wr_addr),
      .rd_data1(mem_rd_data1),
      .rd_data2(mem_rd_data2),
      .byte_en(mem_byte_en)
  );

  // ── UART result output ──
  // Snoop memory write bus to capture result and done flag
  // Result at byte addr 0x1000 (word 1024), done at 0x1004 (word 1025)
  localparam RESULT_WORD_ADDR = 32'h0000_1000;
  localparam DONE_WORD_ADDR   = 32'h0000_1004;

  logic [31:0] result_val;
  logic [31:0] done_val;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result_val <= '0;
      done_val   <= '0;
    end else if (mem_wr_en) begin
      if (mem_wr_addr == RESULT_WORD_ADDR)
        result_val <= mem_wr_data;
      if (mem_wr_addr == DONE_WORD_ADDR)
        done_val <= mem_wr_data;
    end
  end

  logic [7:0] tx_data;
  logic       tx_send;
  logic       tx_busy;

  result_sender result_out (
      .clk(clk),
      .rst_n(rst_n),
      .done_val(done_val),
      .result_val(result_val),
      .tx_data(tx_data),
      .tx_send(tx_send),
      .tx_busy(tx_busy)
  );

  uart_tx #(
      .CLK_FREQ(95_000_000),
      .BAUD(115200)
  ) uart (
      .clk(clk),
      .rst_n(rst_n),
      .data(tx_data),
      .send(tx_send),
      .tx(uart_tx),
      .busy(tx_busy)
  );

endmodule
