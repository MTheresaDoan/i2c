module sel_sda
(
	input sel_sda_i,
	input sda_tx_i,
	output logic sda_rx_o, //data to rx_i
	inout  wire sda_io
);

	assign sda_io = (sel_sda_i == 1'b0) ? sda_tx_i : 1'bz; // tx control sda (output) when sel is low
	assign sda_rx_o = sda_io; 
	
endmodule