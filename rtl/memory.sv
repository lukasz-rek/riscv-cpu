module memory #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int MEM_SIZE   = 4096  // in bytes
) (
    input  logic                  clk,
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic [DATA_WIDTH-1:0] rd_data,
    input  logic [           3:0] byte_en   // for byte/halfword/word access
);

endmodule
