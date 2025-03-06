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
    logic TRIGGER_PVP_REG;

    logic [19:0] START_VAL_0_REG;
    logic [19:0] START_VAL_1_REG;
    logic [19:0] START_VAL_2_REG;
    logic [19:0] START_VAL_3_REG;

    logic [15:0] DWELL_CYCLES_REG;
    logic [19:0] STEP_SIZE_REG;
    logic [7:0] NUM_CYCLES_REG;
    logic [1:0] NUM_DACS_REG;
    logic [4:0] W_REG_W;
    logic [4:0] W_REG_X;
    logic [4:0] W_REG_Y;
    logic [4:0] W_REG_Z;

    logic [4:0] SELECT;
    logic [31:0] mosi_o;
    logic trigger_spi_o;
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
            TRIGGER_PVP_REG = 1;
            #20;
            TRIGGER_PVP_REG = 0;
            #1000000;
        end

    localparam AXI_ADDR_WIDTH = 32;
    localparam AXI_DATA_WIDTH = 32;


pvp_fsm_gen
    fsm_i(
		// Reset and clock.
		.rstn,
		.clk,

        .TRIGGER_PVP_REG,
        .START_VAL_0_REG,
        .START_VAL_1_REG,
        .START_VAL_2_REG,
        .START_VAL_3_REG,
        .DWELL_CYCLES_REG,
        .STEP_SIZE_REG,
        .NUM_CYCLES_REG,
        .NUM_DACS_REG,
        .W_REG_W,
        .W_REG_X,
        .W_REG_Y,
        .W_REG_Z,

    	// parameter inputs.
		.mosi_o,
        .SELECT,
        .readout_o,
        .trigger_spi_o
	);

endmodule