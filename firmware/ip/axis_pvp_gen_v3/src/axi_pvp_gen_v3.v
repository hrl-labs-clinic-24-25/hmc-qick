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

		// M AXIS
		m_axi_awaddr,
		m_axi_awprot,
		m_axi_awvalid,
		m_axi_awready,

		m_axi_wdata,
		m_axi_wstrb,
		m_axi_wvalid,
		m_axi_wready,

		m_axi_bresp,
		m_axi_bvalid,
		m_axi_bready,

		m_axi_araddr,
		m_axi_arprot,
		m_axi_arvalid,
		m_axi_arready,

		m_axi_rdata,
		m_axi_rresp,
		m_axi_rvalid,
		m_axi_rready,

		// Non AXI-LITE 
		TRIGGER_AWG_REG, // trigger for AWG
		select_mux,
		test_fake,
		done
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


	// M AXIS
	output [5:0]		m_axi_awaddr;
	output [2:0]		m_axi_awprot;
	output 				m_axi_awvalid;
	input 				m_axi_awready;

	output [31:0]		m_axi_wdata;
	output [3:0]		m_axi_wstrb;
	output 				m_axi_wvalid;
	input				m_axi_wready;

	input  [1:0]		m_axi_bresp;
	input 				m_axi_bvalid;
	output 				m_axi_bready;



	output [5:0]		m_axi_araddr;
	output [2:0]		m_axi_arprot;
	output 				m_axi_arvalid;
	input 				m_axi_arready;

	input  [31:0]		m_axi_rdata;
	input  [1:0]		m_axi_rresp;
	input 				m_axi_rvalid;
	output 				m_axi_rready;

	// Non AXI-LITE outputs
	output 			TRIGGER_AWG_REG; // trigger for AWG ** test that output registers don't cause net contention in Vivado (March 7)
	output [4:0]  	select_mux;
	output 			done;
	output testfake;
	//we do NOT put mosi here because it comes out via m_axi



	/********************/
	/* Internal signals */
	/********************/
	// Registers.

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
	wire [2:0]  NUM_DACS_REG;
	wire [9:0]  PVP_WIDTH_REG;

	wire [15:0] DWELL_CYCLES_REG;
	wire [15:0] CYCLES_TILL_READOUT_REG;

	// Address for Demux to DACs
	wire [5:0] DEMUX_0_REG;
	wire [5:0] DEMUX_1_REG;
	wire [5:0] DEMUX_2_REG;
	wire [5:0] DEMUX_3_REG;

	wire 	   done;			 // trigger for SPI

	wire trigger_spi_o;
	wire [31:0] outsig;
	


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
				.mosi_o				(mosi_output),
				.select_mux			(select_mux), 
				.TRIGGER_AWG_REG	(TRIGGER_AWG_REG),
				.trigger_spi_o 		(trigger_spi_o),
				.done 				(done),

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
				.DEMUX_3_REG		(DEMUX_3_REG)
				
			);



	axi_lite_master
     #(
       .AXI_ADDR_WIDTH(6),
       .AXI_DATA_WIDTH(32)
       )
   axi_lite_master_i
     (
      .init_transaction 		(trigger_spi_o), // input
	  .output_data				(mosi_output), // output

      .M_AXI_ACLK		(s_axi_aclk), // input
      .M_AXI_ARESETN	(s_axi_aresetn), // input

      // aw
      .M_AXI_AWADDR		(m_axi_awaddr),
      .M_AXI_AWPROT		(m_axi_awprot),
      .M_AXI_AWVALID	(m_axi_awvalid),
      .M_AXI_AWREADY	(m_axi_awready), // input

      // w
      .M_AXI_WDATA		(m_axi_wdata),
      .M_AXI_WSTRB		(m_axi_wstrb),
      .M_AXI_WVALID		(m_axi_wvalid),
      .M_AXI_WREADY		(s_axi_wready), // input

      // b resp
      .M_AXI_BRESP		(m_axi_bresp), // input
      .M_AXI_BVALID		(m_axi_bvalid), // input
      .M_AXI_BREADY		(m_axi_bready),

      // ar
      .M_AXI_ARADDR		(m_axi_araddr),
      .M_AXI_ARPROT		(m_axi_arprot),
      .M_AXI_ARVALID	(m_axi_arvalid),
      .M_AXI_ARREADY	(m_axi_arready), // input

      // r
      .M_AXI_RDATA		(m_axi_rdata), // input
      .M_AXI_RRESP		(m_axi_rresp), // input
      .M_AXI_RVALID		(m_axi_rvalid), // input
      .M_AXI_RREADY		(m_axi_rready)

      );


endmodule

