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

    logic [19:0] START_VAL_0_REG;
    logic [19:0] START_VAL_1_REG;
    logic [19:0] START_VAL_2_REG;
    logic [19:0] START_VAL_3_REG;

    logic [31:0] DWELL_CYCLES_REG;
    logic [15:0] CYCLES_TILL_READOUT_REG;
    logic [19:0] STEP_SIZE_REG;
    logic [9:0]  PVP_WIDTH_REG;
    logic [2:0]  NUM_DIMS_REG;

    logic [4:0]  DEMUX_0_REG;
    logic [4:0]  DEMUX_1_REG;
    logic [4:0]  DEMUX_2_REG;
    logic [4:0]  DEMUX_3_REG;

                            //   11       10        9      		8		  7:6	   5:4		3:2		1:0
	                       // [ LDACN    CLRN     RSTN      TRIG_PVP     DAC0     DAC1     DAC2     DAC3 ]
    logic [11:0] CTRL_REG;
    logic [1:0]  MODE_REG;
    logic [28:0] CONFIG_REG;

    logic [4:0] select_mux;
    logic [23:0] mosi_o;
    logic trigger_spi_o;
    logic readout_o;
    logic ldacn;
    logic clrn;
    logic resetn;
    logic done;

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

            START_VAL_0_REG = 20'b0000_0000_0000_1111_0000;
            START_VAL_1_REG = 20'b0000_0000_1111_0000_0000;
            START_VAL_2_REG = 20'b0000_1111_0000_0000_0000;
            START_VAL_3_REG = 20'b1111_0000_0000_0000_0000;
            
            DWELL_CYCLES_REG = 32'd50_00;
            CYCLES_TILL_READOUT_REG = 16'd10;
            STEP_SIZE_REG = 20'h0001;

            PVP_WIDTH_REG = 3;
            NUM_DIMS_REG = 2;

            DEMUX_0_REG = 5'b00001;
            DEMUX_1_REG = 5'b00010;
            DEMUX_2_REG = 5'b00100;
            DEMUX_3_REG = 5'b01000;

            MODE_REG = 2'b00;
            CONFIG_REG = 29'b000_0_00_00_00_00_00_00_00_00;
            CTRL_REG = 8'b0000_00_00_00_01;

            #100;

            CTRL_REG = 8'b0000_00_00_01_01;

            #100;

            CTRL_REG[8] = 1;

            for (int i = 0; i < 500000; i++) begin
                #20;
                if (done)  CTRL_REG[8] = 0;
            end

            // confirming that you can stop a trial while its running
            CTRL_REG[8] = 0;
            #10000;
            CTRL_REG[8] = 1;
            #10000;
        end

    localparam AXI_ADDR_WIDTH = 32;
    localparam AXI_DATA_WIDTH = 32;


pvp_fsm_gen
    fsm_i(
		// Reset and clock.
		.rstn,
		.clk,
        
		.START_VAL_0_REG,
		.START_VAL_1_REG,
		.START_VAL_2_REG,
		.START_VAL_3_REG,

        .DWELL_CYCLES_REG,
        .CYCLES_TILL_READOUT_REG,

        .STEP_SIZE_REG,
        .PVP_WIDTH_REG,
        .NUM_DIMS_REG,
        
		.DEMUX_0_REG,
		.DEMUX_1_REG,
		.DEMUX_2_REG,
		.DEMUX_3_REG,

        .CTRL_REG,
        .MODE_REG,
        .CONFIG_REG,

    	// parameter inputs.
		.mosi_o,
        .select_mux,
        .readout_o,
        .trigger_spi_o,
        .ldacn,
        .clrn,
        .resetn,
        .done
	);

endmodule