module i2c_tx
  //////////// standard mode 100KHz////////////////
  (
    input logic       clk_i,  //clk 1MHz
    input logic       _rst_i, //reset tích cực thấp
    input logic       start_tx,
    input logic [23:0] datatx_i,
    output logic      sda_sel_o, //nếu lên 1 thì nghĩa là đã gửi xong 1 byte, trả lại sda cho rx nhận ack
    output logic      sda_o,
    output logic      scl_o,
    output logic      rxread_o
  );
  /// khai báo biến nội ///
  logic [7:0] tcount, n_tcount; //đếm thời gian chờ 5us
  logic sda, scl; //control sda, scl
  logic [4:0] state, n_state; //biến trạng thái
  logic [7:0] breg, n_breg, add_slave_w, add_reg, data;  //biến dữ liệu cần gửi đi
  logic [1:0] bytecount, n_bytecount; // đếm số byte đã nhận được
  logic [2:0] bcount, n_bcount; // đếm số bit đã nhận được
  logic [2:0] temp_bcount; // Thanh ghi trung gian cho pipeline
  logic sda_sel; //control sda_sel
  /// khai báo hằng số
  assign {add_slave_w, add_reg, data} = datatx_i;
  assign rxread_o = (datatx_i[23:17] == datatx_i[7:1]) && (~datatx_i[16] && datatx_i[0]);

  localparam IDLE        = 0,     // trạng thái đệm, reset vào trạng thái này
             START_SDA   = 1,
             START_SCL   = 2,
             DATA        = 3,
             HOLD_DATA   = 4,
             ACK_ADD_SLAVE= 5,
             HOLD_ACK     = 6,
             HOLD         = 7,
             PREP_START   = 8,
             REPEAT_START = 9,
             READ         = 10,
             HOLD_READ    = 11,
             NACK         = 12,
             HOLD_NACK    = 13,
             STOP         = 14,
             HOLD_STOP    = 15;

  /// khai báo trạng thái ////
  always_comb
  begin
    n_tcount = tcount;
    n_state = IDLE;
    n_bcount = bcount;
    n_bytecount = bytecount;
    n_breg = breg;
    sda = sda_o;
    scl = scl_o;
    sda_sel = sda_sel_o; // tx control sda
    case (state)
      IDLE:
      begin
        scl = 1'bz;
        sda = 1'bz;
        n_state = (start_tx) ? START_SDA : IDLE;
        n_tcount = 0; //start timer
        sda_sel = 1;
      end
      START_SDA:
      begin
        sda = 0; //start condition
        sda_sel = 0; //tx control sda
        if (tcount == 59)
        begin
          n_tcount = 0; //if 5us pass, reset timer
          n_breg   = add_slave_w; //prepare data to transfer
          n_state = START_SCL;
        end
        else
        begin
          n_tcount = tcount + 1;   // hold sda for 5us
          n_state  = START_SDA;
        end
      end
      START_SCL:
      begin
        scl = 0;
        sda = 0;
        if (tcount == 59)
        begin
          n_state  = DATA; //begin transfer data
          n_tcount = 0; //start timer
          n_bcount = 0; //start count bit
          n_bytecount = 0; // start count byte
        end
        else
        begin
          n_state  = START_SCL;
          n_tcount = tcount + 1;
        end
      end
      DATA:
      begin
        sda = breg[7];
        scl = 0;
        sda_sel = 0;
        if (tcount == 59)
        begin
          n_state = HOLD_DATA;
          n_tcount = 0;
        end
        else
        begin
          n_state = DATA;
          n_tcount = tcount + 1;
        end
      end
      HOLD_DATA:
      begin
        scl = 1;
        if (tcount == 59)
        begin
          if (bcount == 7) //receive 8 bit
          begin
            n_tcount = 0;
            n_state = ACK_ADD_SLAVE; //wait ack to confirm address slave
          end
          else
          begin
            n_tcount = 0;
            n_state = DATA;
            n_bcount = temp_bcount; // Dùng temp_bcount đã pipeline
            n_breg = breg << 1;
          end
        end
        else
        begin
          n_state = HOLD_DATA;
          n_tcount = tcount + 1;
        end
      end
      ACK_ADD_SLAVE:
      begin
        scl = 0;
        sda_sel = 1;
        if (tcount == 59)
        begin
          n_tcount = 0; //reset timer to hold scl
          n_state = HOLD_ACK;
        end
        else
        begin
          n_state = ACK_ADD_SLAVE;
          n_tcount = tcount + 1;
        end
      end
      HOLD_ACK:
      begin
        n_bcount = 0;
        scl = 1;
        sda_sel = 1; //release sda to receive ack
        if (tcount == 59)
        begin
          n_state = HOLD;
          n_bytecount = bytecount + 1;
          n_tcount = 0;
        end
        else
        begin
          n_state = HOLD_ACK;
          n_tcount = tcount + 1;
        end
      end
      HOLD:
      begin
        scl = 0;
        sda_sel = 1;
        if (tcount == 120)
        begin
          n_tcount = 0;
          n_breg = data;
          if (bytecount == 2)
          begin
            n_tcount = 0;
            if (rxread_o)
              n_state = PREP_START;
            else
              n_state = DATA;
          end
          else if (bytecount == 3)
          begin
            n_tcount = 0;
            if (rxread_o)
              n_state = READ;
            else
              n_state = HOLD_STOP;
          end
          else
          begin
            n_state = DATA;
            n_breg = add_reg;
          end
        end
        else
        begin
          n_tcount = tcount + 1;
          n_state = HOLD;
        end
      end
      PREP_START:
      begin
        scl = 1;
        sda_sel = 1;
        if (tcount > 1)
          sda_sel = 0;
        if (tcount == 59)
        begin
          n_state = REPEAT_START;
          n_tcount = 0;
        end
        else
        begin
          n_state = PREP_START;
          n_tcount = tcount + 1;
        end
      end
      REPEAT_START:
      begin
        sda = 0;
        if (tcount == 59)
        begin
          n_state = DATA;
          n_breg = data;
          n_tcount = 0;
        end
        else
        begin
          n_state = REPEAT_START;
          n_tcount = tcount + 1;
        end
      end
      READ:
      begin
        sda_sel = 1;
        scl = 1;
        if (tcount == 59)
        begin
          n_state = HOLD_READ;
          n_tcount = 0;
        end
        else
        begin
          n_state = READ;
          n_tcount = tcount + 1;
        end
      end
      HOLD_READ:
      begin
        sda_sel = 1;
        scl = 0;
        if (bcount == 7)
          sda_sel = 0;
        if (tcount == 59)
        begin
          if (bcount == 7)
          begin
            n_state = NACK;
            scl = 1;
            n_tcount = 0;
          end
          else
          begin
            n_state = READ;
            n_bcount = temp_bcount; // Dùng temp_bcount đã pipeline
            n_tcount = 0;
          end
        end
        else
        begin
          n_state = HOLD_READ;
          n_tcount = tcount + 1;
        end
      end
      NACK:
      begin
        sda_sel = 0;
        sda = 1;
        scl = 1;
        if (tcount == 59)
        begin
          n_state = HOLD_NACK;
          n_tcount = 0;
          scl = 0;
        end
        else
        begin
          n_state = NACK;
          n_tcount = tcount + 1;
        end
      end
      HOLD_NACK:
      begin
        sda = 1;
        sda_sel = 0;
        if (tcount == 59)
        begin
          n_state = STOP;
          n_tcount = 0;
          scl = 0;
          sda = 0;
        end
        else
        begin
          n_state = HOLD_NACK;
          n_tcount = tcount + 1;
        end
      end
      STOP:
      begin
        sda_sel = 0;
        if (tcount == 59)
        begin
          n_state = HOLD_STOP;
          n_tcount = 0;
          scl = 1;
          sda = 0;
        end
        else
        begin
          n_state = STOP;
          n_tcount = tcount + 1;
        end
      end
      HOLD_STOP:
      begin
        if (tcount == 59)
        begin
          scl = 1;
          sda_sel = 1;
          n_tcount = 0;
          n_state = IDLE;
        end
        else
        begin
          n_state = HOLD_STOP;
          n_tcount = tcount + 1;
        end
      end
    endcase
  end

  // Pipeline cho bcount
  always_ff @(posedge clk_i)
  begin
    if (!_rst_i)
      temp_bcount <= 0;
    else if (state == HOLD_DATA || state == HOLD_READ)
      temp_bcount <= bcount + 1; // Pipeline bcount
  end

  always_ff @(posedge clk_i)
  begin
    if (!_rst_i)
    begin
      state     <= IDLE;
      sda_o     <= 1;
      scl_o     <= 1;
      sda_sel_o <= 0;
      bytecount <= 0;
      bcount    <= 0;
      tcount    <= 0;
      breg      <= 0;
    end
    else
    begin
      state     <= n_state;
      sda_o     <= sda;
      scl_o     <= scl;
      sda_sel_o <= sda_sel;
      bytecount <= n_bytecount;
      bcount    <= n_bcount;
      tcount    <= n_tcount;
      breg      <= n_breg;
    end
  end
endmodule
