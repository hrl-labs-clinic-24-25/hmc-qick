/**
* Module: axil_pvp_gen_v3
* Description: This module is the top level module for the PVP generator. It instantiates the FSM and the AXI Slave modules for the PVP generator.
* Author: Zoe Worrall, zoe.worrall@me.com
* Date: March 13, 2025

* Update A: changing register names to match our new convention
* Ellie, esundheim@hmc.edu, 3/13/25

*/

// s_axi_aclk	: clock for s_axi_* and m_axi_*
module axi_pvp_gen_v3 
	( 
		// AXI Slave I/F for configuration.
		s_axi_aclk,
		s_axi_aresetn,

		s_axi_awaddr,
		s_axi_awprot,
		s_axi_awvalid,
		s_axi_awready,

		s_axi_wdata,
		s_axi_wstrb,
		s_axi_wvalid,
		s_axi_wready,

		s_axi_bresp,
		s_axi_bvalid,
		s_axi_bready,

		s_axi_araddr,
		s_axi_arprot,
		s_axi_arvalid,
		s_axi_arready,

		s_axi_rdata,
		s_axi_rresp,
		s_axi_rvalid,
		s_axi_rready,

		// Non AXI-LITE 
		TRIGGER_AWG_REG, // trigger for AWG
		select_mux,
		done,
		COPI,
		SCK, // SPI Clock
		CS // SPI Chip Select
	);

	/*********/
	/* Ports */
	/*********/
	parameter DATA_WIDTH	= 32;
	parameter ADDR_WIDTH	= 6;

	// AXI Slave I/F for configuration.
	input 				s_axi_aclk;
	input 				s_axi_aresetn;

	input [5:0] 		s_axi_awaddr;
	input [2:0]			s_axi_awprot;
	input 				s_axi_awvalid;
	output 				s_axi_awready;

	input [31:0]		s_axi_wdata;
	input [3:0]			s_axi_wstrb;
	input				s_axi_wvalid;
	output 				s_axi_wready;

	output [1:0]		s_axi_bresp;
	output 				s_axi_bvalid;
	input 			    s_axi_bready;



	input [5:0]		    s_axi_araddr;
	input [2:0]			s_axi_arprot;
	input 				s_axi_arvalid;
	output 				s_axi_arready;

	output [31:0]		s_axi_rdata;
	output [1:0]		s_axi_rresp;
	output 				s_axi_rvalid;
	input 				s_axi_rready;

	// Non AXI-LITE outputs
	output 			TRIGGER_AWG_REG; // trigger for AWG ** test that output registers don't cause net contention in Vivado (March 7)
	output [4:0]  	select_mux;
	output 			done;

	output 			COPI;
	output 			SCK; // SPI Clock
	output 			CS; // SPI Chip Select
	//we do NOT put mosi here because it comes out via m_axi



	/********************/
	/* Internal signals */
	/********************/

	// connected from FSM to axil_slv
	wire [31:0] mosi_output;

	// Non AXI inputs
	wire TRIGGER_PVP_REG;

	// starting value for the DACs
	wire [19:0] START_VAL_0_REG;
	wire [19:0] START_VAL_1_REG;
	wire [19:0] START_VAL_2_REG;
	wire [19:0] START_VAL_3_REG;

	// Adjust these to change PvP Plot
	wire [19:0] STEP_SIZE_REG;
	wire [2:0]  NUM_DIMS_REG;
	wire [9:0]  PVP_WIDTH_REG;
	wire [15:0] DWELL_CYCLES_REG;         // at minimum, must be 50 * 4 cycles (200 cycles)
	wire [15:0] CYCLES_TILL_READOUT_REG;

	// Address for Demux to DACs
	wire [5:0] DEMUX_0_REG;
	wire [5:0] DEMUX_1_REG;
	wire [5:0] DEMUX_2_REG;
	wire [5:0] DEMUX_3_REG;
	wire 	   done;			 // trigger for SPI
	wire trigger_spi_o;


	/**************/
	/* Parameters */
	/**************/
	

	/**********************/
	/* Begin Architecture */
	/**********************/
	// AXI Slave.
	axi_slv axi_slv_i
	(
		.aclk			(s_axi_aclk	 	),
		.aresetn		(s_axi_aresetn	),

		// Write Address Channel.
		.awaddr			(s_axi_awaddr 	),
		.awprot			(s_axi_awprot 	),
		.awvalid		(s_axi_awvalid	),
		.awready		(s_axi_awready	),

		// Write Data Channel.
		.wdata			(s_axi_wdata	),
		.wstrb			(s_axi_wstrb	),
		.wvalid			(s_axi_wvalid   ),
		.wready			(s_axi_wready	),

		// Write Response Channel.
		.bresp			(s_axi_bresp	),
		.bvalid			(s_axi_bvalid	),
		.bready			(s_axi_bready	),

		// Read Address Channel.
		.araddr			(s_axi_araddr 	),
		.arprot			(s_axi_arprot 	),
		.arvalid		(s_axi_arvalid	),
		.arready		(s_axi_arready	),

		// Read Data Channel.
		.rdata			(s_axi_rdata	),
		.rresp			(s_axi_rresp	),
		.rvalid			(s_axi_rvalid	),
		.rready			(s_axi_rready	),

		// Registers.
		.START_VAL_0_REG	(START_VAL_0_REG	),
		.START_VAL_1_REG	(START_VAL_1_REG	),
		.START_VAL_2_REG	(START_VAL_2_REG	),
		.START_VAL_3_REG	(START_VAL_3_REG	),

		.TRIGGER_PVP_REG	(TRIGGER_PVP_REG	),

		.DWELL_CYCLES_REG	(DWELL_CYCLES_REG	), 
		.CYCLES_TILL_READOUT_REG (CYCLES_TILL_READOUT_REG),
		.STEP_SIZE_REG		(STEP_SIZE_REG	),
		.PVP_WIDTH_REG		(PVP_WIDTH_REG), 
		.NUM_DIMS_REG 		(NUM_DIMS_REG),

		.DEMUX_0_REG 		(DEMUX_0_REG),
		.DEMUX_1_REG 		(DEMUX_1_REG),
		.DEMUX_2_REG 		(DEMUX_2_REG),
		.DEMUX_3_REG 		(DEMUX_3_REG)
	);


	pvp_fsm_gen
		fsm_i 
			(
				.rstn				(s_axi_aresetn),
				.clk				(s_axi_aclk),

				.TRIGGER_PVP_REG   	(TRIGGER_PVP_REG),
			
				.START_VAL_0_REG 	(START_VAL_0_REG),
				.START_VAL_1_REG 	(START_VAL_1_REG),
				.START_VAL_2_REG 	(START_VAL_2_REG),
				.START_VAL_3_REG 	(START_VAL_3_REG),

				.DWELL_CYCLES_REG		 (DWELL_CYCLES_REG),
				.CYCLES_TILL_READOUT_REG (CYCLES_TILL_READOUT_REG),

				.STEP_SIZE_REG      (STEP_SIZE_REG),
				.PVP_WIDTH_REG      (PVP_WIDTH_REG),
				.NUM_DIMS_REG 		(NUM_DIMS_REG),

				.DEMUX_0_REG		(DEMUX_0_REG),
				.DEMUX_1_REG		(DEMUX_1_REG),
				.DEMUX_2_REG		(DEMUX_2_REG),
				.DEMUX_3_REG		(DEMUX_3_REG),

				.mosi_o				(mosi_output),
				.select_mux			(select_mux), 
				.readout_o			(TRIGGER_AWG_REG),
				.trigger_spi_o 		(trigger_spi_o),
				.done 				(done)

				
			);

	spi spi_i
     (
		.clk (s_axi_aclk),
		.rstn (rstn),
		.DATA_IN (mosi_output),
		.TRIGGER (trigger_spi_o),
		.sdo (COPI),
		.sdi (1'b0),
		.cs (CS),
		.sck (SCK)
	);


endmodule

