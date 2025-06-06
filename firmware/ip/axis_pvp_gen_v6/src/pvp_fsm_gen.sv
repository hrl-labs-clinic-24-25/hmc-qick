/**
*	A module that runs a pvp plot generator using a Finite State Machine
*
* Author: Zoe Worrall, zoe.worrall@me.com
* Date: March 13, 2025

* Rev A: updating reg names
* Author: Ellie Sundheim esundheim@hmc.edu
* Date: March 13, 2025
*/

module pvp_fsm_gen 
    (
		// Reset and clock.
		rstn,
		clk,

		// start the fsm or configure a DAC
		CONFIG_REG,

		// Inputs from PYNQ registers
		START_VAL_0_REG,
		START_VAL_1_REG,
		START_VAL_2_REG,
		START_VAL_3_REG,

		DWELL_CYCLES_REG,        // the number of clock cycles to wait before moving to next DAC. LOADING_SPI > 50
		CYCLES_TILL_READOUT_REG, // the number of clock cycles until AWG can be run

		STEP_SIZE_REG,
		PVP_WIDTH_REG,  // ** change to PVP_WIDTH
		NUM_DIMS_REG,

		DEMUX_0_REG,
		DEMUX_1_REG,
		DEMUX_2_REG,
		DEMUX_3_REG,

		CTRL_REG,
		MODE_REG,

    	// parameter inputs.
		mosi_o,
        select_mux,
        readout_o,      // for AWG output
		trigger_spi_o,  // for SPI output
		ldacn,
		clrn,
		resetn, // for resetting the DAC
		done
	);

	/**************/
	/* Parameters */
	/**************/
	
	// Define the states for the FSM
	parameter WAIT = 4'b0000, CONFIG_STATE = 4'b0101, S_SEND_0 = 4'b0001, S_SEND_1 = 4'b0010, S_SEND_2 = 4'b0100, S_SEND_3 = 4'b1000, S_STALL = 4'b1101, NULL_STATE = 4'b1111;

	/*********/
	/* Ports */
	/*********/

	input rstn;
	input clk;

	input [19:0] START_VAL_0_REG;
	input [19:0] START_VAL_1_REG;
	input [19:0] START_VAL_2_REG;
	input [19:0] START_VAL_3_REG;

	// assume that CYCLES_TILL_READOUT_REG is less than LOADING_SPI
	input [31:0] DWELL_CYCLES_REG;
	input [15:0] CYCLES_TILL_READOUT_REG; // the number of clock cycles until AWG can be run

	input [19:0] STEP_SIZE_REG;
	input [9:0]  PVP_WIDTH_REG;
	input [2:0]  NUM_DIMS_REG;

	input [4:0]  DEMUX_0_REG;
	input [4:0]  DEMUX_1_REG;
	input [4:0]  DEMUX_2_REG;
	input [4:0]  DEMUX_3_REG;

	input [28:0] CONFIG_REG; // for configuring the DACs: [28:24] is demux value, [23:0] is the SPI message. won't run unless its != 0

	input  [3:0] CTRL_REG; // [LDACN, CLRN, RSTN, TRIGGER_PVP]
	input  [1:0] MODE_REG;

	output [23:0] mosi_o;  // could potentially be reduced to 24
	output [4:0]  select_mux;
	output 		  ldacn;
	output 		  clrn;
	output		  resetn;

	output done;
	output readout_o;
	output trigger_spi_o;


	/********************/
	/* Internal signals */
	/********************/

	parameter LOADING_SPI = 9'd400;
	parameter HOLD_SIGNAL = 9'd100;
	
	logic on_off;

	///////// DACs //////////
	logic rstn_0, rstn_1, rstn_2, rstn_3;

	logic [31:0] mosi_0;
	logic [31:0] mosi_1;
	logic [31:0] mosi_2;
	logic [31:0] mosi_3;
	logic [31:0] past_mosi;
	logic [4:0]  past_select_mux;

	logic [7:0] index;

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

	logic        past_done;

	logic       ldacn_fsm;

	logic 		ldacn_user;
	logic		clrn_user;
	logic		rstn_user;
	logic		trigger_pvp;

	/////////////////////////

	// FSM signals
	logic [3:0]  curr_state, next_state;
	logic [31:0] dwell_counter;   // cycle for DWELL_CYCLES
	logic [31:0] next_mosi;

	// Added mode handling (mode 0 = (default) Linear, mode 1 = Top-Bottom, mode 2 = Spiral)
	logic [1:0] mode;
	logic direction_0; // 1 for increasing, 0 for decreasing
	logic direction_1;
	logic direction_2;
	logic direction_3;
	logic [7:0] count; // counter for the number of steps taken in spiral mode

	logic wait_to_next_cycle;

	logic [31:0] ldac_counter;
	logic 		 ldacn_blip;

	logic        last_0, last_1, last_2, last_3; // when the last number we reached was at the top of 0, 1, 2, or 3, we raise this flag.
	//logic		 init_load; // used to set all the DACs to their starting values at the beginning of the FSM

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

	assign {ldacn_user, clrn_user, rstn_user, trigger_pvp} = CTRL_REG;
	assign ldacn = (MODE_REG == 2'b11) ? ldacn_user : ldacn_fsm;
	assign resetn = (((MODE_REG == 2'b11) ? rstn_user : 1'b1)); // allows user to control reset the DAC if you're in MODE 3
	assign clrn = (MODE_REG == 2'b11) ? clrn_user : 1'b1;

	

	// FINITE STATE MACHINE
	always @(posedge clk) begin
		past_done <= 0;
		rstn_3 <= 1;
		rstn_2 <= 1;
		rstn_1 <= 1;
		rstn_0 <= 1;
		//init_load <= init_load;

		last_0 <= last_0;
		last_1 <= last_1;
		last_2 <= last_2;
		last_3 <= last_3;

		dwell_counter <= dwell_counter;
		next_mosi <= ((curr_state==S_STALL) | (dwell_counter==0)) ? past_mosi   : ((curr_state==CONFIG_STATE) & dwell_counter>0) ? CONFIG_REG[23:0] : ((curr_state==S_SEND_0) & dwell_counter>0) ? mosi_0 : (curr_state==S_SEND_1) ? mosi_1                : (curr_state==S_SEND_2) ? mosi_2 			   : (curr_state==S_SEND_3) ? mosi_3 				: 0;

		on_off <= 0;

		if (~rstn) begin
			// State register.
			next_state 	<= WAIT;
			past_mosi <= 0;
			past_select_mux <= 0;

			direction_0 <= 1;
			direction_1 <= 1;
			direction_2 <= 1;
			direction_3 <= 1;
			index <= 0;
			count <= 0;

			last_0 <= 0;
			last_1 <= 0;
			last_2 <= 0;
			last_3 <= 0;

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
					past_mosi         <= mosi_0;   // preload with the first DAC word
    				past_select_mux   <= 0;

					past_done <= done;

					//init_load <= 1; // if the first value isn't loaded yet, we need to go through every dimension of the SPI to set their starting value

					last_0 <= 0;
					last_1 <= 0;
					last_2 <= 0;
					last_3 <= 0;

					/////////////////////////
					/// NEXT STATE LOGIC ////
					/////////////////////////

					// run the pvp plot generator
					if (trigger_pvp & !done)       		      						  next_state <= S_STALL;

					// need to configure one of the DACs, so enter config state
					else if (CONFIG_REG != 0 & !done) 								  next_state <= CONFIG_STATE;

					// finished configuring/running pvp, but haven't turned off trigger or configuration
					else if ((trigger_pvp & done) | ((CONFIG_REG != 0) & done)) 	  next_state <= WAIT;

					// finished running trigger pvp and config register; turn off the done sign so that we can run the program again
					else if ((!trigger_pvp & done) | (CONFIG_REG == 0) & done)  begin next_state <= WAIT; past_done <= 0; end

					// continue running WAIT state
					else          		  		        		  						  next_state <= WAIT;
				end
				CONFIG_STATE: begin
					next_state <= CONFIG_STATE;
					on_off <= ((dwell_counter >= 99) & (dwell_counter <= 116)) ? 1 : 0;

					// configure the DACs
					if (CONFIG_REG != 0 & dwell_counter <= (DWELL_CYCLES_REG)) begin
						dwell_counter <= dwell_counter + 1;
						past_done <= 0;
					end
					else begin
						next_state <= WAIT;
						dwell_counter <= 0;
						past_done <= 1;
					end
				end

				S_STALL: begin
					
					rstn_3 <= 1;
					rstn_2 <= 1;
					rstn_1 <= 1;
					rstn_0 <= 1;
					past_done <= done;

					 // will only load the next DACs if the trigger_pvp is still 1 (i.e. gives user control to stop partway through the pvp generation)
					if (trigger_pvp & !done)
						if (wait_to_next_cycle) begin
							next_state <= S_STALL;
							dwell_counter <= dwell_counter + 1;
						end else begin
							next_state <= S_SEND_0;
							dwell_counter <= 0;
						end
					else begin
						if (trigger_pvp != 1) begin
							next_state <= S_STALL;
							dwell_counter <= dwell_counter;
						end else begin
							if (wait_to_next_cycle) begin
								next_state <= S_STALL;
								dwell_counter <= dwell_counter + 1;
							end else begin
								next_state <= WAIT;
								dwell_counter <= dwell_counter;
							end
						end
					end

					past_mosi   <= mosi_o;
					past_select_mux <= select_mux;

				end
				S_SEND_0: begin

					next_state <= S_SEND_0;
					past_mosi <= mosi_o;
					past_select_mux <= select_mux;
					dwell_counter <= dwell_counter + 1; 

					past_done <= done;

					//if (NUM_DIMS_REG == 1) init_load <= 0;

					on_off <= ((dwell_counter >= 99) & (dwell_counter <= 116)) ? 1 : 0;
					
					case(MODE_REG)
						2'b10: begin //"Spiral" increment mode
							if (count == PVP_WIDTH_REG)begin 
								next_state <= WAIT;
							end

							else if (direction_0)begin 
								// cycle until dwell counter has been spent. If we're not at the top of the stack, return to stall
								if ((dwell_counter == (LOADING_SPI-1)) & !top_0)      // inside DAC 1 loop
								begin 
									dwell_counter <= 0; 
									next_state <= S_SEND_0; 
								end
								else if ((dwell_counter == (LOADING_SPI-1)) & top_0)  // if we've' gone full through list, set up to go to next DAC and flip direction
								begin 
									dwell_counter <= 0;
									next_state <= S_SEND_1;
									direction_0 <= 0;

									if (NUM_DIMS_REG == 1) begin past_done <= 1; end
									
								end 
							end
							else
							begin 
								// cycle until dwell counter has been spent. If we're not at the base of the stack, return to stall
								if ((dwell_counter == (LOADING_SPI-1)) & !base_0)      // inside DAC 1 loop
								begin 
									dwell_counter <= 0; 
									next_state <= S_SEND_0;
								end
								else if ((dwell_counter == (LOADING_SPI-1)) & base_0)  // if we've' gone full through list, set up to go to next DAC and flip direction
								begin
									dwell_counter <= 0;
									next_state <= S_SEND_1;
									direction_0 <= 1;
									rstn_0 <= 0; 

									if (NUM_DIMS_REG == 1) begin past_done <= 1; end
									
								end 
							end
						end


						2'b01: begin // "Top-Bottom" increment mode
							if (direction_0)begin 
								// cycle until dwell counter has been spent. If we're not at the top of the stack, return to stall
								if ((dwell_counter == (LOADING_SPI-1)) & !top_0)      // inside DAC 1 loop
								begin 
									if ((last_0)) next_state <= S_SEND_1;  // the previous DAC was at the top of the DAC0 stack, which means that we can go to the next DAC now
									else 			   next_state <= S_STALL; 
								end
								else if ((dwell_counter == (LOADING_SPI-1)) & top_0)  // if we've' gone full through list, set up to go to next DAC and flip direction
								begin 
									next_state <= S_STALL;
									last_0 <= 1;
									direction_0 <= 0;

									if (NUM_DIMS_REG == 1) begin past_done <= 1; end
									
								end 
							end
							else
							begin
								// cycle until dwell counter has been spent. If we're not at the base of the stack, return to stall
								if ((dwell_counter == (LOADING_SPI-1)) & !base_0)      // inside DAC 1 loop
								begin 
									if ((last_0)) next_state <= S_SEND_1;  // the previous DAC was at the top of the DAC0 stack, which means that we can go to the next DAC now
									else 			   next_state <= S_STALL; 
								end
								else if ((dwell_counter == (LOADING_SPI-1)) & base_0)  // if we've' gone full through list, set up to go to next DAC and flip direction
								begin
									next_state <= S_STALL;
									last_0 <= 1;
									direction_0 <= 1;

									if (NUM_DIMS_REG == 1) begin past_done <= 1; end
									
								end 
							end
						end


						2'b00: begin // "Default" increment mode
							// cycle until dwell counter has been spent. If we're not at the top of the stack, return to stall
							if ((dwell_counter == (LOADING_SPI-1)) & !top_0)      // inside DAC 1 loop
							begin 
								if ((last_0 == 1)) next_state <= S_SEND_1;  // the previous DAC was at the top of the DAC0 stack, which means that we can go to the next DAC now
								else 			   next_state <= S_STALL; 
							end
							else if ((dwell_counter == (LOADING_SPI-1)) & top_0)  // if we've' gone full through list, set up to go to next DAC
							begin
								next_state <= S_STALL;
								last_0 <= 1;

								if (NUM_DIMS_REG == 1) begin past_done <= 1; end
								
								rstn_0 <= 0; 
							end 
						end
					endcase
				end
				S_SEND_1: begin
					next_state <= S_SEND_1;
					past_mosi <= mosi_o;
					past_select_mux <= select_mux;
					dwell_counter <= dwell_counter + 1; 

					last_0 <= 0;

					past_done <= done;
					
					//if (NUM_DIMS_REG == 2) init_load <= 0;

					on_off <= ((dwell_counter >= (LOADING_SPI-1)+100) & (dwell_counter <= (LOADING_SPI-1)+117)) ? 1 : 0;

					case(MODE_REG)
						2'b10: begin //"Spiral" increment mode
							if (direction_1)begin 
								// cycle until dwell counter has been spent. If we're not at the top of the stack, return to stall
								if ((dwell_counter == (LOADING_SPI-1)*2) & !top_1)      
								begin
									dwell_counter <= 0; 
									next_state <= S_SEND_1; 
								end 
								else if ((dwell_counter == (LOADING_SPI-1)*2) & top_1)  // if we've' gone full through list, go to next DAC
								begin 
									dwell_counter <= 0;
									next_state <= S_SEND_0;
									direction_1 <= 0;
									index <= index + 1;
									count <= count + 1;

									if (NUM_DIMS_REG == 2) begin past_done <= 1; end
								end 
							end
							else
							begin 
								if ((dwell_counter == (LOADING_SPI-1)*2) & !base_1)      
								begin 
									dwell_counter <= 0; 
									next_state <= S_SEND_1; 
								end
								else if ((dwell_counter == (LOADING_SPI-1)*2) & base_1)  // if we've' gone full through list, set up to go to next DAC and flip direction
								begin
									dwell_counter <= 0;
									next_state <= S_SEND_0;
									direction_1 <= 1;
									count <= count + 1;

									if (NUM_DIMS_REG == 2) begin past_done <= 1; end
									
								end 
							end
						end


						2'b01: begin // "Top-Bottom" increment mode
							if (direction_1)begin 
								// cycle until dwell counter has been spent. If we're not at the top of the stack, return to stall
								if ((dwell_counter == ((LOADING_SPI-1)*2)) & !top_1)      
								begin
									if ((last_1)) next_state <= S_SEND_2;  // the previous DAC was at the top of the DAC0 stack, which means that we can go to the next DAC now
									else 			 next_state <= S_STALL; 
								end 
								else if ((dwell_counter == (LOADING_SPI-1)*2) & top_1)  // if we've' gone full through list, go to next DAC
								begin 
									next_state <= S_STALL;
									last_1 <= 1;
									direction_1 <= 0;

									if (NUM_DIMS_REG == 2) begin past_done <= 1; end
								end 
							end
							else
							begin 
								if ((dwell_counter == (LOADING_SPI-1)*2) & !base_1)      
								begin 
									if ((last_1)) next_state <= S_SEND_2;  // the previous DAC was at the top of the DAC0 stack, which means that we can go to the next DAC now
									else 			   next_state <= S_STALL; 
								end
								else if ((dwell_counter == (LOADING_SPI-1)*2) & base_1)  // if we've' gone full through list, set up to go to next DAC and flip direction
								begin
									next_state <= S_STALL;
									last_1 <= 1;
									direction_1 <= 1;

									if (NUM_DIMS_REG == 2) begin past_done <= 1; end
									
								end 
							end
						end


						2'b00: begin // "Default" increment mode
							// cycle until dwell counter has been spent. If we're not at the top of the stack, return to S_STALL
							if ((dwell_counter == ((LOADING_SPI-1)*2)) & !top_1)      
							begin
								if (last_1 == 1) next_state <= S_SEND_2;  // the previous DAC was at the top of the DAC0 stack, which means that we can go to the next DAC now
								else 			 next_state <= S_STALL; 
							end 
							else if ((dwell_counter == (LOADING_SPI-1)*2) & top_1)  // if we've' gone full through list, go to next DAC
							begin 
								next_state <= S_STALL;
								last_1 <= 1;

								if (NUM_DIMS_REG == 2) begin past_done <= 1; end
								rstn_1 <= 0; 
							end
						end
					endcase
				end
				S_SEND_2: begin

					next_state <= S_SEND_2;
					past_mosi <= mosi_o;
					past_select_mux <= select_mux;
					dwell_counter <= dwell_counter + 1;

					past_done <= done;
					
					//if (NUM_DIMS_REG == 3) init_load <= 0;

					last_1 <= 0;

					on_off <= ((dwell_counter >= 2*(LOADING_SPI-1)+100) & (dwell_counter <= 2*(LOADING_SPI-1)+117)) ? 1 : 0;

					case(MODE_REG)
						2'b10: begin //"Spiral" increment mode
							next_state = WAIT;
						end


						2'b01: begin // "Top-Bottom" increment mode
							if (direction_2)begin 
								// cycle until dwell counter has been spent. If we're not at the top of the stack, return to stall
								if ((dwell_counter == ((LOADING_SPI-1)*3)) & !top_2)      
								begin
									if ((last_2)) next_state <= S_SEND_3;  // the previous DAC was at the top of the DAC0 stack, which means that we can go to the next DAC now
									else 			 next_state <= S_STALL; 
								end 
								else if ((dwell_counter == ((LOADING_SPI-1)*3)) & top_2)   // if we've' gone full through list, go to next DAC
								begin
									next_state <= S_STALL;
									last_2 <= 1;
									direction_2 <= 0;

									if (NUM_DIMS_REG == 3) begin past_done <= 1; end
								end
							end
							else
							begin 
								if ((dwell_counter == (LOADING_SPI-1)*3) & !base_2)      
								begin 
									if ((last_2)) next_state <= S_SEND_3;  // the previous DAC was at the top of the DAC0 stack, which means that we can go to the next DAC now
									else 			   next_state <= S_STALL; 
								end
								else if ((dwell_counter == (LOADING_SPI-1)*3) & base_2)  // if we've' gone full through list, set up to go to next DAC and flip direction
								begin
									next_state <= S_STALL;
									last_2 <= 1;
									direction_2 <= 1;

									if (NUM_DIMS_REG == 3) begin past_done <= 1; end
								
								end 
							end
						end


						2'b00: begin // "Default increment mode
							// cycle until dwell counter has been spent. If we're not at the top of the stack, return to S_STALL
							if ((dwell_counter == ((LOADING_SPI-1)*3)) & !top_2)      
							begin
								if (last_2 == 1) next_state <= S_SEND_3;  // the previous DAC was at the top of the DAC0 stack, which means that we can go to the next DAC now
								else 			 next_state <= S_STALL; 
							end 
							else if ((dwell_counter == ((LOADING_SPI-1)*3)) & top_2)   // if we've' gone full through list, go to next DAC
							begin
								next_state <= S_STALL;
								last_2 <= 1;

								if (NUM_DIMS_REG == 3) begin past_done <= 1; end
								rstn_2 <= 0; 
							end
						end
					endcase
				end
				S_SEND_3: begin
					
					next_state <= S_SEND_3;
					past_mosi <= mosi_o;
					past_select_mux <= select_mux;
					dwell_counter <= dwell_counter + 1; 

					past_done <= done;
					
					//if (NUM_DIMS_REG == 4) init_load <= 0;

					last_2 <= 0;

					on_off <= ((dwell_counter >= 3*(LOADING_SPI-1)+100) & (dwell_counter <= 3*(LOADING_SPI-1)+117)) ? 1 : 0;
					


					case(MODE_REG)
						2'b10: begin //"Spiral" increment mode
							next_state = WAIT;
						end


						2'b01: begin // "Top-Bottom" increment mode
							if (direction_3)begin 
								// cycle until dwell counter has been spent. If we're not at the top of the stack, return to stall
								if ((dwell_counter == ((LOADING_SPI-1)*4)) & !top_3)    
								begin
									next_state <= S_STALL; 
								end 
								else if ((dwell_counter == ((LOADING_SPI-1)*4)) & top_3)   
								begin 
									next_state <= S_STALL;
									last_3 <= 1;
									past_done <= 1;
									direction_3 <= 0;
								end 
							end
							else
							begin 
								// cycle until dwell counter has been spent. If we're not at the top of the stack, return to stall
								if ((dwell_counter == ((LOADING_SPI-1)*4)) & !base_3)    
								begin
									next_state <= S_STALL; 
								end 
								else if ((dwell_counter == ((LOADING_SPI-1)*4)) & base_3)   
								begin 
									next_state <= S_STALL;
									last_3 <= 1;
									past_done <= 1;
									rstn_3 <= 0; 
									direction_3 <= 1;
								end 
							end
						end


						2'b00: begin // "Default increment mode
							// cycle until dwell counter has been spent. If we're not at the top of the stack, return to stall
							if ((dwell_counter == ((LOADING_SPI-1)*4)) & !top_3)    
							begin
								next_state <= S_STALL; 
							end 
							else if ((dwell_counter == ((LOADING_SPI-1)*4)) & top_3)   
							begin 
								next_state <= S_STALL;
								last_3 <= 1;
								past_done <= 1;
								rstn_3 <= 0; 
							end 
						end
					endcase
				end
				default: begin dwell_counter <= 0; next_state <= WAIT; rstn_0 <= 1;  rstn_1 <= 1;  rstn_2 <= 1;  rstn_3 <= 1;  end
			endcase
		end
	end

	
	/********************************/
	/* Combinational Output Signals */
	/********************************/

	// go to next state
	assign curr_state = next_state;

	// whether or not the DAC is enabled (i.e. move to the next step if enabled)
	assign dac0_en = ((dwell_counter ==             0) & (curr_state == S_SEND_0)) | (curr_state == WAIT);
	assign dac1_en = ((dwell_counter ==   LOADING_SPI) & (curr_state == S_SEND_1)) | (curr_state == WAIT);
	assign dac2_en = ((dwell_counter == 2*LOADING_SPI) & (curr_state == S_SEND_2)) | (curr_state == WAIT);
	assign dac3_en = ((dwell_counter == 3*LOADING_SPI) & (curr_state == S_SEND_3)) | (curr_state == WAIT);

	// assign the mosi and output for demuxing to DACs based on current state
	assign mosi_o = next_mosi; //((curr_state==S_STALL) | (dwell_counter==0)) ? past_mosi   : ((curr_state==S_SEND_0) & dwell_counter>0) ? mosi_0 : (curr_state==S_SEND_1) ? mosi_1                : (curr_state==S_SEND_2) ? mosi_2 			   : (curr_state==S_SEND_3) ? mosi_3 				: 0;
	assign select_mux = ((curr_state==S_STALL) | (dwell_counter==0)) ? past_select_mux :  (curr_state == CONFIG_STATE) ? CONFIG_REG[28:24] : (curr_state==S_SEND_0) ? DEMUX_0_REG     : (curr_state==S_SEND_1) ? DEMUX_1_REG : (curr_state==S_SEND_2) ? DEMUX_2_REG : (curr_state==S_SEND_3) ? DEMUX_3_REG : 4'b1111; // this is hard to debug if we're always seeing first DAC and none of second (lol)

	assign trigger_spi_o = on_off;

	// readout controls AWG readout
	assign readout_o 	 = (dwell_counter > CYCLES_TILL_READOUT_REG); // CHANGE TO CYCLES_TILL_READOUT

	assign done = past_done;

	 // if all the DACs have all finished running, then we are done
	assign wait_to_next_cycle = ((dwell_counter >= LOADING_SPI) & (dwell_counter < DWELL_CYCLES_REG)) ? 1 : 0; // if we're waiting for the next cycle to start
	assign ldacn_fsm 	      = ((curr_state != WAIT) & wait_to_next_cycle & (dwell_counter > (DWELL_CYCLES_REG - HOLD_SIGNAL)) & (dwell_counter < DWELL_CYCLES_REG)) ? 1'b0 : 1'b1;

	no_mem_sweep_fsm 
		
		no_mem_sweep_0 (
			.rstn		(rstn_0),
			.clk		(clk),
			.enable     (dac0_en),
			.direction  (direction_0),
			.start		(START_VAL_0_REG),
			.step       (STEP_SIZE_REG),
			.index		(index),
			.mode 		(MODE_REG),
			.base       (base_0),
			.top        (top_0),
			.mosi		(mosi_0),
			.DEPTH	    (PVP_WIDTH_REG)
			);

	no_mem_sweep_fsm 
		
		no_mem_sweep_1 (
			.rstn		(rstn_1),
			.clk		(clk),
			.enable     (dac1_en),
			.direction 	(direction_1),
			.start		(START_VAL_1_REG),
			.step       (STEP_SIZE_REG),
			.index		(index),
			.mode		(MODE_REG),
			.base       (base_1),
			.top        (top_1),
			.mosi		(mosi_1),
			.DEPTH	    (PVP_WIDTH_REG)
			);

	no_mem_sweep_fsm 
	
		no_mem_sweep_2 (
			.rstn		(rstn_2),
			.clk		(clk),
			.enable     (dac2_en),
			.direction 	(direction_2),
			.start		(START_VAL_2_REG),
			.step       (STEP_SIZE_REG),
			.index		(index),
			.mode 		(MODE_REG),
			.base       (base_2),
			.top        (top_2),
			.mosi		(mosi_2),
			.DEPTH	    (PVP_WIDTH_REG)
			);

	no_mem_sweep_fsm 
		
		no_mem_sweep_3 (
			.rstn		(rstn_3),
			.clk		(clk),
			.enable     (dac3_en),
			.direction 	(direction_3),
			.start		(START_VAL_3_REG),
			.step       (STEP_SIZE_REG),
			.index		(index),
			.mode 		(MODE_REG),
			.base       (base_3),
			.top        (top_3),
			.mosi		(mosi_3),
			.DEPTH	    (PVP_WIDTH_REG)
			);
			

endmodule