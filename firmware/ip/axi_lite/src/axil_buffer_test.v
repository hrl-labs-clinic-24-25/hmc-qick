/**
* Module: axil_pvp_gen_v3
* Description: This module is the top level module for the PVP generator. It instantiates the FSM and the AXI Slave modules for the PVP generator.
* Author: Zoe Worrall, zoe.worrall@me.com
* Date: March 13, 2025
*/

// No Mem Sweep
// s_axi_aclk	: clock for s_axi_*
// s0_axis_aclk	: clock for s0_axis_*
// aclk			: clock for s1_axis_* and m_axis_*
//
module axil_buffer_test 
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

	wire [31:0] outsig;

	// /**************/
	// /* Parameters */
	// /**************/

	// // Set the starting values for the DACs based on the current select line
	// assign select = (select == 2'b00) ? X_AXIS_START_VAL_REG : (select == 2'b01) ? Y_AXIS_START_VAL_REG : (select == 2'b10) ? Z_AXIS_START_VAL_REG : W_AXIS_START_VAL_REG;

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
		.QOUT_REG       (outsig)
	);

    axi_lite_master_v2 axi_lite_master_i
     (
	  .M_AXI_ACLK		(s_axi_aclk), // input
      .M_AXI_ARESETN	(s_axi_aresetn), // input

      // aw
      .M_AXI_AWADDR		(s_axi_awaddr),
      .M_AXI_AWPROT		(m_axi_awprot),
      .M_AXI_AWVALID	(m_axi_awvalid),
      .M_AXI_AWREADY	(s_axi_awready), // input

      // w
      .M_AXI_WDATA		(m_axi_wdata),
      .M_AXI_WSTRB		(m_axi_wstrb),
      .M_AXI_WVALID		(m_axi_wvalid),
      .M_AXI_WREADY		(s_axi_wready), // input

      // b resp
      .M_AXI_BRESP		(s_axi_bresp), // input
      .M_AXI_BVALID		(s_axi_bvalid), // input
      .M_AXI_BREADY		(m_axi_bready),

      // ar
      .M_AXI_ARADDR		(m_axi_araddr),
      .M_AXI_ARPROT		(m_axi_arprot),
      .M_AXI_ARVALID	(m_axi_arvalid),
      .M_AXI_ARREADY	(s_axi_arready), // input

      // r
      .M_AXI_RDATA		(s_axi_rdata), // input
      .M_AXI_RRESP		(s_axi_rresp), // input
      .M_AXI_RVALID		(s_axi_rvalid), // input
      .M_AXI_RREADY		(m_axi_rready)

      );



	// // AXI Slave.
	// axil_slv 
	// 	#(
	// 	.S_COUNT 				(32),
	// 	.M_COUNT 				(32),
	// 	.DATA_WIDTH				(32),
	// 	.ADDR_WIDTH    			(32),
	// 	.STRB_WIDTH			    (4),
	// 	.M_REGIONS				(1),
	// 	.M_BASE_ADDR  			(0),
	// 	.M_ADDR_WIDTH 			({32 { {1 {32'd24} } }  }),
	// 	.M_CONNECT_READ 		({32 { {32{1'b1}   } }  }),
	// 	.M_CONNECT_WRITE 		({32 { {32{1'b1}   } }  }),
	// 	.M_SECURE 				({32 	  {1'b0}        })
	// 	)
	// 	axil_slv_i
	// 	(
	// 		.clk			(s_axi_aclk	 	),
	// 		.rst		    (~s_axi_aresetn	),

	// 		// INPUT AXI
	// 		// Write Address Channel.
	// 		.s_axil_awaddr			(s_axi_awaddr 	),
	// 		.s_axil_awprot			(s_axi_awprot 	),
	// 		.s_axil_awvalid		    (s_axi_awvalid	),
	// 		.s_axil_awready		    (s_axi_awready	),

	// 		// Write Data Channel.
	// 		.s_axil_wdata			(mosi_output	),
	// 		.s_axil_wstrb			(s_axi_wstrb	),
	// 		.s_axil_wvalid			(s_axi_wvalid   ),
	// 		.s_axil_wready			(s_axi_wready  ),

	// 		// Write Response Channel.
	// 		.s_axil_bresp			(s_axi_bresp	),
	// 		.s_axil_bvalid			(s_axi_bvalid	),
	// 		.s_axil_bready			(s_axi_bready	),

	// 		// Read Address Channel.
	// 		.s_axil_araddr			(s_axi_araddr 	),
	// 		.s_axil_arprot			(s_axi_arprot 	),
	// 		.s_axil_arvalid			(s_axi_arvalid	),
	// 		.s_axil_arready			(s_axi_arready	),

	// 		// Read Data Channel.
	// 		.s_axil_rdata			(s_axi_rdata	),
	// 		.s_axil_rresp			(s_axi_rresp	),
	// 		.s_axil_rvalid			(s_axi_rvalid	),
	// 		.s_axil_rready			(s_axi_rready	),

	// 		// OUTPUT AXI
	// 		// Write Address Channel.
	// 		.m_axil_awaddr			(m_axi_awaddr 	),
	// 		.m_axil_awprot			(m_axi_awprot 	),
	// 		.m_axil_awvalid			(m_axi_awvalid	),
	// 		.m_axil_awready			(m_axi_awready	),

	// 		// Write Data Channel.
	// 		.m_axil_wdata			(m_axi_wdata	),
	// 		.m_axil_wstrb			(m_axi_wstrb	),
	// 		.m_axil_wvalid			(m_axi_wvalid   ),
	// 		.m_axil_wready			(trigger_spi_o	),

	// 		// Write Response Channel.
	// 		.m_axil_bresp			(m_axi_bresp	),
	// 		.m_axil_bvalid			(m_axi_bvalid	),
	// 		.m_axil_bready			(m_axi_bready	),

	// 		// Read Address Channel.
	// 		.m_axil_araddr			(m_axi_araddr 	),
	// 		.m_axil_arprot			(m_axi_arprot 	),
	// 		.m_axil_arvalid		    (m_axi_arvalid	),
	// 		.m_axil_arready		    (m_axi_arready	),

	// 		// Read Data Channel.
	// 		.m_axil_rdata			(m_axi_rdata	),
	// 		.m_axil_rresp			(m_axi_rresp	),
	// 		.m_axil_rvalid			(m_axi_rvalid	),
	// 		.m_axil_rready			(m_axi_rready	)
	// 	);

endmodule

