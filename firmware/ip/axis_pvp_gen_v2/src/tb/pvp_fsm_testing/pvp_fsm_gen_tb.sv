// Modelsim-ASE requires a timescale directive
// `timescale 1 ps / 1 ps

/**

Based on the test bench in the corresponding video https://www.youtube.com/watch?v=qqI9QIkGFIQ 

Confirming that data interacts with AXI blocks as anticipated
Zoe Worrall, March 3 2025

*/
module pvp_fsm_gen_tb ();

    logic clk = 0;
    logic rstn;
    logic trigger;
    logic [31:0] mosi_o;
    logic [1:0]  which_dac_o;
    logic readout_o;

    localparam freq = 50.0e6;
    localparam clk_period = (1/freq)/1e-9;

    always begin
        clk = #(clk_period/2) ~clk;
    end

    initial
        begin
            rstn = 0;
            #100
            rstn = 1;
            #100;
            trigger = 1;
            #20;
            trigger = 0;
            #1000000;
        end

    localparam AXI_ADDR_WIDTH = 32;
    localparam AXI_DATA_WIDTH = 32;


pvp_fsm_gen  #(.DWELL_CYCLES(10), .START_VAL_0(20'd3), .STEP_SIZE(20'd1), .NUM_CYCLES(4))
    fsm_i(
		// Reset and clock.
		.rstn,
		.clk,

        .trigger,

    	// parameter inputs.
		.mosi_o,
        .which_dac_o,
        .readout_o
	);

endmodule