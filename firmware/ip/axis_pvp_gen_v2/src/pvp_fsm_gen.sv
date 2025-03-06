/**
	A module that runs a pvp plot generator using a Finite State Machine
	Zoe Worrall, zworrall@g.hmc.edu, March 3, 2025
*/


module pvp_fsm_gen  #(parameter [15:0] DWELL_CYCLES = 16'd100,
					parameter [19:0] STEP_SIZE = 20'h00001, 
					parameter [7:0] NUM_CYCLES = 8'd10,
					parameter [1:0] NUM_DACS = 2'd4)
    (
		// Reset and clock.
		input rstn,
		input clk,

        input trigger,

		// Inputs from PYNQ registers
		input logic [19:0] start_0_i,
		input logic [19:0] start_1_i,
		input logic [19:0] start_2_i,
		input logic [19:0] start_3_i,

    	// parameter inputs.
		output [31:0] mosi_o,
        output [1:0]  which_dac_o,
        output        readout_o
	);

/**************/
/* Parameters */
/**************/

// parameter SIZE = 16;
// parameter DWELL_TIME = 100; // will be set

/*********/
/* Ports */
/*********/
// input						rstn;
logic 						rstn_0, rstn_1, rstn_2, rstn_3;
// input						clk;

// input                       trigger;

// output 	[31:0]			    mosi_o;
// output	[1:0]			    which_dac_o;
// output                      readout_o;


/********************/
/* Internal signals */
/********************/

logic [31:0] mosi_0;
logic [31:0] mosi_1;
logic [31:0] mosi_2;
logic [31:0] mosi_3;
logic [31:0] past_mosi;

logic top_0;
logic top_1;
logic top_2;
logic top_3;

logic base_0;
logic base_1;
logic base_2;
logic base_3;

logic dac0_en;
logic dac1_en;
logic dac2_en;
logic dac3_en;

logic sendorload_trigger;

logic [3:0] curr_state, next_state;
logic [15:0] dwell_counter;   // cycle for DWELL_CYCLES


//logic [19:0] D0_START;
//assign D0_START = 20'b0000_0000_0000_0000_0000;

//logic [19:0] D1_START;
//assign D1_START = 20'b0000_0000_0000_0000_0100;

//logic [19:0] D2_START;
//assign D2_START = 20'b0000_0000_0000_0000_1000;

//logic [19:0] D3_START;
//assign D3_START = 20'b0000_0000_0000_0000_1100;

/***************/
/* FSM Machine */
/***************/

// FSM States:
		// wait -- waits for DWELL_CYCLES amount of time
// wait   -- before triggered and running the full cycle this is where the FSM rests
// s_send -- send part of the send state
// s_wait -- the machine is waiting to be set
// s_stall -- for when there are multiple dacs, to make sure that the SPI is set before continuing to run readout samples
parameter WAIT = 4'b0000, S_SEND_0 = 4'b0001, S_SEND_1 = 4'b0010, S_SEND_2 = 4'b0100, S_SEND_3 = 4'b1000, S_WAIT = 4'b1110, S_STALL = 4'b1101;

assign curr_state = next_state;
assign dac0_en = ((dwell_counter == 0) & (curr_state == S_SEND_0)) | (curr_state == WAIT);
assign dac1_en = ((dwell_counter == 0) & (curr_state == S_SEND_1)) | (curr_state == WAIT);
assign dac2_en = ((dwell_counter == 0) & (curr_state == S_SEND_2)) | (curr_state == WAIT);
assign dac3_en = ((dwell_counter == 0) & (curr_state == S_SEND_3)) | (curr_state == WAIT);

assign mosi_o      = ((curr_state==S_STALL) | (dwell_counter==0)) ? past_mosi : ((curr_state==S_SEND_0) & dwell_counter>0) ? mosi_0 : (curr_state==S_SEND_1) ? mosi_1 : (curr_state==S_SEND_2) ? mosi_2 : (curr_state==S_SEND_3) ? mosi_3 : 0;
assign which_dac_o = (curr_state==S_SEND_0) ? 2'b00 : (curr_state==S_SEND_1) ? 2'b01 : (curr_state==S_SEND_2) ? 2'b10 : (curr_state==S_SEND_3) ? 2'b11 : 2'b00; // this is hard to debug if we're always seeing first DAC and none of second (lol)

assign readout_o = (dwell_counter > DWELL_CYCLES/10); // CHANGE TO CYCLES_TILL_READOUT -- only possible in one of the readout states (dwell_counter is 0 in other states)

// FINITE STATE MACHINE
// Registers.
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
				rstn_3 <= 0;
				rstn_2 <= 0;
				rstn_1 <= 0;
				rstn_0 <= 0;
				past_mosi <= 0;
                
				if (trigger)  next_state <= S_STALL;
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

				// if      (top_3 & top_2 & top_1 & top_0) begin next_state <= WAIT; dwell_counter <= 0; rstn_0 <= 0; rstn_1 <= 0; rstn_2 <= 0; rstn_3 <= 0; end
                // else if (top_2) 					    begin 				      dwell_counter <= 0; rstn_0 <= 0; rstn_1 <= 0; rstn_2 <= 0; rstn_3 <= 1; end
                // else if (top_1) 					    begin 				      dwell_counter <= 0; rstn_0 <= 0; rstn_1 <= 0; rstn_2 <= 1; rstn_3 <= 1; end
                // else if (top_0) 					    begin 				      dwell_counter <= 0; rstn_0 <= 0; rstn_1 <= 1; rstn_2 <= 1; rstn_3 <= 1; end  // reset only 0

            end
			S_SEND_0: begin

				next_state <= S_SEND_0;
				past_mosi <= mosi_o;

				// cycle until dwell counter has been spent. If we're not at the top of the stack, return to stall
				if ((dwell_counter == DWELL_CYCLES) & !top_0)      begin dwell_counter <= 0;  next_state <= S_STALL; end // inside DAC 1 loop
				else if ((dwell_counter == DWELL_CYCLES) & top_0)  begin dwell_counter <= 0; next_state <= S_SEND_1; rstn_0 <= 0; end  // if we've' gone full through list, go to next DAC
				else 											  begin dwell_counter <= dwell_counter + 1; end  // we are waiting for full time

			end
            S_SEND_1: begin

				next_state <= S_SEND_1;
				past_mosi <= mosi_o;

				// cycle until dwell counter has been spent. If we're not at the top of the stack, return to stall
				if ((dwell_counter == DWELL_CYCLES) & !top_1)      begin dwell_counter <= 0;  next_state <= S_STALL; end // inside DAC 1 loop
				else if ((dwell_counter == DWELL_CYCLES) & top_1)  begin dwell_counter <= 0; next_state <= S_SEND_2; rstn_1 <= 0; end  // if we've' gone full through list, go to next DAC
				else 											  begin dwell_counter <= dwell_counter + 1; end  // we are waiting for full time

            end
            S_SEND_2: begin

				next_state <= S_SEND_2;
				past_mosi <= mosi_o;

				// cycle until dwell counter has been spent. If we're not at the top of the stack, return to stall
				if ((dwell_counter == DWELL_CYCLES) & !top_2)      begin dwell_counter <= 0;  next_state <= S_STALL; end // inside DAC 1 loop
				else if ((dwell_counter == DWELL_CYCLES) & top_2)  begin dwell_counter <= 0; next_state <= S_SEND_3; rstn_2 <= 0; end  // if we've' gone full through list, go to next DAC
				else 											  begin dwell_counter <= dwell_counter + 1; end  // we are waiting for full time

            end
            S_SEND_3: begin
                
				next_state <= S_SEND_3;
				past_mosi <= mosi_o;

				// cycle until dwell counter has been spent. If we're not at the top of the stack, return to stall
				if ((dwell_counter == DWELL_CYCLES) & top_3)          begin dwell_counter <= 0;  next_state <= WAIT; rstn_3 <= 0; end // inside DAC 1 loop
				else if ((dwell_counter == DWELL_CYCLES) & !top_3)    begin dwell_counter <= 0;  next_state <= S_STALL; end 
				else 									 begin dwell_counter <= dwell_counter + 1; end  // we are waiting for full time

			end
			default: begin dwell_counter <= 0; next_state <= WAIT; end
		endcase
	end
end

no_mem_sweep_fsm 
	#(
		.DEPTH	(NUM_CYCLES)
	)
	no_mem_sweep_0 (
        .rstn		(rstn_0),
		.clk		(clk),
        .enable     (dac0_en),
		.start		(start_0_i),
        .step       (STEP_SIZE),
        .base       (base_0),
        .top        (top_0),
		.mosi		(mosi_0)
		);

no_mem_sweep_fsm 
	#(
		.DEPTH	(NUM_CYCLES)
	)
	no_mem_sweep_1 (
        .rstn		(rstn_1),
		.clk		(clk),
        .enable     (dac1_en),
		.start		(start_1_i),
        .step       (STEP_SIZE),
        .base       (base_1),
        .top        (top_1),
		.mosi		(mosi_1)
		);

no_mem_sweep_fsm 
	#(
		.DEPTH	(NUM_CYCLES)
	)
	no_mem_sweep_2 (
        .rstn		(rstn_2),
		.clk		(clk),
        .enable     (dac2_en),
		.start		(start_2_i),
        .step       (STEP_SIZE),
        .base       (base_2),
        .top        (top_2),
		.mosi		(mosi_2)
		);

no_mem_sweep_fsm 
	#(
		.DEPTH	(NUM_CYCLES)
	)
	no_mem_sweep_3 (
        .rstn		(rstn_3),
		.clk		(clk),
        .enable     (dac3_en),
		.start		(start_3_i),
        .step       (STEP_SIZE),
        .base       (base_3),
        .top        (top_3),
		.mosi		(mosi_3)
		);
        

endmodule