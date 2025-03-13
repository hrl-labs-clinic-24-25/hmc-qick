/**
*	A module that runs a pvp plot generator using a Finite State Machine
*
* Author: Zoe Worrall, zoe.worrall@me.com
* Date: March 13, 2025
*/

module pvp_fsm_gen 
    (
		// Reset and clock.
		rstn,
		clk,

		// start the fsm
        TRIGGER_PVP_REG,

		// Inputs from PYNQ registers
		X_AXIS_START_VAL_REG,
		Y_AXIS_START_VAL_REG,
		Z_AXIS_START_VAL_REG,
		W_AXIS_START_VAL_REG,

		DWELL_CYCLES_REG,        // the number of clock cycles to wait before moving to next DAC. DWELL_CYCLES_REG > 50
		CYCLES_TILL_READOUT_REG, // the number of clock cycles until AWG can be run

		STEP_SIZE_REG,
		PVP_WIDTH_REG,  // ** change to PVP_WIDTH
		NUM_DACS_REG,

		X_AXIS_DEMUX_REG,
		Y_AXIS_DEMUX_REG,
		Z_AXIS_DEMUX_REG,
		W_AXIS_DEMUX_REG,

    	// parameter inputs.
		mosi_o,
        select,
        readout_o,      // for AWG output
		trigger_spi_o,  // for SPI output
		done
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

	input [19:0] X_AXIS_START_VAL_REG;
	input [19:0] Y_AXIS_START_VAL_REG;
	input [19:0] Z_AXIS_START_VAL_REG;
	input [19:0] W_AXIS_START_VAL_REG;

	// assume that CYCLES_TILL_READOUT_REG is less than DWELL_CYCLES_REG
	input [15:0] DWELL_CYCLES_REG;
	input [15:0] CYCLES_TILL_READOUT_REG; // the number of clock cycles until AWG can be run

	input [19:0] STEP_SIZE_REG;
	input [9:0]  PVP_WIDTH_REG;
	input [2:0]  NUM_DACS_REG;

	input [5:0]  X_AXIS_DEMUX_REG;
	input [5:0]  Y_AXIS_DEMUX_REG;
	input [5:0]  Z_AXIS_DEMUX_REG;
	input [5:0]  W_AXIS_DEMUX_REG;

	input TRIGGER_PVP_REG;

	output [31:0] mosi_o;  // could potentially be reduced to 24
	output [4:0]  select;
	output done;
	output readout_o;
	output trigger_spi_o;


	/********************/
	/* Internal signals */
	/********************/

	
	logic on_off;

	///////// DACs //////////
	logic rstn_0, rstn_1, rstn_2, rstn_3;

	logic [31:0] mosi_0;
	logic [31:0] mosi_1;
	logic [31:0] mosi_2;
	logic [31:0] mosi_3;
	logic [31:0] past_mosi;
	logic [4:0]  past_select;

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
	logic [31:0] next_mosi;

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
		dwell_counter <= 0;
		next_mosi <= ((curr_state==S_STALL) | (dwell_counter==0)) ? past_mosi   : ((curr_state==S_SEND_0) & dwell_counter>0) ? mosi_0 : (curr_state==S_SEND_1) ? mosi_1                : (curr_state==S_SEND_2) ? mosi_2 			   : (curr_state==S_SEND_3) ? mosi_3 				: 0;
	

		if (~rstn) begin
			// State register.
			next_state 	<= WAIT;
			past_mosi <= 0;
			past_select <= 0;

			dwell_counter <= 0;
		end 
		else begin
			
			on_off <= ((dwell_counter >= (DWELL_CYCLES_REG-10)) & (dwell_counter < (DWELL_CYCLES_REG-9))) ? 1 : 0;

			// State register.
			case(curr_state)
				WAIT: begin
					dwell_counter <= 0;
					rstn_3 		  <= 0;
					rstn_2 		  <= 0;
					rstn_1 		  <= 0;
					rstn_0		  <= 0;
					past_mosi	  <= 0;
					past_select	  <= 0;
					
					if (TRIGGER_PVP_REG)  next_state <= S_STALL;
					else          		  next_state <= WAIT;

				end
				S_STALL: begin
					
					rstn_3 <= 1;
					rstn_2 <= 1;
					rstn_1 <= 1;
					rstn_0 <= 1;

					 // will only load the next DACs if the TRIGGER_PVP_REG is still 1 (i.e. gives user control to stop partway through the pvp generation)
					if (TRIGGER_PVP_REG)
						next_state <= S_SEND_0;
					else
						next_state <= S_STALL;
					past_mosi   <= mosi_o;
					past_select <= select;

					dwell_counter <= 0;

				end
				S_SEND_0: begin

					next_state <= S_SEND_0;
					past_mosi <= mosi_o;
					past_select <= select;

					// cycle until dwell counter has been spent. If we're not at the top of the stack, return to stall
					if ((dwell_counter == DWELL_CYCLES_REG) & !top_0)      // inside DAC 1 loop
					begin 
						dwell_counter <= 0; 
						next_state <= S_STALL; 
					end
					else if ((dwell_counter == DWELL_CYCLES_REG) & top_0)  // if we've' gone full through list, go to next DAC
					begin 
						dwell_counter <= 0; 
						if (NUM_DACS_REG < 2) next_state <= WAIT;
						else next_state <= S_SEND_1;
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
					past_select <= select;

					// cycle until dwell counter has been spent. If we're not at the top of the stack, return to S_STALL

					if ((dwell_counter == DWELL_CYCLES_REG) & !top_1)      // inside DAC 1 loop
					begin 
						dwell_counter <= 0;  
						next_state <= S_STALL; 
					end 
					else if ((dwell_counter == DWELL_CYCLES_REG) & top_1)  // if we've' gone full through list, go to next DAC
					begin 
						dwell_counter <= 0; 
						if (NUM_DACS_REG < 3) next_state <= WAIT;
						else next_state <= S_SEND_2; 
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
					past_select <= select;

					// cycle until dwell counter has been spent. If we're not at the top of the stack, return to S_STALL

					if ((dwell_counter == DWELL_CYCLES_REG) & !top_2)    // inside DAC 1 loop  
					begin 
						dwell_counter <= 0;  
						next_state <= S_STALL; 
					end 
					else if ((dwell_counter == DWELL_CYCLES_REG) & top_2)   // if we've' gone full through list, go to next DAC
					begin 
						dwell_counter <= 0; 
						if (NUM_DACS_REG < 4) next_state <= WAIT;
						else next_state <= S_SEND_3; 
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
					past_select <= select;

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

	
	/********************************/
	/* Combinational Output Signals */
	/********************************/

	// go to next state
	assign curr_state = next_state;

	// whether or not the DAC is enabled (i.e. move to the next step if enabled)
	assign dac0_en = ((dwell_counter == 0) & (curr_state == S_SEND_0)) | (curr_state == WAIT);
	assign dac1_en = ((dwell_counter == 0) & (curr_state == S_SEND_1)) | (curr_state == WAIT);
	assign dac2_en = ((dwell_counter == 0) & (curr_state == S_SEND_2)) | (curr_state == WAIT);
	assign dac3_en = ((dwell_counter == 0) & (curr_state == S_SEND_3)) | (curr_state == WAIT);

	// assign the mosi and output for demuxing to DACs based on current state
	assign mosi_o = next_mosi; //((curr_state==S_STALL) | (dwell_counter==0)) ? past_mosi   : ((curr_state==S_SEND_0) & dwell_counter>0) ? mosi_0 : (curr_state==S_SEND_1) ? mosi_1                : (curr_state==S_SEND_2) ? mosi_2 			   : (curr_state==S_SEND_3) ? mosi_3 				: 0;
	assign select = ((curr_state==S_STALL) | (dwell_counter==0)) ? past_select :  (curr_state==S_SEND_0) ? X_AXIS_DEMUX_REG[4:0]     : (curr_state==S_SEND_1) ? Y_AXIS_DEMUX_REG[4:0] : (curr_state==S_SEND_2) ? Z_AXIS_DEMUX_REG[4:0] : (curr_state==S_SEND_3) ? W_AXIS_DEMUX_REG[4:0] : 5'b11111; // this is hard to debug if we're always seeing first DAC and none of second (lol)

	assign trigger_spi_o = on_off;

	// readout controls AWG readout
	assign readout_o 	 = (dwell_counter > CYCLES_TILL_READOUT_REG); // CHANGE TO CYCLES_TILL_READOUT

	assign done = (curr_state == WAIT);	// if all the DACs are at the top, then we are done

	no_mem_sweep_fsm 
		#(
			.DEPTH	(4)
		)
		no_mem_sweep_0 (
			.rstn		(rstn_0),
			.clk		(clk),
			.enable     (dac0_en),
			.start		(X_AXIS_START_VAL_REG),
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
			.start		(Y_AXIS_START_VAL_REG),
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
			.start		(Z_AXIS_START_VAL_REG),
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
			.start		(W_AXIS_START_VAL_REG),
			.step       (STEP_SIZE_REG),
			.base       (base_3),
			.top        (top_3),
			.mosi		(mosi_3)
			);
			

endmodule