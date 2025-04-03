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
    logic [1:0] MODE_REG;

    logic [19:0] X_AXIS_START_VAL_REG;
    logic [19:0] Y_AXIS_START_VAL_REG;
    logic [19:0] Z_AXIS_START_VAL_REG;
    logic [19:0] W_AXIS_START_VAL_REG;

    logic [15:0] DWELL_CYCLES_REG;
    logic [15:0] CYCLES_TILL_READOUT_REG;

    logic [19:0] STEP_SIZE_REG;
    logic [9:0]  PVP_WIDTH_REG;
    logic [2:0]  NUM_DACS_REG;

    logic [5:0] X_AXIS_DEMUX_REG;
    logic [5:0] Y_AXIS_DEMUX_REG;
    logic [5:0] Z_AXIS_DEMUX_REG;
    logic [5:0] W_AXIS_DEMUX_REG;

    logic [4:0] select;
    logic [31:0] mosi_o;
    logic trigger_spi_o;
    logic readout_o;
    logic done;


    localparam freq = 50.0e6;
    localparam clk_period = (1/freq)/1e-9;

    always begin
        clk = #(clk_period/2) ~clk;
    end

    initial
        begin
            MODE_REG = 2; // Cycle between Spiral, Top-Bottom, and Default
            rstn = 0;
            #100
            rstn = 1;
            #100;
            TRIGGER_PVP_REG = 1;
            for (int i = 0; i < 500000; i++) begin
                #20;
                if (done) TRIGGER_PVP_REG = 0;
            end

            // confirming that you can stop a trial while its running
            TRIGGER_PVP_REG = 1;
            #10000;
            TRIGGER_PVP_REG = 0;
            #10000;
        end

    localparam AXI_ADDR_WIDTH = 32;
    localparam AXI_DATA_WIDTH = 32;


pvp_fsm_gen
    fsm_i(
		// Reset and clock.
		.rstn,
		.clk,

        .TRIGGER_PVP_REG,
        .X_AXIS_START_VAL_REG,
        .Y_AXIS_START_VAL_REG,
        .Z_AXIS_START_VAL_REG,
        .W_AXIS_START_VAL_REG,
        .DWELL_CYCLES_REG,
        .CYCLES_TILL_READOUT_REG,
        .STEP_SIZE_REG,
        .PVP_WIDTH_REG,
        .NUM_DACS_REG,
        .X_AXIS_DEMUX_REG,
        .Y_AXIS_DEMUX_REG,
        .Z_AXIS_DEMUX_REG,
        .W_AXIS_DEMUX_REG,

        .MODE_REG,

    	// parameter inputs.
		.mosi_o,
        .select,
        .readout_o,
        .trigger_spi_o,
        .done
	);

endmodule