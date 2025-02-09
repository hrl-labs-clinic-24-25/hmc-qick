/**
	A module that runs a pvp plot generator using a Finite State Machine
*/

module pvp_fsm_gen (
		// Reset and clock.
		rstn,
		clk,

    	// parameter inputs.
		data_i,
		tvalid_i,

		// Iterator interface with FSM
		iter_rd_en_o,
        iter_wr_en_o,
		iter_empty_i,
		iter_full_i,

        iter_din_o,

        c_mux_o,
		
	);

/**************/
/* Parameters */
/**************/

parameter SIZE = 256;
parameter DWELL_TIME = 10; // will be set

/*********/
/* Ports */
/*********/
input						rstn;
input						clk;

input 	[97:0]			    data_i;
input					    tvalid_i;

output						iter_rd_en_o;
output						iter_wr_en_o;
input						iter_empty_i;
input	            	    iter_full_i;


output	[23:0]         	    iter_din_o;
output	[4:0]         	    c_mux_o;


/********************/
/* Internal signals */
/********************/

reg  iter_rd_en;
reg  iter_empty;

reg [23:0] dac_1;
reg [23:0] dac_2;
reg [23:0] dac_3;
reg [23:0] dac_4;

reg muxes_enabled;
reg sendorload_trigger;
reg iter_full;

reg	[23:0]         	    iter_din_1_o;
reg	[23:0]         	    iter_din_2_o;
reg	[23:0]         	    iter_din_3_o;
reg	[23:0]         	    iter_din_4_o;

reg	[4:0]         	    c_mux_1_o;
reg	[4:0]         	    c_mux_2_o;
reg	[4:0]          	    c_mux_3_o;
reg	[4:0]         	    c_mux_4_o;

/***************/
/* FSM Machine */
/***************/

	// DAC:   1     2     3     4
// LOADING: 0001, 0010, 0011, 0100  --- saving into bram
// SENDING: 0101, 0110, 0111, 1000  --- sending from iterator
parameter WAIT_LOAD = 4'b0000, WAIT_SEND = 4'b1111, LOAD = 4'b0001, LOAD_MUX = 4'b0010, SEND = 4'b0101;
parameter TIMES_THRU = 256;

reg[3:0] curr_state, next_state;

// mux_x -- the value for mux_x
reg[4:0] mux_1, n_mux_1;
reg[4:0] mux_2, n_mux_2;
reg[4:0] mux_3, n_mux_3;
reg[4:0] mux_4, n_mux_4;

reg[16:0] counter;
reg[7:0]  iter_count;

// FINITE STATE MACHINE
// Registers.
always @(posedge clk) begin

	if (~rstn) begin
		// State register.
		next_state 	<= WAIT_LOAD;

		n_mux_1 <= 5'b00000;
		n_mux_2 <= 5'b00000;
		n_mux_3 <= 5'b00000;
		n_mux_4 <= 5'b00000;


		iter_rd_en <= 0;


        counter <= 0;
        iter_count <= 0;
	end 
	else begin

		// muxes are only set during the WAIT_LOAD stage of the system; 
			// when it is first triggered, the muxes are set
		if (muxes_enabled) begin
			n_mux_1 <= mux_1;
			n_mux_2 <= mux_2;
			n_mux_3 <= mux_3;
			n_mux_4 <= mux_4;
		end else begin
			n_mux_1 <= c_mux_1_o;
			n_mux_2 <= c_mux_2_o;
			n_mux_3 <= c_mux_3_o;
			n_mux_4 <= c_mux_4_o;
		end
		
		// State register.
		case(curr_state)
			WAIT_LOAD: begin

                iter_count <= 0;
                counter <= 0;
                
				if (muxes_enabled)  next_state <= LOAD_MUX;
                else         	    next_state <= WAIT_LOAD;

            end
			LOAD_MUX: begin
                iter_count <= 0;
                counter <= 0;

				next_state <= LOAD;
			end
            LOAD: begin

                iter_count <= 0;
                counter <= 0;
                
                if (iter_full) next_state <= WAIT_SEND;
                else           next_state <= LOAD;

            end
            WAIT_SEND: begin

                iter_count <= 0;
                counter <= 0;

                if (sendorload_trigger) begin  next_state <= SEND; end
                else         begin  next_state <= WAIT_SEND; end

            end
            SEND: begin
                if (iter_count < TIMES_THRU) 
				begin // if we haven't gone through at 256 columns yet

                    // continue time in loop
                    next_state <= SEND;

                    // if the counter's gone through the "DWELL TIME", move on to the next iterator loop and enable write enable again for the next DAC
                    if (counter == DWELL_TIME) 
					begin   
						// restart counter and continue sending
                        // increment counter for the loop
                        iter_count <= iter_count + 1;
                        counter <= 0;
                    end else 
					begin
                        counter <= counter + 1;
                        iter_count <= iter_count;
                    end
				end else begin 
				iter_count <= iter_count + 1;
                        	counter <= 0;
				next_state <= WAIT_SEND;
			end

			end
			default: begin iter_count <= 0; counter <= 0; next_state <= WAIT_LOAD; end
		endcase
	end
end


assign iter_wr_en_o = (curr_state == SEND) && (counter == 0);

// unsure if the timing will work for this; it may take multiple cycles to actually "load" something into memory
assign iter_rd_en_o = (curr_state == LOAD & ~muxes_enabled); // wait until after we have loaded the muxes with the values that we want
assign iter_empty = iter_empty_i;
assign iter_full  = iter_full_i;

assign iter_din_1_o = (curr_state == LOAD & sendorload_trigger) ? dac_1 : 24'b0;
assign iter_din_2_o = (curr_state == LOAD & sendorload_trigger) ? dac_2 : 24'b0;
assign iter_din_3_o = (curr_state == LOAD & sendorload_trigger) ? dac_3 : 24'b0;
assign iter_din_4_o = (curr_state == LOAD & sendorload_trigger) ? dac_4 : 24'b0;


assign curr_state = next_state;

assign c_mux_1_o = n_mux_1;
assign c_mux_2_o = n_mux_2;
assign c_mux_3_o = n_mux_3;
assign c_mux_4_o = n_mux_4;


// SINCE WE'RE NOT DOING MULTIPLE DAC'S YET; THIS WILL BE CHANGED WHEN WE HAVE AN INNER FOR LOOP (FOR TWO DACS)
assign c_mux_o = c_mux_1_o;
assign iter_din_o = iter_din_1_o;

/**********************/
/* Begin Architecture */
/**********************/

// Control block.
ctrl 
	#()
	ctrl_i
	(
		// Reset and clock.
		.rstn			(rstn			),
		.clk			(clk			),

		.mem_i          (data_i),

 
		// dac control.
		.dac_1_o		    (dac_1		   ),
		.dac_2_o		    (dac_2		   ),
		.dac_3_o		    (dac_3		   ),
		.dac_4_o		    (dac_4		   ),

		// Output mux selection.
		.mux_1_o			(mux_1			),
		.mux_2_o			(mux_2			),
		.mux_3_o			(mux_3			),
		.mux_4_o			(mux_4			),

		// Output enable.
        .sendorload_o      (sendorload_trigger),
		.mux_en_o		       (muxes_enabled			) // output by the control message about whether or not we should start loading the muxes
	);

endmodule
