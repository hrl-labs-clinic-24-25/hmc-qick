//Format of waveform interface:

// mem_i
// |---------|-----|---------|---------|--------|--------|
// | 97      | 96  | 95:72   | 71:48   |  47:24	| 23:0   |
// |---------|-----|---------|---------|--------|--------|
// | trigger | mux | dac_4   |  dac_3  | dac_2  | dac_1 |
// |---------|-----|---------|---------|--------|--------|
// dac_1 	: if mux = 1, the last three bits are the values for each select mux (i.e. 6:0 for bits 23:0)
	//      : if mux = 0, 24 bits dedicated to the SPI output to be stored
// mux -- 1 if this is loading the mux values for the dacs

module ctrl (
	// Reset and clock.
	rstn			,
	clk				,

	// Memory/AXI interface.
	mem_i		,

	// save
	// dac control.
	dac_1_o		,
	dac_2_o		,
	dac_3_o		,
	dac_4_o		,

	// Output mux selection.
	mux_o			,
	
	// Output enable.
	trigger_o,
	en_o			
);

// Ports.
input					rstn;
input					clk;
input	[97:0]			mem_input_r;  // 97 bits for the data
output	[23:0]			dac_o;
output  [4:0]           mux_o;
output 					trigger_o;
output					en_o;

// wires combinational only
// Muxes.
reg [4:0]  mux_1, n_mux_1;
reg [4:0]  mux_2, n_mux_2;
reg [4:0]  mux_3, n_mux_3;
reg [4:0]  mux_4, n_mux_4;

// DAC
reg [23:0] dac_1;
reg [23:0] dac_2;
reg [23:0] dac_3;
reg [23:0] dac_4;


// Registers.
always @(posedge clk) begin
	if (~rstn) begin

		// DAC registers.
		dac_1 			<= 0;
		dac_2 			<= 0;
		dac_3 			<= 0;
		dac_4 			<= 0;

		// Muxes.
		mux_1 			<= 0;
		mux_2 			<= 0;
		mux_3 			<= 0;
		mux_4 			<= 0;

		en_o  			<= 0;
		trigger_o       <= 0;
	end
	else begin

		en_o <= 1;
		trigger <= mem_i[97];

		mux_1 <= n_mux_1;
		mux_2 <= n_mux_2;
		mux_3 <= n_mux_3;
		mux_4 <= n_mux_4;

		// load muxes
		if (mem_i[96]) begin  // set the mux values
			// DAC registers.
			dac_1 			<= 0;
			dac_2 			<= 0;
			dac_3 			<= 0;
			dac_4 			<= 0;

		end else begin
			dac_1 			<= dac_1[23:0];
			dac_2 			<= dac_2[47:24];
			dac_3 			<= dac_3[71:48];
			dac_4 			<= dac_4[95:72];

		end

	end
end 

assign n_mux_1 = mem_i[6:0];
assign n_mux_2 = mem_i[30:24];
assign n_mux_3 = mem_i[56:48];
assign n_mux_4 = mem_i[78:72];

assign dac_1_o = dac_1;
assign dac_2_o = dac_2;
assign dac_3_o = dac_3;
assign dac_4_o = dac_4;


endmodule

