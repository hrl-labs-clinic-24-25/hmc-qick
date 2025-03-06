/**
	A module that runs a pvp plot generator using a Finite State Machine
	Zoe Worrall, zworrall@g.hmc.edu, March 3, 2025
*/

module pvp_fsm_gen 
    (
		// Reset and clock.
		rstn,
		clk,

		// start the fsm
        TRIGGER_PVP_REG,

		// Inputs from PYNQ registers
		START_VAL_0_REG,
		START_VAL_1_REG,
		START_VAL_2_REG,
		START_VAL_3_REG,

		DWELL_CYCLES_REG,
		STEP_SIZE_REG,
		NUM_CYCLES_REG,
		NUM_DACS_REG,
		W_REG_W,
		W_REG_X,
		W_REG_Y,
		W_REG_Z,

    	// parameter inputs.
		mosi_o,
        SELECT,
        readout_o,    // for AWG output
		trigger_spi_o  // for SPI output
	);

	/**************/
	/* Parameters */
	/**************/
	
	// Define the states for the FSM
	parameter WAIT = 4'b0000, S_SEND_0 = 4'b0001, S_SEND_1 = 4'b0010, S_SEND_2 = 4'b0100, S_SEND_3 = 4'b1000, S_WAIT = 4'b1110, S_STALL = 4'b1101;

	/*********/
	/* Ports */
	/*********/

	input rstn;
	input clk;

	input [19:0] START_VAL_0_REG;
	input [19:0] START_VAL_1_REG;
	input [19:0] START_VAL_2_REG;
	input [19:0] START_VAL_3_REG;

	input [15:0] DWELL_CYCLES_REG;
	input [19:0] STEP_SIZE_REG;
	input [7:0]  NUM_CYCLES_REG;
	input [1:0]  NUM_DACS_REG;
	input [4:0]  W_REG_W;
	input [4:0]  W_REG_X;
	input [4:0]  W_REG_Y;
	input [4:0]  W_REG_Z;

	input TRIGGER_PVP_REG;

	output [31:0] mosi_o;
	output [4:0]  SELECT;
	output readout_o;
	output trigger_spi_o;

	/********************/
	/* Internal signals */
	/********************/


	///////// DACs //////////
	logic rstn_0, rstn_1, rstn_2, rstn_3;

	logic [31:0] mosi_0;
	logic [31:0] mosi_1;
	logic [31:0] mosi_2;
	logic [31:0] mosi_3;
	logic [31:0] past_mosi;

	logic 		 top_0;
	logic 		 top_1;
	logic		 top_2;
	logic 		 top_3;

	logic 		 base_0;
	logic		 base_1;
	logic 		 base_2;
	logic 		 base_3;

	logic 		 dac0_en;
	logic 		 dac1_en;
	logic 		 dac2_en;
	logic 		 dac3_en;
	/////////////////////////

	// FSM signals
	logic [3:0]  curr_state, next_state;
	logic [15:0] dwell_counter;   // cycle for DWELL_CYCLES

	/***************/
	/* FSM Machine */
	/***************/

	// FSM States:
	// WAIT     -- waits for trigger to start
	// S_SEND_0 -- send to DAC 0
	// S_SEND_1 -- send to DAC 1
	// S_SEND_2 -- send to DAC 2
	// S_SEND_3 -- send to DAC 3
	// S_STALL  -- middle step between each DAC increment

	// FINITE STATE MACHINE
	always @(posedge clk) begin
		rstn_3 <= 1;
		rstn_2 <= 1;
		rstn_1 <= 1;
		rstn_0 <= 1;

		if (~rstn) begin
			// State register.
			next_state 	<= WAIT;
			past_mosi <= 0;

			dwell_counter <= 0;
		end 
		else begin

			// State register.
			case(curr_state)
				WAIT: begin
					dwell_counter <= 0;
					rstn_3 		  <= 0;
					rstn_2 		  <= 0;
					rstn_1 		  <= 0;
					rstn_0		  <= 0;
					past_mosi	  <= 0;
					
					if (TRIGGER_PVP_REG)  next_state <= S_STALL;
					else          next_state <= WAIT;

				end
				S_STALL: begin
					
					rstn_3 <= 1;
					rstn_2 <= 1;
					rstn_1 <= 1;
					rstn_0 <= 1;

					next_state <= S_SEND_0;
					past_mosi <= mosi_o;

					dwell_counter <= 0;

				end
				S_SEND_0: begin

					next_state <= S_SEND_0;
					past_mosi <= mosi_o;

					// cycle until dwell counter has been spent. If we're not at the top of the stack, return to stall
					if ((dwell_counter == DWELL_CYCLES_REG) & !top_0)      // inside DAC 1 loop
					begin 
						dwell_counter <= 0; 
						next_state <= S_STALL; 
					end
					else if ((dwell_counter == DWELL_CYCLES_REG) & top_0)  // if we've' gone full through list, go to next DAC
					begin 
						dwell_counter <= 0; 
						next_state <= S_SEND_1; 
						rstn_0 <= 0; 
					end 
					else  // we are waiting for full time
					begin 
						dwell_counter <= dwell_counter + 1; 
					end

				end
				S_SEND_1: begin

					next_state <= S_SEND_1;
					past_mosi <= mosi_o;

					// cycle until dwell counter has been spent. If we're not at the top of the stack, return to S_STALL

					if ((dwell_counter == DWELL_CYCLES_REG) & !top_1)      // inside DAC 1 loop
					begin 
						dwell_counter <= 0;  
						next_state <= S_STALL; 
					end 
					else if ((dwell_counter == DWELL_CYCLES_REG) & top_1)  // if we've' gone full through list, go to next DAC
					begin 
						dwell_counter <= 0; 
						next_state <= S_SEND_2; 
						rstn_1 <= 0; 
					end  
					else 	  // we are waiting for full time
					begin 
						dwell_counter <= dwell_counter + 1; 
					end

				end
				S_SEND_2: begin

					next_state <= S_SEND_2;
					past_mosi <= mosi_o;

					// cycle until dwell counter has been spent. If we're not at the top of the stack, return to S_STALL

					if ((dwell_counter == DWELL_CYCLES_REG) & !top_2)    // inside DAC 1 loop  
					begin 
						dwell_counter <= 0;  
						next_state <= S_STALL; 
					end 
					else if ((dwell_counter == DWELL_CYCLES_REG) & top_2)   // if we've' gone full through list, go to next DAC
					begin 
						dwell_counter <= 0; 
						next_state <= S_SEND_3; 
						rstn_2 <= 0; 
					end 
					else 		 // we are waiting for full time									  
					begin 
						dwell_counter <= dwell_counter + 1; 
					end 

				end
				S_SEND_3: begin
					
					next_state <= S_SEND_3;
					past_mosi <= mosi_o;

					// cycle until dwell counter has been spent. If we're not at the top of the stack, return to stall
					if ((dwell_counter == DWELL_CYCLES_REG) & top_3)   // inside DAC 1 loop
					begin 
						dwell_counter <= 0;  
						next_state <= WAIT; 
						rstn_3 <= 0; 
					end 
					else if ((dwell_counter == DWELL_CYCLES_REG) & !top_3)    
					begin 
						dwell_counter <= 0;  
						next_state <= S_STALL; 
					end 
					else 		  // we are waiting for full time
					begin 
						dwell_counter <= dwell_counter + 1; 
					end 

				end
				default: begin dwell_counter <= 0; next_state <= WAIT; end
			endcase
		end
	end

	
	// go to next state
	assign curr_state = next_state;

	// whether or not the DAC is enabled (i.e. move to the next step if enabled)
	assign dac0_en = ((dwell_counter == 0) & (curr_state == S_SEND_0)) | (curr_state == WAIT);
	assign dac1_en = ((dwell_counter == 0) & (curr_state == S_SEND_1)) | (curr_state == WAIT);
	assign dac2_en = ((dwell_counter == 0) & (curr_state == S_SEND_2)) | (curr_state == WAIT);
	assign dac3_en = ((dwell_counter == 0) & (curr_state == S_SEND_3)) | (curr_state == WAIT);

	// assign the mosi and output for demuxing to DACs based on current state
	assign mosi_o      = ((curr_state==S_STALL) | (dwell_counter==0)) ? past_mosi : ((curr_state==S_SEND_0) & dwell_counter>0) ? mosi_0 : (curr_state==S_SEND_1) ? mosi_1 : (curr_state==S_SEND_2) ? mosi_2 : (curr_state==S_SEND_3) ? mosi_3 : 0;
	assign SELECT = (curr_state==S_SEND_0) ? W_REG_W : (curr_state==S_SEND_1) ? W_REG_X : (curr_state==S_SEND_2) ? W_REG_Y : (curr_state==S_SEND_3) ? W_REG_Z : 5'b11111; // this is hard to debug if we're always seeing first DAC and none of second (lol)

	// readout controls AWG readout
	assign readout_o 	 = (dwell_counter > DWELL_CYCLES_REG/10); // CHANGE TO CYCLES_TILL_READOUT

	// spi_readout controls when the SPI gets written to
	assign spi_readout_o = (dwell_counter > DWELL_CYCLES_REG/10 & dwell_counter < (DWELL_CYCLES_REG/10 + 1)); // 

	no_mem_sweep_fsm 
		#(
			.DEPTH	(4)
		)
		no_mem_sweep_0 (
			.rstn		(rstn_0),
			.clk		(clk),
			.enable     (dac0_en),
			.start		(START_VAL_0_REG),
			.step       (STEP_SIZE_REG),
			.base       (base_0),
			.top        (top_0),
			.mosi		(mosi_0)
			);

	no_mem_sweep_fsm 
		#(
			.DEPTH	(4)
		)
		no_mem_sweep_1 (
			.rstn		(rstn_1),
			.clk		(clk),
			.enable     (dac1_en),
			.start		(START_VAL_1_REG),
			.step       (STEP_SIZE_REG),
			.base       (base_1),
			.top        (top_1),
			.mosi		(mosi_1)
			);

	no_mem_sweep_fsm 
		#(
			.DEPTH	(4)
		)
		no_mem_sweep_2 (
			.rstn		(rstn_2),
			.clk		(clk),
			.enable     (dac2_en),
			.start		(START_VAL_2_REG),
			.step       (STEP_SIZE_REG),
			.base       (base_2),
			.top        (top_2),
			.mosi		(mosi_2)
			);

	no_mem_sweep_fsm 
		#(
			.DEPTH	(4)
		)
		no_mem_sweep_3 (
			.rstn		(rstn_3),
			.clk		(clk),
			.enable     (dac3_en),
			.start		(START_VAL_3_REG),
			.step       (STEP_SIZE_REG),
			.base       (base_3),
			.top        (top_3),
			.mosi		(mosi_3)
			);
			

endmodule