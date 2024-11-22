//Format of waveform interface:
// |---------|----------|---------|
// | 49  48  | 47 .. 24 | 23 .. 0 |
// |---------|----------|---------|
// |  mux    | dac_2    | dac_1   |
// |---------|----------|---------|
// mux 	    : 2 bits
// dac_2 	: 24 bits
// dac_1 	: 24 bits

// deleted: mode_int --> determines whether the output is a one shot or periodic. We are assuming "one shot" atm; we don't need a counter.
// deleted: the state machine - we aren't following the periodic/single time read idea

// need to map out timing for this block -- i'm pretty sure we just load and the raise the "en_o" flag

module ctrl (
	// Reset and clock.
	rstn			,
	clk				,

	// Memory/AXI interface.
	mem_input_i		,

	// dac control.
	dac_1_o		,
	dac_2_o		,

	// Output mux selection.
	mux_o			,
	
	// Output enable.
	en_o			);

// Ports.
input					rstn;
input					clk;
input	[49:0]			mem_input_r;
output	[23:0]			dac_1_o;
output	[23:0]			dac_2_o;
output	[2:0]			mux_o;
output					en_o;

// Input register. Only assigned when load_r is true (i.e. we're allowed to read)
reg		[49:0]	mem_input_r;

// DAC vectors.
wire	[23:0]	dac_1;
wire	[23:0]	dac_2;

// Mux Vector
wire    [1:0]   mux;

// Counter.
reg		[23:0]	cnt;

// Output enable register.
reg				en_reg;

// Registers.
always @(posedge clk) begin
	if (~rstn) begin

		// DAC registers.
		dac_1 			<= 0;
		dac_2 			<= 0;

		// Memory dout register.
		mem_input_r		<= 0;

		// Load enable flag.
		load_r			<= 0;

		// Counter.
		cnt				<= 0;

		// Output enable register.
		en_reg			<= 0;
	end
	else begin

		dac_1 		<= dac_1_int;
		dac_2		<= mem_input_r[47:0];
		mux 		<= mem_input_r[49:48];

		en_reg_r1		<= en_reg;
	end
end 

// Assigning variables
assign dac_1_int = mem_input_r[23:0];
assign dac_2_int = mem_input_r[47:0];
assign mux_int 	 = mem_input_r[49:48];
assign en_reg    = 1;

// Assigning outputs
assign dac_1_o = dac_1;
assign dac_2_o = dac_2;
assign mux_o   = mux;
assign en_reg  = en_reg;

// Assign load_int, which determines if we are loading the register or not.
// rd_en_int depends on the state originally (i.e. whether we're in READ or CNTR state; since we aren't doing periodic for now, though, we'll leave it as 1)
// assign load_int 	= rd_en_int & ~fifo_empty_i;
// READ state is entered when in reset mode, or when cnt == nsamp_int-2
// CNT  state is entered when in periodic mode and the fifo stack isn't empty
// we don't need this ability yet, so it's been removed along with the state machine

endmodule

