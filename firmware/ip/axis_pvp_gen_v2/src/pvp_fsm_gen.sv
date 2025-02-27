/**
	A module that runs a pvp plot generator using a Finite State Machine
*/

module pvp_fsm_gen (
		// Reset and clock.
		rstn,
		clk,

    	// parameter inputs.
		
		
	);

/**************/
/* Parameters */
/**************/

parameter SIZE = 16;
parameter DWELL_TIME = 100; // will be set

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


output	[31:0]         	    iter_din_o;
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

reg	[31:0]         	    iter_din_1_o;
reg	[31:0]         	    iter_din_2_o;
reg	[31:0]         	    iter_din_3_o;
reg	[31:0]         	    iter_din_4_o;

reg	[4:0]         	    c_mux_1_o;
reg	[4:0]         	    c_mux_2_o;
reg	[4:0]          	    c_mux_3_o;
reg	[4:0]         	    c_mux_4_o;

/***************/
/* FSM Machine */
/***************/

// FSM States:
		// send three bits of eight to the SPI (LOAD) -- does it trigger automatically(?)
				// enable SPI fifo. Width can be 16 or 256
				// FIFO size of the SPI is 8
				// AXI QSPI communicates either using AXI4 or AXI4-Lite.
				// may need to output to the AXI SPI's specific inputs - 

				// how loading works with AXI SPI:
					// collection of 16 bits
					// SPICR.SPE = 0
					// SSR is: 0xff when off, 0 when on(?)
					// Set SPI_SSR to ch_en, where ch_en = 0 (at least in Abbie's code for the DACs)  -> slave select
					// SPI_DTR: sent to the SPI block; send once every clock cycle, 8 bits
					// SPICR.SPE = 1 after 
					// SPI_SSR reset to its initial value (normally 0xff)

		// wait -- waits for DWELL_CYCLES amount of time
		// 


	// DAC:   1     2     3     4
// LOADING: 0001, 0010, 0011, 0100  --- saving into bram
// SENDING: 0101, 0110, 0111, 1000  --- sending from iterator
parameter WAIT_LOAD = 4'b0000, WAIT_SEND = 4'b1111, LOAD = 4'b0001, LOAD_MUX = 4'b0010, SEND = 4'b0101;
parameter TIMES_THRU = 256;

module hw_proj1_wrapper
   (
   // OTHER PINS
   // ...
    cs_n,
    miso,
    mosi,
    sck);
	
   // etc
   // ...
  output [0:0]cs_n;
  input miso;
  output mosi;
  output sck;
  
  
  // etc
  // ...
  wire [0:0]cs_n;
  wire miso;
  wire mosi;
  wire sck;
 
  hw_proj1 hw_proj1_i
       (.DDR_addr(DDR_addr),
        .DDR_ba(DDR_ba),
        .DDR_cas_n(DDR_cas_n),
        .DDR_ck_n(DDR_ck_n),
        .DDR_ck_p(DDR_ck_p),
        .DDR_cke(DDR_cke),
        .DDR_cs_n(DDR_cs_n),
        .DDR_dm(DDR_dm),
        .DDR_dq(DDR_dq),
        .DDR_dqs_n(DDR_dqs_n),
        .DDR_dqs_p(DDR_dqs_p),
        .DDR_odt(DDR_odt),
        .DDR_ras_n(DDR_ras_n),
        .DDR_reset_n(DDR_reset_n),
        .DDR_we_n(DDR_we_n),
        .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),
        .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
        .FIXED_IO_mio(FIXED_IO_mio),
        .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
        .FIXED_IO_ps_porb(FIXED_IO_ps_porb),
        .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
        .cs_n(cs_n),
        .miso(miso),
        .mosi(mosi),
        .sck(sck));
endmodule

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

assign iter_din_1_o = (curr_state == LOAD & sendorload_trigger) ? {8'b0, dac_1} : 32'b0;
assign iter_din_2_o = (curr_state == LOAD & sendorload_trigger) ? {8'b0, dac_2} : 32'b0;
assign iter_din_3_o = (curr_state == LOAD & sendorload_trigger) ? {8'b0, dac_3} : 32'b0;
assign iter_din_4_o = (curr_state == LOAD & sendorload_trigger) ? {8'b0, dac_4} : 32'b0;


assign curr_state = next_state;

assign c_mux_1_o = n_mux_1;
assign c_mux_2_o = n_mux_2;
assign c_mux_3_o = n_mux_3;
assign c_mux_4_o = n_mux_4;


// SINCE WE'RE NOT DOING MULTIPLE DAC'S YET; THIS WILL BE CHANGED WHEN WE HAVE AN INNER FOR LOOP (FOR TWO DACS)
assign c_mux_o = c_mux_1_o;
assign iter_din_o = iter_din_1_o;


endmodule
