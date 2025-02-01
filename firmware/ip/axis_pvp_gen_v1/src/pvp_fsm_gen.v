module pvp_fsm_gen (
		// Reset and clock.
		.rstn,
		.clk,

    	// parameter inputs.
		.data_i,
		.tvalid_i,

        // parameter outputs.
        .data_o,
        .select,

		// Iterator interface with FSM
		.iter_rd_en_o,
        .iter_wr_en_o,
		.iter_empty_i,
		.iter_full_i,
        .iter_din_o
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

input 	[96:0]			    data_i;
input					    tvalid_i;

input						iter_rd_en_o;
input						iter_wr_en_o;
output						iter_empty_i;
output	            	    iter_full_i;
output	[23:0]         	    iter_din_o;

output  [4:0]               select;  // to control the muxes

/********************/
/* Internal signals */
/********************/

wire						iter_rd_en;
wire						iter_empty;
wire		[23:0]			iter_din;


/***************/
/* FSM Machine */
/***************/

	// DAC:   1     2     3     4
// LOADING: 0001, 0010, 0011, 0100  --- saving into bram
// SENDING: 0101, 0110, 0111, 1000  --- sending from iterator
parameter WAIT_LOAD = 4'b0000, WAIT_SEND = 4'b1111, LOAD = 4'b0001, SEND_DAC1 = 4'b0101;
parameter TIMES_THRU = 256;

reg[3:0] curr_state, next_state;

reg[2:0] mux_1;
reg[2:0] mux_2;
reg[2:0] mux_3;
reg[2:0] mux_4;

reg[16:0] counter;
reg[7:0]  iter_count;

// FINITE STATE MACHINE
// Registers.
always @(posedge clk) begin
	if (~rstn) begin
		// State register.
		curr_state 	<= WAIT_LOAD;

		// Fifo dout register.
		mux_1 <= 0;
		mux_2 <= 0;
		mux_3 <= 0;

		fifo_rd_en <= 0;
		fifo_empty <= 0;
		fifo_dout <= 0;

		iter_rd_en <= 0;
		iter_empty <= 0;
		iter_dout <= 0;

        counter <= 0;
        iter_count <= 0;
	end 
    
    else begin
		// State register.
		case (curr_state)
			WAIT_LOAD: begin

                iter_count <= 0;
                counter <= 0;
                
				if (rdy_2_ld)  next_state <= LOAD;
                else           next_state <= WAIT_LOAD;
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

                if (trigger)   next_state <= SEND;
                else           next_state <= WAIT_SEND;
            end
            SEND_DAC1: 
                if (iter_count < TIMES_THRU) begin // if we haven't gone through at 256 columns yet

                    // continue time in loop
                    next_state <= SEND;

                    // if the counter's gone through the "DWELL TIME", move on to the next iterator loop and enable write enable again for the next DAC
                    if (counter == DWELL_TIME) begin   // restart counter and continue sending
                        // increment counter for the loop
                        iter_count <= iter_count + 1;
                        counter <= 0;
                    end else begin
                        counter <= counter + 1;
                        iter_count <= iter_count;
                    end
                end else begin // all columns have been done
                    next_state <= WAIT_SEND;

                    iter_count <= 0;
                    counter <= 0;
                end 
            end
		endcase
end 

assign iter_wr_en <= (curr_state == SEND) && (counter == 0);

// unsure if the timing will work for this; it may take multiple cycles to actually "load" something into memory
assign iter_rd_en <= (curr_state == LOAD);
assign iter_empty <= iter_empty_i;
assign iter_full  <= iter_full_i;
assign iter_din_o <= dac_1;

/**********************/
/* Begin Architecture */
/**********************/

reg [23:0] dac_1;
reg [23:0] dac_2;
reg [23:0] dac_3;
reg [23:0] dac_4;

reg [4:0] mux;

reg rdy_2_ld;
reg trigger;

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
		mux_o			(mux			),

		// Output enable.
        .trigger_o      (trigger)
		.en_o			(rdy_2_ld			)
	);

endmodule
