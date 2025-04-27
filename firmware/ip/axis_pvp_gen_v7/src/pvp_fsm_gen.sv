/**
*	A module that runs a pvp plot generator using a Finite State Machine
* 		Groups the DACs into Groups 1, 2, 3, and 4. Based on these groups, the FSM will update DACs at a given time.
*		This allows for concurrent loading.
*
* Author: Zoe Worrall, zoe.worrall@me.com
* Date: March 13, 2025
*
* Rev A: updating reg names
* Author: Ellie Sundheim esundheim@hmc.edu
* Date: March 13, 2025
*
* Rev B: Added timing capability so that DACs send out SPI at correct times.
* Author: Zoe Worrall, zoe.worrall@me.com
* Date: May 31, 2025
*
* Rev C: Added Groups and changed the way the trigger works (either PMOD or User)
* Author: Zoe Worrall, zoe.worrall@me.com
* Date: April 26, 2025
*
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

		STEP_SIZE_0_REG,
		STEP_SIZE_1_REG,
		STEP_SIZE_2_REG,
		STEP_SIZE_3_REG,

		DEMUX_0_REG,
		DEMUX_1_REG,
		DEMUX_2_REG,
		DEMUX_3_REG,

		DAC_0_GROUP_REG,
		DAC_1_GROUP_REG,
		DAC_2_GROUP_REG,
		DAC_3_GROUP_REG,

		DWELL_CYCLES_REG,        // the number of clock cycles to wait before moving to next DAC. LOADING_SPI > 50
		CYCLES_TILL_READOUT_REG, // the number of clock cycles until AWG can be run

		PVP_WIDTH_REG,  // ** change to PVP_WIDTH
		NUM_DIMS_REG,

		CTRL_REG,
		MODE_REG,

		TRIGGER_USER_REG, // trigger from the user
		trigger_pmod, // trigger from PMOD

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

	parameter WAIT_TRIG = 2'b0, FIRST_TRIGGER = 2'b1, WAIT_DONE_TRIG = 2'b11;

	/*********/
	/* Ports */
	/*********/

	input rstn;
	input clk;

	input [19:0] START_VAL_0_REG;
	input [19:0] START_VAL_1_REG;
	input [19:0] START_VAL_2_REG;
	input [19:0] START_VAL_3_REG;

	input [19:0] STEP_SIZE_0_REG;
	input [19:0] STEP_SIZE_1_REG;
	input [19:0] STEP_SIZE_2_REG;
	input [19:0] STEP_SIZE_3_REG;

	input [4:0]  DEMUX_0_REG;
	input [4:0]  DEMUX_1_REG;
	input [4:0]  DEMUX_2_REG;
	input [4:0]  DEMUX_3_REG;

	input [1:0]  DAC_0_GROUP_REG;
	input [1:0]  DAC_1_GROUP_REG;
	input [1:0]  DAC_2_GROUP_REG;
	input [1:0]  DAC_3_GROUP_REG;

	// assume that CYCLES_TILL_READOUT_REG is less than LOADING_SPI
	input [31:0] DWELL_CYCLES_REG;
	input [15:0] CYCLES_TILL_READOUT_REG; // the number of clock cycles until AWG can be run

	input [9:0]  PVP_WIDTH_REG;
	input [2:0]  NUM_DIMS_REG;


	input [28:0] CONFIG_REG; // for configuring the DACs: [28:24] is demux value, [23:0] is the SPI message. won't run unless its != 0

	input  [3:0] CTRL_REG; // [LDACN, CLRN, RSTN, TRIGGER_SELECT] // trigger select choses whether you are triggering from PMOD or from the Jupyter Notebook
	input  [1:0] MODE_REG;

	input        TRIGGER_USER_REG; // trigger from the user
	input		 trigger_pmod; // trigger from PMOD (i.e. AWGs)

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
	logic		trigger_from; // where you get the trigger from (either the PMOD[0] or the Jupyter Notebook [1]), and the actual pin keeping the system running/iterating
	logic       trigger_pvp; 

	///////// FSM Signals //////////
	logic [3:0]  curr_state, next_state;
	logic [31:0] dwell_counter;   // cycle for DWELL_CYCLES
	logic [31:0] next_mosi;
	logic [1:0]  which_dac, which_period;
	logic 		 wait_to_next_cycle;
	logic [31:0] ldac_counter;
	logic 		 ldacn_blip;
	logic		 init_load; // used to set all the DACs to their starting values at the beginning of the FSM

	/////////////////////////


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
	

	logic [1:0] dac_0_group, dac_1_group, dac_2_group, dac_3_group;	// the group can be either 00, 01, 02, or 03.
	logic [3:0] group0, group1, group2, group3;	// a set of 4 bits that indicates which dacs are in a group (group0 = 1010 means dac3 and dac1 are in group0)
	logic       group_0_en, group_1_en, group_2_en, group_3_en;	// Group Variables (i.e. if the current group is enabled or not. Used to change/update the current DAC levels)	
	logic [2:0] number_group_0, number_group_1, number_group_2, number_group_3;  // the number of DACs in each group

	logic       top_g0, top_g1, top_g2, top_g3;
	logic [1:0] dac_g0, dac_g1, dac_g2, dac_g3;
	logic [1:0] dac_no_g0, dac_no_g1, dac_no_g2, dac_no_g3;
	logic        last_0, last_1, last_2, last_3; // when the last number we reached was at the top of 0, 1, 2, or 3, we raise this flag.

	assign dac_0_group = DAC_0_GROUP_REG;
	assign dac_1_group = DAC_1_GROUP_REG;
	assign dac_2_group = DAC_2_GROUP_REG;
	assign dac_3_group = DAC_3_GROUP_REG;

	// quick assignment (number DACs in each group)
	assign number_group_0 = (dac_0_group == 2'b00) + (dac_1_group == 2'b00) + (dac_2_group == 2'b00) + (dac_3_group == 2'b00); // used for constraints
	assign number_group_1 = (dac_0_group == 2'b01) + (dac_1_group == 2'b01) + (dac_2_group == 2'b01) + (dac_3_group == 2'b01);
	assign number_group_2 = (dac_0_group == 2'b10) + (dac_1_group == 2'b10) + (dac_2_group == 2'b10) + (dac_3_group == 2'b10);
	assign number_group_3 = (dac_0_group == 2'b11) + (dac_1_group == 2'b11) + (dac_2_group == 2'b11) + (dac_3_group == 2'b11);

	// quick assignment (top)
	assign top_g0 = ({top_0, top_1, top_2, top_3} & group0) == group0; //(top_0 | ~group0[3]) & (top_1 | ~group0[2]) & (top_2 | ~group0[1]) & (top_3 | ~group0[0]);
	assign top_g1 = ({top_0, top_1, top_2, top_3} & group1) == group1;
	assign top_g2 = ({top_0, top_1, top_2, top_3} & group2) == group2;
	assign top_g3 = ({top_0, top_1, top_2, top_3} & group3) == group3;

	// LOGIC FOR GROUPS IN THE DAC LOADING
	always_comb begin
		which_period = (dwell_counter < LOADING_SPI) ? 2'b00 : (dwell_counter < 2*LOADING_SPI) ? 2'b01 : (dwell_counter < 3*LOADING_SPI) ? 2'b10 : 2'b11;

		// assign groupdacs according to which DACs are on in which group
		group0 = { dac_0_group==0, dac_1_group==0, dac_2_group==0, dac_3_group==0 };
		group1 = { dac_0_group==1, dac_1_group==1, dac_2_group==1, dac_3_group==1 };
		group2 = { dac_0_group==2, dac_1_group==2, dac_2_group==2, dac_3_group==2 };
		group3 = { dac_0_group==3, dac_1_group==3, dac_2_group==3, dac_3_group==3 };

		dac_g0 = ((group0[3]) ? 0 : (group0[2]) ? 1 : (group0[1]) ? 2 : 3);
		dac_g1 = ((group1[3]) ? 0 : (group1[2]) ? 1 : (group1[1]) ? 2 : 3);
		dac_g2 = ((group2[3]) ? 0 : (group2[2]) ? 1 : (group2[1]) ? 2 : 3);
		dac_g3 = ((group3[3]) ? 0 : (group3[2]) ? 1 : (group3[1]) ? 2 : 3);

		// if d0 wasn't in the first period, chose from the second
		dac_no_g0 = ((~group0[3]) ? (group0[1]) ? 2 : 3 : (group0[2]) ? 1 : (group0[1]) ? 2 : 3);
		dac_no_g1 = ((~group1[3]) ? (group1[1]) ? 2 : 3 : (group1[2]) ? 1 : (group1[1]) ? 2 : 3);
		dac_no_g2 = ((~group2[3]) ? (group2[1]) ? 2 : 3 : (group2[2]) ? 1 : (group2[1]) ? 2 : 3);
		dac_no_g3 = ((~group3[3]) ? (group3[1]) ? 2 : 3 : (group3[2]) ? 1 : (group3[1]) ? 2 : 3);
		

		case(NUM_DIMS_REG)

			1: // Case where there is only one dimension
			begin 
					if 		    (curr_state == S_STALL)  which_dac = 0;
					else 							     which_dac = (which_period==0) ? dac_g0 : (which_period==1) ? (group0[2]) ? 1 : (group0[1]) ? 2 : 3: (which_period==2) ? (group0[1]) ? 2 : 3 : 3;
			end

			2: // Case where there are two dimensions
			begin

				// if there is only one DAC is the group sending during SEND cycle 0
				if 		(number_group_0 == 1) begin
					if 		(curr_state == S_STALL)  which_dac = 0;
					else if (curr_state == S_SEND_0) which_dac =  dac_g0;
					else 							 which_dac =  ((which_period==1) ? dac_g1 : (which_period==2) ? dac_no_g1 : (~group1[3] | ~group1[2] | ~group1[1]) ? 3 : group1[1] ? 2 : 3);
				end
				else if (number_group_0 == 2) begin
					if 		(curr_state == S_STALL)  which_dac = 0;
					else if (curr_state == S_SEND_0) which_dac =  (which_period==1) ? dac_g0 : dac_no_g0;
					else 							 which_dac =  (which_period==2) ? dac_g1 : dac_no_g1;
				end
				else begin // 3 dacs in Group 0 begin
					if       (curr_state == S_STALL)  which_dac = 0;
					else if  (curr_state == S_SEND_0) which_dac = (which_period==0) ? dac_g0 : (which_period==1) ? dac_no_g0 : (~group0[3] | ~group0[2] | ~group0[1]) ? 3 : group0[1] ? 2 : 3;
					else 							  which_dac = dac_g2;
				end
			end

			3: // Case where there are three dimensions
			begin
				if 		(number_group_0 == 1) begin

					if 		(curr_state == S_STALL)  which_dac = 0;

					else if (curr_state == S_SEND_0) which_dac =  dac_g0;

					else if (curr_state == S_SEND_1) 
						if (number_group_1 == 1)
							which_dac =  dac_g1;
						else 
							which_dac = (which_period==1) ? dac_g1 : dac_no_g1;

					else    					     
						if (number_group_2 == 1)
							which_dac =  dac_g2;
						else 
							which_dac = (which_period==2) ? dac_g2 : dac_no_g2;

				end
				else begin // there are two DACs in group 0
					if 		(curr_state == S_STALL)  which_dac = 0;
					else if (curr_state == S_SEND_0) which_dac =  (which_period==1) ? dac_g0 : dac_no_g0;
					else if (curr_state == S_SEND_1) which_dac = dac_g1;
					else 						     which_dac = dac_g2;
				end
				
			end

			// Case where there are four dimensions
			4:
			begin
					if 		(curr_state == S_STALL)  which_dac = 0;
					else if (curr_state == S_SEND_0) which_dac = dac_g0;
					else if (curr_state == S_SEND_1) which_dac = dac_g1;
					else if (curr_state == S_SEND_2) which_dac = dac_g2;
					else                             which_dac = dac_g3;
			end

			default: which_dac = 0;
		endcase
	end


	/////////////////////////////////////////////////////////////////////////////////

	assign {ldacn_user, clrn_user, rstn_user, trigger_from} = CTRL_REG;

	assign ldacn =    (MODE_REG == 2'b11) ?    ldacn_user : ldacn_fsm;
	assign resetn = (((MODE_REG == 2'b11) ?     rstn_user : 1'b1)); // allows user to control reset the DAC if you're in MODE 3
	assign clrn =     (MODE_REG == 2'b11) ?     clrn_user : 1'b1;
	assign trigger_fsm = (trigger_from) ? TRIGGER_USER_REG : trigger_pmod;


	////////////////// MINI TRIGGER FSM //////////////////

	/// TRIGGER DEVICE TO START LOADING A PVP PLOT
	logic [8:0] trigger_counter;
	logic [1:0] trig_state, next_trig_state;
	always_ff @(posedge clk) begin
		case (trig_state)
			WAIT_TRIG: begin
				trigger_counter <= 0;
				if (trigger_fsm) next_trig_state <= FIRST_TRIGGER;
				else             next_trig_state <= WAIT_TRIG;
			end
			FIRST_TRIGGER: begin
				trigger_counter <= trigger_counter + 1;
				if (trigger_counter == NUM_DIMS_REG*HOLD_SIGNAL) next_trig_state <= WAIT_DONE_TRIG;
				else								next_trig_state <= FIRST_TRIGGER;
			end
			WAIT_DONE_TRIG: begin
				trigger_counter <= 0;
				if (trigger_fsm)  next_trig_state <= WAIT_DONE_TRIG;
				else 			  next_trig_state <= WAIT_TRIG;
			end
			default: next_trig_state <= WAIT_TRIG;
		endcase
	end

	assign trig_state = next_trig_state;
	assign trigger_pvp = (next_trig_state==FIRST_TRIGGER);

	//////////////////////////////////////////////////////

	// next MUX and MOSI logic
	always_ff @(posedge clk) begin
		// MOSI Output
		if 		((curr_state == S_STALL) | (dwell_counter==0) | ((dwell_counter>=(LOADING_SPI-1)) & (dwell_counter<=LOADING_SPI)) | ((dwell_counter>=(2*(LOADING_SPI-1))) & (dwell_counter<=2*LOADING_SPI)) | ((dwell_counter>=(3*(LOADING_SPI-1))) & (dwell_counter<=3*LOADING_SPI))) 	next_mosi <= past_mosi;
		else if ((curr_state==CONFIG_STATE) & (dwell_counter>0))					next_mosi <= CONFIG_REG[23:0];
		else if (which_dac == 0) 													next_mosi <= mosi_0;
		else if (which_dac == 1) 													next_mosi <= mosi_1;
		else if (which_dac == 2) 													next_mosi <= mosi_2;
		else 					 													next_mosi <= mosi_3;
	end
	
	// FINITE STATE MACHINE
	always_ff @(posedge clk) begin
		past_done <= 0;
		rstn_3 <= 1;
		rstn_2 <= 1;
		rstn_1 <= 1;
		rstn_0 <= 1;
		init_load <= init_load;

		last_0 <= last_0;
		last_1 <= last_1;
		last_2 <= last_2;
		last_3 <= last_3;

		dwell_counter <= dwell_counter;

		on_off <= 0;

		if (~rstn) begin
			// State register.
			next_state 	<= WAIT;
			past_mosi <= 0;
			past_select_mux <= 0;

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
					past_mosi	  <= 0;
					past_select_mux	  <= 0;

					past_done <= done;

					init_load <= 1; // if the first value isn't loaded yet, we need to go through every dimension of the SPI to set their starting value

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

					//////////////////////////
					/// STALL STATE LOGIC ////
					//////////////////////////

				// stall state; all pvp cycles start here
				S_STALL: begin
					
					rstn_3 <= 1;
					rstn_2 <= 1;
					rstn_1 <= 1;
					rstn_0 <= 1;
					past_done <= done;

					 // will only load the next DACs if the trigger_pvp is still 1 (i.e. gives user control to stop partway through the pvp generation)
					if (trigger_pvp & !done & !wait_to_next_cycle) begin
							next_state <= S_SEND_0;
							dwell_counter <= 0;
					end else begin
							if (wait_to_next_cycle) begin next_state <= S_STALL; dwell_counter <= dwell_counter + 1; end 
							else if (done) 			begin next_state <= WAIT;    dwell_counter <= dwell_counter;     end
							else 					begin next_state <= S_STALL; dwell_counter <= dwell_counter;     end 
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
					on_off <= 	  (((dwell_counter >= 99) & (dwell_counter <= 116) & (number_group_0>=1))) 
								| ((dwell_counter >= (LOADING_SPI-1)+100) & (dwell_counter <= (LOADING_SPI-1)+117) & (number_group_0>=2))
								| ((dwell_counter >= 2*(LOADING_SPI-1)+100) & (dwell_counter <= 2*(LOADING_SPI-1)+117) & (number_group_0>=3)) 
								| ((dwell_counter >= 3*(LOADING_SPI-1)+100) & (dwell_counter <= 3*(LOADING_SPI-1)+117) & (number_group_0==4)) ? 1'b1 : 1'b0;

					// cycle until dwell counter has been spent. If we're not at the top of the stack, return to stall
					if ((dwell_counter == number_group_0*(LOADING_SPI-1)) & !top_g0)      // inside DAC 1 loop
					begin 
						if 		((last_0 == 1) & (NUM_DIMS_REG == 1)) 				begin past_done <= 1; next_state <= WAIT; end
						else if ((last_0 == 1) | (init_load & (NUM_DIMS_REG > 1))) 		  next_state <= S_SEND_1;  // the previous DAC was at the top of the DAC0 stack, which means that we can go to the next DAC now
						else 			  				 							begin next_state <= S_STALL; init_load <= 0; end
					end
					else if ((dwell_counter == number_group_0*(LOADING_SPI-1)) & top_g0)  // if we've' gone full through list, set up to go to next DAC
					begin
						next_state <= S_STALL;
						last_0 <= 1;

						if ((NUM_DIMS_REG == 1) & (last_0)) begin past_done <= 1; end

						rstn_0 <= ~group0[3];
						rstn_1 <= ~group0[2];
						rstn_2 <= ~group0[1];
						rstn_3 <= ~group0[0]; 
					end 
				end


				S_SEND_1: begin

					next_state <= S_SEND_1;
					past_mosi <= mosi_o;
					past_select_mux <= select_mux;
					dwell_counter <= dwell_counter + 1; 
					last_0 <= 0;
					past_done <= done;
					on_off <= 	  ((dwell_counter >=   (LOADING_SPI-1)+100) & (dwell_counter <=   (LOADING_SPI-1)+117) & ((number_group_0+number_group_1)>=1))
								| ((dwell_counter >= 2*(LOADING_SPI-1)+100) & (dwell_counter <= 2*(LOADING_SPI-1)+117) & ((number_group_0+number_group_1)>=2)) 
								| ((dwell_counter >= 3*(LOADING_SPI-1)+100) & (dwell_counter <= 3*(LOADING_SPI-1)+117) & ((number_group_0+number_group_1)>=3)) ? 1'b1 : 1'b0;

					// cycle until dwell counter has been spent. If we're not at the top of the stack, return to S_STALL

					if ((dwell_counter == ((number_group_0+number_group_1)*(LOADING_SPI-1))) & !top_g1)      // inside DAC 1 loop
					begin
						if     ((last_1 == 1) & (NUM_DIMS_REG == 2)) 			     begin past_done <= 1; next_state <= WAIT; end
						else if (last_1 == 1 | (init_load & (NUM_DIMS_REG > 2))) 		   next_state <= S_SEND_2;  // the previous DAC was at the top of the DAC0 stack, which means that we can go to the next DAC now
						else 			  										 	 begin next_state <= S_STALL; init_load <= 0; end
					end 
					else if ((dwell_counter == (number_group_0+number_group_1)*(LOADING_SPI-1)) & top_g1)  // if we've' gone full through list, go to next DAC
					begin 
						next_state <= S_STALL;
						last_1 <= 1;

						if ((NUM_DIMS_REG == 2) & (last_1)) begin past_done <= 1; end
						
						rstn_0 <= ~group1[3];
						rstn_1 <= ~group1[2];
						rstn_2 <= ~group1[1];
						rstn_3 <= ~group1[0];
					end
				end


				S_SEND_2: begin

					next_state <= S_SEND_2;
					past_mosi <= mosi_o;
					past_select_mux <= select_mux;
					dwell_counter <= dwell_counter + 1;
					past_done <= done;
					last_1 <= 0;
					on_off <= 	  ((dwell_counter >= 2*(LOADING_SPI-1)+100) & (dwell_counter <= 2*(LOADING_SPI-1)+117) & ((number_group_0+number_group_1+number_group_2)>=1)) 
								| ((dwell_counter >= 3*(LOADING_SPI-1)+100) & (dwell_counter <= 3*(LOADING_SPI-1)+117) & ((number_group_0+number_group_1+number_group_2)>=2)) ? 1'b1 : 1'b0;

					// cycle until dwell counter has been spent. If we're not at the top of the stack, return to S_STALL

					if ((dwell_counter == ((number_group_0+number_group_1+number_group_2)*(LOADING_SPI-1))) & !top_g2)    // inside DAC 1 loop  
					begin
						if     ((last_2 == 1) & (NUM_DIMS_REG == 3)) 				begin past_done <= 1; next_state <= WAIT; end
						else if (last_2 == 1 | (init_load & (NUM_DIMS_REG > 3))) 		  next_state <= S_SEND_3;  // the previous DAC was at the top of the DAC0 stack, which means that we can go to the next DAC now
						else 			   											begin next_state <= S_STALL; init_load <= 0; end
					end 
					else if ((dwell_counter == ((number_group_0+number_group_1+number_group_2)*(LOADING_SPI-1))) & top_g2)   // if we've' gone full through list, go to next DAC
					begin
						next_state <= S_STALL;
						last_2 <= 1;

						if ((NUM_DIMS_REG == 3) & (last_2)) begin past_done <= 1; end
						
						rstn_0 <= ~group2[3];
						rstn_1 <= ~group2[2];
						rstn_2 <= ~group2[1];
						rstn_3 <= ~group2[0];
					end
				end


				S_SEND_3: begin
					
					next_state <= S_SEND_3;
					past_mosi <= mosi_o;
					past_select_mux <= select_mux;
					dwell_counter <= dwell_counter + 1; 
					past_done <= done;
					last_2 <= 0;
					on_off <= ((dwell_counter >= 3*(LOADING_SPI-1)+100) & (dwell_counter <= 3*(LOADING_SPI-1)+117)) ? 1 : 0;

					// cycle until dwell counter has been spent. If we're not at the top of the stack, return to stall
					if ((dwell_counter == ((number_group_0+number_group_1+number_group_2+number_group_3)*(LOADING_SPI-1))) & !top_g3)    
					begin
						if ((last_3 == 1) & (NUM_DIMS_REG == 4)) begin past_done <= 1; next_state <= WAIT; end
						else 									 begin next_state <= S_STALL; init_load <= 0; end
					end 
					else if ((dwell_counter == ((number_group_0+number_group_1+number_group_2+number_group_3)*(LOADING_SPI-1))) & top_g3)   // inside DAC 1 loop
					begin 
						next_state <= S_STALL;
						last_3 <= 1;
						
						rstn_0 <= ~group3[3];
						rstn_1 <= ~group3[2];
						rstn_2 <= ~group3[1];
						rstn_3 <= ~group3[0];
					end 
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
	// If the DAC is in a group, then it will update when that group is enabled.
	assign group_0_en = ((dwell_counter ==             0) & (curr_state == S_SEND_0) & (~last_0)) | (curr_state == WAIT);
	assign group_1_en = ((dwell_counter ==   LOADING_SPI* number_group_0) & (curr_state == S_SEND_1) & (~last_1)) | (curr_state == WAIT);
	assign group_2_en = ((dwell_counter ==   LOADING_SPI*(number_group_0+number_group_1)) & (curr_state == S_SEND_2) & (~last_2)) | (curr_state == WAIT);
	assign group_3_en = ((dwell_counter ==   LOADING_SPI*(number_group_0+number_group_1+number_group_2)) & (curr_state == S_SEND_3) & (~last_3)) | (curr_state == WAIT);

	assign dac0_en = init_load ? 1'b0 : (dac_0_group == 2'b00) ? group_0_en : (dac_0_group == 2'b01) ? group_1_en : (dac_0_group == 2'b10) ? group_2_en : (dac_0_group == 2'b11) ? group_3_en : 0;
	assign dac1_en = init_load ? 1'b0 : (dac_1_group == 2'b00) ? group_0_en : (dac_1_group == 2'b01) ? group_1_en : (dac_1_group == 2'b10) ? group_2_en : (dac_1_group == 2'b11) ? group_3_en : 0;
	assign dac2_en = init_load ? 1'b0 : (dac_2_group == 2'b00) ? group_0_en : (dac_2_group == 2'b01) ? group_1_en : (dac_2_group == 2'b10) ? group_2_en : (dac_2_group == 2'b11) ? group_3_en : 0;
	assign dac3_en = init_load ? 1'b0 : (dac_3_group == 2'b00) ? group_0_en : (dac_3_group == 2'b01) ? group_1_en : (dac_3_group == 2'b10) ? group_2_en : (dac_3_group == 2'b11) ? group_3_en : 0;

	// assign the mosi and output for demuxing to DACs based on current state
	assign mosi_o = next_mosi; //((curr_state==S_STALL) | (dwell_counter==0)) ? past_mosi   : ((curr_state==S_SEND_0) & dwell_counter>0) ? mosi_0 : (curr_state==S_SEND_1) ? mosi_1                : (curr_state==S_SEND_2) ? mosi_2 			   : (curr_state==S_SEND_3) ? mosi_3 				: 0;
	assign select_mux = ((curr_state==S_STALL) | (dwell_counter==0)) ? past_select_mux : (curr_state==CONFIG_STATE) ? CONFIG_REG[28:24] : (which_dac==0) ? DEMUX_0_REG[4:0] : (which_dac==1) ? DEMUX_1_REG[4:0] : (which_dac==2) ? DEMUX_2_REG[4:0] : (which_dac==3) ? DEMUX_3_REG[4:0] : 4'b1111;
	assign trigger_spi_o = on_off;
	assign readout_o 	 = (dwell_counter > CYCLES_TILL_READOUT_REG); // CHANGE TO CYCLES_TILL_READOUT
	assign done = past_done;
	assign wait_to_next_cycle = ((dwell_counter >= LOADING_SPI) & (dwell_counter < DWELL_CYCLES_REG)) ? 1 : 0; // if we're waiting for the next cycle to start  // if all the DACs have all finished running, then we are done
	assign ldacn_fsm 	      = ((curr_state != WAIT) & wait_to_next_cycle & (dwell_counter > (DWELL_CYCLES_REG - HOLD_SIGNAL)) & (dwell_counter < DWELL_CYCLES_REG)) ? 1'b0 : 1'b1;

	no_mem_sweep_fsm 
		no_mem_sweep_0 (
			.rstn		(rstn_0),
			.clk		(clk),

			.enable     (dac0_en),
			.direction  ((STEP_SIZE_0_REG[19])),
			.mode       (MODE_REG),
			.index		(8'b0),

			.start		(START_VAL_0_REG),
			.step       (STEP_SIZE_0_REG[18:0]),

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
			.direction  ((STEP_SIZE_1_REG[19])),
			.mode       (MODE_REG),
			.index		(8'b0),

			.start		(START_VAL_1_REG),
			.step       (STEP_SIZE_1_REG[18:0]),
			
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
			.direction  ((STEP_SIZE_2_REG[19])),
			.mode       (MODE_REG),
			.index		(8'b0),

			.start		(START_VAL_2_REG),
			.step       (STEP_SIZE_2_REG[18:0]),

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
			.direction  ((STEP_SIZE_3_REG[19])),
			.mode       (MODE_REG),
			.index		(8'b0),

			.start		(START_VAL_3_REG),
			.step       (STEP_SIZE_3_REG[18:0]),

			.base       (base_3),
			.top        (top_3),
			.mosi		(mosi_3),
			.DEPTH	    (PVP_WIDTH_REG)
			);

	

endmodule