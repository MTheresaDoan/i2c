module i2c_master
  (
    input  logic clk_i, //global clock
    input  logic _rst_i, //global active low reset
    input  logic start_ms_i, // master start control from interface
    input  logic [23:0] data_i, //data from interface
    inout  wire sda_io, //global sda
    output logic scl_o, //global scl
    output logic [7:0] data_o, //data to interface
    output logic rxdone_o //rxready
  );
  logic txdone;
  logic sda_tx;
  logic sda_rx;
  logic sel_sda;
  logic rx_read;
  i2c_tx  i2c_tx_inst (
            .clk_i(clk_i),
            ._rst_i(_rst_i),
            .start_tx(start_ms_i),
            .datatx_i(data_i),
            .sda_sel_o(sel_sda),
            .sda_o(sda_tx),
            .scl_o(scl_o),
            .rxread_o(rx_read)
          );

  i2c_rx  i2c_rx_inst (
            .sda_i(sda_rx),
            .scl_i(scl_o),
            .clk_i(clk_i),
            ._rst_i(_rst_i),
            .rx_en_i(sel_sda),
            .rx_read_i(rx_read),
            .rxdone_o(rxdone_o),
            .rx_o(data_o)
          );

  sel_sda  sel_sda_inst (
             .sel_sda_i(sel_sda),
             .sda_tx_i(sda_tx),
             .sda_rx_o(sda_rx),
             .sda_io(sda_io)
           );

endmodule
