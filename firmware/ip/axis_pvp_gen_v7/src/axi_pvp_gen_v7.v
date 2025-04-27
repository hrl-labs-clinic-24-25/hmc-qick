/**
* Module: axil_pvp_gen_v3
* Description: This module is the top level module for the PVP generator. It instantiates the FSM and the AXI Slave modules for the PVP generator.
* Author: Zoe Worrall, zoe.worrall@me.com
* Date: March 13, 2025

* Update A: changing register names to match our new convention
* Ellie, esundheim@hmc.edu, 3/13/25

*/

// s_axi_aclk	: clock for s_axi_* and m_axi_*
module axi_pvp_gen_v7
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

		// Non AXI-LITE input
		trigger_pmod, // trigger from AWG


		// Non AXI-LITE outputs
		select_mux, // demuxing to the PCBs
		done,		// the "done" flag (raised high when PvP is finished)

		LDACN,		// ran after every loading cycle of the SPI
		CLRN,		// Clear all the DACs (not yet implemented)
		RESETN,		// Resetn all the DACs (not yet implemented)

		COPI, // SPI COPI signal (controller in peripheral out)
		SCK, // SPI Clock
		CS, // SPI Chip Select
	);

	/*********/
	/* Ports */
	/*********/
	parameter DATA_WIDTH	= 32;
	parameter ADDR_WIDTH	= 6;

	// AXI BUS 1 -- Slave I/F for configuration.
	input 				s_axi_aclk;
	input 				s_axi_aresetn;

	input [6:0] 		s_axi_awaddr;
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

	input [6:0]		    s_axi_araddr;
	input [2:0]			s_axi_arprot;
	input 				s_axi_arvalid;
	output 				s_axi_arready;

	output [31:0]		s_axi_rdata;
	output [1:0]		s_axi_rresp;
	output 				s_axi_rvalid;
	input 				s_axi_rready;

	// Non AXI-LITE input
	input 			trigger_pmod; // trigger for AWG ** test that output registers don't cause net contention in Vivado (March 7)

	// Non AXI-LITE outputs
	output [4:0]  	select_mux;
	output 			done;
	
	output 			LDACN; //  ldac bar
	output			CLRN;  // clear bar
	output			RESETN;  // reset bar
	output 			COPI;
	output 			SCK; // SPI Clock
	output 			CS; // SPI Chip Select



	/********************/
	/* Internal signals */
	/********************/

	// connected from FSM to axil_slv
	wire [23:0] mosi_output;

	// Non AXI inputs

	// starting value for the DACs
	wire [19:0] START_VAL_0_REG;
	wire [19:0] START_VAL_1_REG;
	wire [19:0] START_VAL_2_REG;
	wire [19:0] START_VAL_3_REG;

	// step size of each DAC
	wire [19:0] STEP_SIZE_0_REG;
	wire [19:0] STEP_SIZE_1_REG;
	wire [19:0] STEP_SIZE_2_REG;
	wire [19:0] STEP_SIZE_3_REG;

	// Demux code for each DAC
	wire [4:0] DEMUX_0_REG;
	wire [4:0] DEMUX_1_REG;
	wire [4:0] DEMUX_2_REG;
	wire [4:0] DEMUX_3_REG;

	// Group that the DAC belongs to
	wire [1:0] DAC_0_GROUP_REG;
	wire [1:0] DAC_1_GROUP_REG;
	wire [1:0] DAC_2_GROUP_REG;
	wire [1:0] DAC_3_GROUP_REG;

	wire       TRIGGER_USER_REG; // trigger from the user

	// configurations for DACs
	wire [3:0]  CTRL_REG; 			// [ ldacn, rstn, clrn, trigger_pvp ]
	wire [1:0]  MODE_REG; 			// 0; default pvp. 1: pvp up/down. 2. pvp spiral. 3. user controlled only (allows user to set LDAC)
	wire [28:0] CONFIG_REG; 		// [ demux value + 24 bits to a DAC ]

	wire [31:0] DWELL_CYCLES_REG; 	// time to wait till next SPI signal loaded
	wire [15:0] CYCLES_TILL_READOUT_REG; // time to wait until allowed to start "reading" (when implemented with AWGs)
	wire [9:0]  PVP_WIDTH_REG; 			 // square plot width
	wire [2:0]  NUM_DIMS_REG; 		     // how many DACs are in use (0 - 4)

	wire 	   done;			 // trigger for SPI
	wire 	   trigger_spi_o;


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
		
		.START_VAL_0_REG  (START_VAL_0_REG),
		.START_VAL_1_REG  (START_VAL_1_REG),
		.START_VAL_2_REG  (START_VAL_2_REG),
		.START_VAL_3_REG  (START_VAL_3_REG),

		.STEP_SIZE_0_REG  (STEP_SIZE_0_REG),
		.STEP_SIZE_1_REG  (STEP_SIZE_1_REG),
		.STEP_SIZE_2_REG  (STEP_SIZE_2_REG),
		.STEP_SIZE_3_REG  (STEP_SIZE_3_REG),

		.DEMUX_0_REG 	  (DEMUX_0_REG),
		.DEMUX_1_REG 	  (DEMUX_1_REG),
		.DEMUX_2_REG 	  (DEMUX_2_REG),
		.DEMUX_3_REG 	  (DEMUX_3_REG),

		.DAC_0_GROUP_REG  (DAC_0_GROUP_REG),
		.DAC_1_GROUP_REG  (DAC_1_GROUP_REG),
		.DAC_2_GROUP_REG  (DAC_2_GROUP_REG),
		.DAC_3_GROUP_REG  (DAC_3_GROUP_REG),

		.CTRL_REG  		  (CTRL_REG),
		.MODE_REG		  (MODE_REG),
		.CONFIG_REG       (CONFIG_REG),

		.DWELL_CYCLES_REG 		(DWELL_CYCLES_REG),
		.CYCLES_TILL_READOUT_REG (CYCLES_TILL_READOUT_REG),
		.PVP_WIDTH_REG 			(PVP_WIDTH_REG),
		.NUM_DIMS_REG 			(NUM_DIMS_REG),

		.TRIGGER_USER_REG       (TRIGGER_USER_REG)
		// need to add in LDACN
	);

	pvp_fsm_gen
		fsm_i 
			(
				.rstn				(s_axi_aresetn),
				.clk				(s_axi_aclk),

				.CONFIG_REG			(CONFIG_REG),
			
				.START_VAL_0_REG 	(START_VAL_0_REG),
				.START_VAL_1_REG 	(START_VAL_1_REG),
				.START_VAL_2_REG 	(START_VAL_2_REG),
				.START_VAL_3_REG 	(START_VAL_3_REG),

				.DWELL_CYCLES_REG		 (DWELL_CYCLES_REG),
				.CYCLES_TILL_READOUT_REG (CYCLES_TILL_READOUT_REG),

				.STEP_SIZE_0_REG      (STEP_SIZE_0_REG),
				.STEP_SIZE_1_REG      (STEP_SIZE_1_REG),
				.STEP_SIZE_2_REG      (STEP_SIZE_2_REG),
				.STEP_SIZE_3_REG      (STEP_SIZE_3_REG),

				.DEMUX_0_REG		(DEMUX_0_REG),
				.DEMUX_1_REG		(DEMUX_1_REG),
				.DEMUX_2_REG		(DEMUX_2_REG),
				.DEMUX_3_REG		(DEMUX_3_REG),

				.DAC_0_GROUP_REG		(DAC_0_GROUP_REG),
				.DAC_1_GROUP_REG		(DAC_1_GROUP_REG),
				.DAC_2_GROUP_REG		(DAC_2_GROUP_REG),
				.DAC_3_GROUP_REG        (DAC_3_GROUP_REG),

				.PVP_WIDTH_REG      (PVP_WIDTH_REG),
				.NUM_DIMS_REG 		(NUM_DIMS_REG),

				.CTRL_REG			(CTRL_REG),
				.MODE_REG 			(MODE_REG),

				.TRIGGER_USER_REG   (TRIGGER_USER_REG), // trigger from the user
				.trigger_pmod		(trigger_pmod), // trigger from PMOD

				.mosi_o				(mosi_output),
				.select_mux			(select_mux), 
				.readout_o			(TRIGGER_AWG_REG),
				.trigger_spi_o 		(trigger_spi_o),
				.ldacn				(LDACN),
				.clrn				(CLRN),
				.resetn				(RESETN),
				.done 				(done)

				
			);

	spi spi_i
     (
		.clk (s_axi_aclk),
		.rstn (s_axi_aresetn ),
		.DATA_IN (mosi_output),
		.TRIGGER (trigger_spi_o),
		.sdo (COPI),
		.cs (CS),
		.sck (SCK)
	);


endmodule

