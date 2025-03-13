// Zoe Worrall, March 4, 2025
// Ellie Sundhei, 3/11/25 chagned back to AXI Interface, added all the registers we think we need

// `resetall
// `timescale 1ns / 1ps
// `default_nettype none

// AXI PVP GEN  V2
// s_axi_aclk	: clock for s_axi_*
// s0_axis_aclk	: clock for s0_axis_*
// aclk			: clock for s1_axis_* and m_axis_*
//
module axi_pvp_gen_v2
	( 
		// AXI Slave I/F for configuration.
		input logic					s_axi_aclk,
		input logic					s_axi_aresetn,

		input logic	[31:0]			s_axi_awaddr,
		input logic	[2:0]			s_axi_awprot,
		input logic					s_axi_awvalid,
		output logic				s_axi_awready,

		input logic	[31:0]			s_axi_wdata,
		input logic	[3:0]			s_axi_wstrb,
		input logic					s_axi_wvalid,
		output logic				s_axi_wready,

		output logic	[1:0]		s_axi_bresp,
		output logic				s_axi_bvalid,
		input	 logic				s_axi_bready,

		input logic	[31:0]			s_axi_araddr,
		input logic	[2:0]			s_axi_arprot,
		input logic					s_axi_arvalid,
		output logic				s_axi_arready,

		output logic	[31:0]		s_axi_rdata,
		output logic	[1:0]		s_axi_rresp,
		output logic				s_axi_rvalid,
		input logic					s_axi_rready,

		// Non AXI inputs
		//input  logic					trigger_tproc,
		input 	logic					aclk,
		input		logic				aresetn,

		// M AXIS

		output logic	[31:0]			m_axi_awaddr,
		output logic	[2:0]			m_axi_awprot,
		output logic					m_axi_awvalid,
		input logic						m_axi_awready,

		output logic	[31:0]			m_axi_wdata,
		output logic	[3:0]			m_axi_wstrb,
		output logic					m_axi_wvalid,
		input	 logic					m_axi_wready,

		input logic	[1:0]			m_axi_bresp,
		input logic					m_axi_bvalid,
		output logic				m_axi_bready,

		output	 logic [31:0]		m_axi_araddr,
		output	 logic [2:0]		m_axi_arprot,
		output	 logic				m_axi_arvalid,
		input	 logic				m_axi_arready,

		input logic	[31:0]			m_axi_rdata,
		input logic	[1:0]			m_axi_rresp,
		input	 logic				m_axi_rvalid,
		output logic				m_axi_rready,

		// Non AXI-LITE outputs
		output logic [4:0]  		select_mux_o,
		output logic 				ro,
		output logic 				done
	);

/*********/
/* Ports */
/*********/

// // S AXIS
// input					s_axi_aclk;
// input					s_axi_aresetn;

// input	[31:0]			s_axi_awaddr;
// input	[2:0]			s_axi_awprot;
// input					s_axi_awvalid;
// output					s_axi_awready;

// input	[31:0]			s_axi_wdata;
// input	[3:0]			s_axi_wstrb;
// input					s_axi_wvalid;
// output					s_axi_wready;

// output	[1:0]			s_axi_bresp;
// output					s_axi_bvalid;
// input					s_axi_bready;

// input	[31:0]			s_axi_araddr;
// input	[2:0]			s_axi_arprot;
// input					s_axi_arvalid;
// output					s_axi_arready;

// output	[31:0]			s_axi_rdata;
// output	[1:0]			s_axi_rresp;
// output					s_axi_rvalid;
// input					s_axi_rready;

// input 					trigger_pvp;

// // M AXIS

// output	[31:0]			m_axi_awaddr;
// output	[2:0]			m_axi_awprot;
// output					m_axi_awvalid;
// input					m_axi_awready;

// output	[31:0]			m_axi_wdata;
// output	[3:0]			m_axi_wstrb;
// output					m_axi_wvalid;
// input					m_axi_wready;

// input	[1:0]			m_axi_bresp;
// input					m_axi_bvalid;
// output					m_axi_bready;

// output	[31:0]			m_axi_araddr;
// output	[2:0]			m_axi_arprot;
// output					m_axi_arvalid;
// input					m_axi_arready;

// input	[31:0]			m_axi_rdata;
// input	[1:0]			m_axi_rresp;
// input					m_axi_rvalid;
// output					m_axi_rready;

// output trigger;
// output mux;

/********************/
/* Internal signals */
/********************/
// Registers.
logic [31:0] mosi_output;
logic [1:0]  mux;

logic [19:0] START_VAL_0_REG; 
logic [19:0] START_VAL_1_REG; 
logic [19:0] START_VAL_2_REG;
logic [19:0] START_VAL_3_REG; 

logic [19:0] STEP_SIZE_REG;
logic [3:0]  ACTIVE_DACS_REG; 

logic [5:0] DEMUX_0_REG;
logic [5:0] DEMUX_1_REG;
logic [5:0] DEMUX_2_REG;
logic [5:0] DEMUX_3_REG;

logic 		TRIGGER_PVP_REG;
logic 		TRIGGER_AWG_REG;

/**************/
/* Parameters */
/**************/
parameter NUM_CYCLES = 256;
parameter DWELL_CYCLES = 16;

logic [4:0] mux1 = 5'b00001;
logic [4:0] mux2 = 5'b00010;
logic [4:0] mux3 = 5'b00100;
logic [4:0] mux4 = 5'b10000;

assign SELECT = (select_mux_o == 2'b00) ? mux1 : (select_mux_o == 2'b01) ? mux2 : (select_mux_o == 2'b10) ? mux3 : mux4;
assign m_axi_wvalid = 1; //BIG CHANGE THIS IS TIED SO SPI MIGHT UNDERSTAND OUR MESSAGES


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
		.STEP_SIZE_REG	(STEP_SIZE_REG	),
		.PVP_WIDTH_REG	(PVP_WIDTH_REG), 
		.NUM_DIMS_REG 	(NUM_DIMS_REG),

		.DEMUX_0_REG (DEMUX_0_REG),
		.DEMUX_1_REG (DEMUX_1_REG),
		.DEMUX_2_REG (DEMUX_2_REG),
		.DEMUX_3_REG (DEMUX_3_REG)

	);

/*
 # PVP Gen Control Registers
    
    # START_VAL_0_REG : 20 bit
    # START_VAL_1_REG : 20 bit
    # START_VAL_2_REG : 20 bit
    # START_VAL_3_REG : 20 bit
    
    # TRIGGER_PVP_REG: 1 bit
    
    # DWELL_CYCLES_REG : 16 bit
    # CYCLES_TILL_READOUT : 16 bit
    
    # STEP_SIZE_REG : 20 bit
    # PVP_WIDTH_REG : 10 bit
    # NUM_DIMS_REG : 3 bits
    
    # DEMUX_0_REG : 6 bit (dac that changes value every cycle) (demuxing)
    # DEMUX_1_REG : 6 bit (dac that changes value every depth^1 cycles)
    # DEMUX_2_REG : 6 bit (dac that changes value every depth^2 cycles)
    # DEMUX_3_REG : 6 bit (dac that changes value every depth^3 cycles)
    
    ## READ_ONLY REGISTER
    # mosi_o : 32 bit



*/


pvp_fsm_gen // getting rid of parameters 3/11/25
		fsm_i 
		(.rstn			(aresetn),
		.clk			(aclk),
		.TRIGGER_PVP_REG	(TRIGGER_PVP_REG),
		
		.START_VAL_0_REG 		(START_VAL_0_REG),
		.START_VAL_1_REG 		(START_VAL_1_REG),
		.START_VAL_2_REG 		(START_VAL_2_REG),
		.START_VAL_3_REG 		(START_VAL_3_REG),

		.DWELL_CYCLES_REG 			(DWELL_CYCLES_REG),
		.CYCLES_TILL_READOUT_REG 	(CYCLES_TILL_READOUT_REG),
		.STEP_SIZE_REG 				(STEP_SIZE_REG),
		.PVP_WIDTH_REG 				(PVP_WIDTH_REG),
		.NUM_DIMS_REG 				(NUM_DIMS_REG),

		//outputs
		.mosi_o			(m_axi_wdata), //zoe approved
        .select_mux_o 	(select_mux_o),
		.readout_o		(ro), //this should be an output port directly off the blcok (not axi, Spi doesn/t want it)
		.trigger_spi_o  (m_axi_wready),
		.done 			(done)
		);




endmodule

