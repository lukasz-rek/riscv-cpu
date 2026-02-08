// Monitors memory for a done flag and transmits the result as hex over UART.
// Sends: "RES:XXXXXXXX\r\n" where X is the 32-bit result in hex.
module result_sender #(
    parameter DONE_MAGIC = 32'hDEADBEEF
) (
    input  logic        clk,
    input  logic        rst_n,
    // Memory read port (directly reads BRAM)
    input  logic [31:0] done_val,
    input  logic [31:0] result_val,
    // UART
    output logic [7:0]  tx_data,
    output logic        tx_send,
    input  logic        tx_busy
);

  typedef enum logic [2:0] {
    WAIT_DONE,
    SEND_PREFIX,
    SEND_HEX,
    SEND_CR,
    SEND_LF,
    FINISHED
  } state_t;

  state_t       state;
  logic [31:0]  result_reg;
  logic [3:0]   char_idx;    // 0..3 for prefix "RES:", 0..7 for hex digits
  logic         send_next;

  // "RES:" prefix
  function automatic logic [7:0] prefix_char(input logic [1:0] idx);
    case (idx)
      2'd0: return "R";
      2'd1: return "E";
      2'd2: return "S";
      2'd3: return ":";
    endcase
  endfunction

  // Convert nibble to ASCII hex
  function automatic logic [7:0] hex_char(input logic [3:0] nibble);
    return (nibble < 10) ? (8'h30 + {4'b0, nibble}) : (8'h41 + {4'b0, nibble} - 8'd10);
  endfunction

  // Pick nibble from result (MSB first): idx 0 = bits[31:28], idx 7 = bits[3:0]
  wire [3:0] current_nibble = result_reg[31 - char_idx*4 -: 4];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= WAIT_DONE;
      result_reg <= '0;
      char_idx   <= '0;
      tx_data    <= '0;
      tx_send    <= 1'b0;
      send_next  <= 1'b0;
    end else begin
      tx_send <= 1'b0;

      case (state)
        WAIT_DONE: begin
          if (done_val == DONE_MAGIC) begin
            result_reg <= result_val;
            state      <= SEND_PREFIX;
            char_idx   <= '0;
            send_next  <= 1'b1;
          end
        end

        SEND_PREFIX: begin
          if (send_next && !tx_busy) begin
            tx_data   <= prefix_char(char_idx[1:0]);
            tx_send   <= 1'b1;
            send_next <= 1'b0;
          end else if (!tx_send && !tx_busy && !send_next) begin
            if (char_idx == 3) begin
              char_idx  <= '0;
              state     <= SEND_HEX;
              send_next <= 1'b1;
            end else begin
              char_idx  <= char_idx + 1;
              send_next <= 1'b1;
            end
          end
        end

        SEND_HEX: begin
          if (send_next && !tx_busy) begin
            tx_data   <= hex_char(current_nibble);
            tx_send   <= 1'b1;
            send_next <= 1'b0;
          end else if (!tx_send && !tx_busy && !send_next) begin
            if (char_idx == 7) begin
              state     <= SEND_CR;
              send_next <= 1'b1;
            end else begin
              char_idx  <= char_idx + 1;
              send_next <= 1'b1;
            end
          end
        end

        SEND_CR: begin
          if (send_next && !tx_busy) begin
            tx_data   <= 8'h0D;
            tx_send   <= 1'b1;
            send_next <= 1'b0;
          end else if (!tx_send && !tx_busy && !send_next) begin
            state     <= SEND_LF;
            send_next <= 1'b1;
          end
        end

        SEND_LF: begin
          if (send_next && !tx_busy) begin
            tx_data   <= 8'h0A;
            tx_send   <= 1'b1;
            send_next <= 1'b0;
          end else if (!tx_send && !tx_busy && !send_next) begin
            state <= FINISHED;
          end
        end

        FINISHED: begin
          // Stay here — done
        end

        default: state <= FINISHED;
      endcase
    end
  end

endmodule
