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
  logic [31:0] bram_rd_data2;

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
      .rd_data2(bram_rd_data2),
      .byte_en(mem_byte_en)
  );

  // ── UART with TX FIFO ──
  // Store to UART_ADDR pushes low byte into a 16-entry FIFO.
  // FIFO drains into uart_tx automatically.
  localparam UART_ADDR = 32'h000_10000;
  localparam FIFO_DEPTH = 64;
  localparam PTR_W = $clog2(FIFO_DEPTH);

  logic [7:0] fifo [FIFO_DEPTH];
  logic [PTR_W:0] wr_ptr, rd_ptr;  // extra bit for full/empty detection

  wire fifo_empty = (wr_ptr == rd_ptr);
  wire fifo_full  = (wr_ptr[PTR_W-1:0] == rd_ptr[PTR_W-1:0]) &&
                    (wr_ptr[PTR_W]      != rd_ptr[PTR_W]);
  wire fifo_push  = mem_wr_en && (mem_wr_addr == UART_ADDR);

  // Read mux: return FIFO busy status when CPU reads from UART_ADDR
  // Delay the select by one cycle to match BRAM read latency
  logic uart_rd_sel;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      uart_rd_sel <= 1'b0;
    else
      uart_rd_sel <= (mem_addr2 == UART_ADDR);
  end

  assign mem_rd_data2 = uart_rd_sel ? {31'b0, fifo_full} : bram_rd_data2;

  // Push into FIFO on CPU write
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      wr_ptr <= '0;
    else if (fifo_push) begin
      fifo[wr_ptr[PTR_W-1:0]] <= mem_wr_data[7:0];
      wr_ptr <= wr_ptr + 1;
    end
  end

  // Pop from FIFO and feed uart_tx
  logic [7:0] tx_data;
  logic       tx_send;
  logic       tx_busy;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rd_ptr  <= '0;
      tx_send <= 1'b0;
    end else begin
      tx_send <= 1'b0;
      if (!fifo_empty && !tx_busy && !tx_send) begin
        tx_data <= fifo[rd_ptr[PTR_W-1:0]];
        tx_send <= 1'b1;
        rd_ptr  <= rd_ptr + 1;
      end
    end
  end

  uart_tx #(
      .CLK_FREQ(90_909_091),
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
