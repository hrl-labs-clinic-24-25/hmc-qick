// Zoe Worrall, March 4, 2025

// `resetall
// `timescale 1ns / 1ps
// `default_nettype none

// No Mem Sweep
// s_axi_aclk	: clock for s_axi_*
// s0_axis_aclk	: clock for s0_axis_*
// aclk			: clock for s1_axis_* and m_axis_*
//
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
		SELECT_REG,

		trigger_spi // trigger for SPI
	);

	/*********/
	/* Ports */
	/*********/

	// AXI Slave I/F for configuration.
	input 				s_axi_aclk;
	input 				s_axi_aresetn;

	input [31:0] 		s_axi_awaddr;
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

	input [31:0]		s_axi_araddr;
	input [2:0]			s_axi_arprot;
	input 				s_axi_arvalid;
	output 				s_axi_arready;

	output [31:0]		s_axi_rdata;
	output [1:0]		s_axi_rresp;
	output 				s_axi_rvalid;
	input 				s_axi_rready;

	// M AXIS
	output [31:0]		m_axi_awaddr;
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

	output [31:0]		m_axi_araddr;
	output [2:0]		m_axi_arprot;
	output 				m_axi_arvalid;
	input 				m_axi_arready;

	input  [31:0]		m_axi_rdata;
	input  [1:0]		m_axi_rresp;
	input 				m_axi_rvalid;
	output 				m_axi_rready;

	// Non AXI-LITE outputs
	output 			TRIGGER_AWG_REG; // trigger for AWG
	output [4:0]  	SELECT_REG;
	output 			trigger_spi;	// trigger for SPI



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
	wire [1:0]  NUM_DACS_REG;
	wire [7:0]  NUM_CYCLES_REG;
	wire [15:0] DWELL_CYCLES_REG;

	// Address for Demux to DACs
	wire [4:0] W_REG_W;
	wire [4:0] W_REG_X;
	wire [4:0] W_REG_Y;
	wire [4:0] W_REG_Z;

	// /**************/
	// /* Parameters */
	// /**************/

	// // Set the starting values for the DACs based on the current select line
	// assign SELECT = (select == 2'b00) ? START_VAL_0_REG : (select == 2'b01) ? START_VAL_1_REG : (select == 2'b10) ? START_VAL_2_REG : START_VAL_3_REG;

	/**********************/
	/* Begin Architecture */
	/**********************/
	// AXI Slave.
	axil_slv 
		#(
		.S_COUNT 				(32),
		.M_COUNT 				(32),
		.DATA_WIDTH				(32),
		.ADDR_WIDTH    			(32),
		.STRB_WIDTH			    (4),
		.M_REGIONS				(1),
		.M_BASE_ADDR  			(0),
		.M_ADDR_WIDTH 			({32 { {1 {32'd24} } }  }),
		.M_CONNECT_READ 		({32 { {32{1'b1}   } }  }),
		.M_CONNECT_WRITE 		({32 { {32{1'b1}   } }  }),
		.M_SECURE 				({32 	  {1'b0}        })
		)
		axil_slv_i
		(
			.clk			(s_axi_aclk	 	),
			.rst		    (~s_axi_aresetn	),

			// INPUT AXI
			// Write Address Channel.
			.s_axil_awaddr			(s_axi_awaddr 	),
			.s_axil_awprot			(s_axi_awprot 	),
			.s_axil_awvalid		    (s_axi_awvalid	),
			.s_axil_awready		    (s_axi_awready	),

			// Write Data Channel.
			.s_axil_wdata			(mosi_output	),
			.s_axil_wstrb			(s_axi_wstrb	),
			.s_axil_wvalid			(s_axi_wvalid   ),
			.s_axil_wready			(trigger_spi	),

			// Write Response Channel.
			.s_axil_bresp			(s_axi_bresp	),
			.s_axil_bvalid			(s_axi_bvalid	),
			.s_axil_bready			(s_axi_bready	),

			// Read Address Channel.
			.s_axil_araddr			(s_axi_araddr 	),
			.s_axil_arprot			(s_axi_arprot 	),
			.s_axil_arvalid			(s_axi_arvalid	),
			.s_axil_arready			(s_axi_arready	),

			// Read Data Channel.
			.s_axil_rdata			(s_axi_rdata	),
			.s_axil_rresp			(s_axi_rresp	),
			.s_axil_rvalid			(s_axi_rvalid	),
			.s_axil_rready			(s_axi_rready	),

			// OUTPUT AXI
			// Write Address Channel.
			.m_axil_awaddr			(m_axi_awaddr 	),
			.m_axil_awprot			(m_axi_awprot 	),
			.m_axil_awvalid			(m_axi_awvalid	),
			.m_axil_awready			(m_axi_awready	),

			// Write Data Channel.
			.m_axil_wdata			(m_axi_wdata	),
			.m_axil_wstrb			(m_axi_wstrb	),
			.m_axil_wvalid			(m_axi_wvalid   ),
			.m_axil_wready			(m_axi_wready	),

			// Write Response Channel.
			.m_axil_bresp			(m_axi_bresp	),
			.m_axil_bvalid			(m_axi_bvalid	),
			.m_axil_bready			(m_axi_bready	),

			// Read Address Channel.
			.m_axil_araddr			(m_axi_araddr 	),
			.m_axil_arprot			(m_axi_arprot 	),
			.m_axil_arvalid		    (m_axi_arvalid	),
			.m_axil_arready		    (m_axi_arready	),

			// Read Data Channel.
			.m_axil_rdata			(m_axi_rdata	),
			.m_axil_rresp			(m_axi_rresp	),
			.m_axil_rvalid			(m_axi_rvalid	),
			.m_axil_rready			(m_axi_rready	)
		);

	pvp_fsm_gen
		fsm_i 
			(
				.rstn				(s_axi_aresetn),
				.clk				(s_axi_aclk),
				.TRIGGER_PVP_REG   	(TRIGGER_PVP_REG),
				.mosi_o				(mosi_output),
				.which_dac_o		(SELECT_REG),
				.TRIGGER_AWG_REG	(TRIGGER_AWG_REG),
				.trigger_spi_o 		(trigger_spi),
				.START_VAL_0_REG 	(START_VAL_0_REG),
				.START_VAL_1_REG 	(START_VAL_1_REG),
				.START_VAL_2_REG 	(START_VAL_2_REG),
				.START_VAL_3_REG 	(START_VAL_3_REG),


				.DWELL_CYCLES_REG	(DWELL_CYCLES_REG),
				.STEP_SIZE_REG      (STEP_SIZE_REG),
				.NUM_CYCLES_REG     (NUM_CYCLES_REG),
				.NUM_DACS_REG 		(NUM_DACS_REG),
				.W_REG_W			(W_REG_W),
				.W_REG_X			(W_REG_X),
				.W_REG_Y			(W_REG_Y),
				.W_REG_Z			(W_REG_Z)
			);


endmodule

