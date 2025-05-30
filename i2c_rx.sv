module i2c_rx
  (
    input logic sda_i,
    input logic scl_i,
    input logic clk_i,
    input logic _rst_i,
    input logic rx_en_i,
    input logic rx_read_i,
    output logic rxdone_o,
    output logic [7:0] rx_o
  );
  logic [7:0] temp, n_temp;
  logic rising;
  logic scl_t;
  logic [1:0] state, n_state;
  logic [2:0] bcount, n_bcount;

  assign rising = (~scl_t & scl_i);
  localparam IDLE = 0,
             CAPTURE = 1,
             STOP =2;
  always_comb
  begin
    rxdone_o = 0;
    n_temp = temp;
    n_state = state;
    n_bcount = bcount;
    case(state)
      IDLE:
      begin
        if (rx_read_i&&rx_en_i)
        begin
          n_state = CAPTURE;
          n_bcount = 0;
        end
        else
          n_state = IDLE;
      end
      CAPTURE:
      begin
        if (rising)
        begin
          n_temp = {temp[6:0], sda_i};
          if (bcount == 7)
          begin
            n_state = STOP;
            n_bcount = 0;
          end
          else
          begin
            n_state = CAPTURE;
            n_bcount = bcount + 1;
          end
        end
      end
      STOP:
      begin
        n_state = IDLE;
        rxdone_o = 1;
      end
    endcase
  end
  always_ff @(posedge clk_i)
  begin
    if (!_rst_i)
    begin
      state <= IDLE;
      temp  <= 8'b0;
      bcount <= 3'b0;
      scl_t <= 0;
      rx_o  <= 0;
    end
    else
    begin
      scl_t <= scl_i;
      state <= n_state;
      temp  <= n_temp;
      bcount <= n_bcount;
      rx_o  <= (state == STOP) ? n_temp : 0;
    end
  end

endmodule
