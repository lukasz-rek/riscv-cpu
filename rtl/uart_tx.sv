module uart_tx #(
    parameter CLK_FREQ = 95_000_000,
    parameter BAUD     = 115200
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [7:0] data,
    input  logic       send,
    output logic       tx,
    output logic       busy
);

  localparam CLKS_PER_BIT = CLK_FREQ / BAUD;
  localparam CNT_WIDTH = $clog2(CLKS_PER_BIT);

  typedef enum logic [1:0] {
    IDLE,
    START,
    DATA,
    STOP
  } state_t;

  state_t        state;
  logic [$clog2(CLKS_PER_BIT)-1:0] clk_cnt;
  logic [2:0]    bit_idx;
  logic [7:0]    shift_reg;

  assign busy = (state != IDLE);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      tx        <= 1'b1;
      clk_cnt   <= '0;
      bit_idx   <= '0;
      shift_reg <= '0;
    end else begin
      case (state)
        IDLE: begin
          tx <= 1'b1;
          if (send) begin
            shift_reg <= data;
            state     <= START;
            clk_cnt   <= '0;
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
