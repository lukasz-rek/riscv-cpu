module memory #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int MEM_DEPTH  = 16384,  // 32-bit words → 64KB total
    parameter     INIT_FILE  = ""
) (
    input  logic                  clk,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [ADDR_WIDTH-1:0] addr1,
    input  logic [ADDR_WIDTH-1:0] addr2,
    input  logic [ADDR_WIDTH-1:0] wr_addr,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic [DATA_WIDTH-1:0] rd_data1,
    output logic [DATA_WIDTH-1:0] rd_data2,
    input  logic [           3:0] byte_en
);

  localparam WORD_ADDR_BITS = $clog2(MEM_DEPTH);

  // Word-addressed storage — maps to true dual-port BRAM
  logic [31:0] mem[MEM_DEPTH];

  generate
    if (INIT_FILE != "") begin : gen_init
      initial $readmemh(INIT_FILE, mem);
    end
  endgenerate

  // Byte-to-word address conversion
  wire [WORD_ADDR_BITS-1:0] word_addr1 = addr1[WORD_ADDR_BITS+1:2];
  wire [WORD_ADDR_BITS-1:0] word_wr_addr = wr_addr[WORD_ADDR_BITS+1:2];

  // Port B: single address — write addr during stores, read addr otherwise
  wire [WORD_ADDR_BITS-1:0] word_addr_b = wr_en ? word_wr_addr : addr2[WORD_ADDR_BITS+1:2];

  // Port A: instruction fetch (read-only)
  always_ff @(posedge clk) begin
    rd_data1 <= mem[word_addr1];
  end

  // Port B: data load/store (read + write, one address)
  always_ff @(posedge clk) begin
    rd_data2 <= mem[word_addr_b];
    if (wr_en) begin
      if (byte_en[0]) mem[word_addr_b][7:0] <= wr_data[7:0];
      if (byte_en[1]) mem[word_addr_b][15:8] <= wr_data[15:8];
      if (byte_en[2]) mem[word_addr_b][23:16] <= wr_data[23:16];
      if (byte_en[3]) mem[word_addr_b][31:24] <= wr_data[31:24];
    end
  end

endmodule
