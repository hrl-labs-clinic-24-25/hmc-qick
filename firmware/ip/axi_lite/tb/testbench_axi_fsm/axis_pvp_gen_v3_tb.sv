// Modelsim-ASE requires a timescale directive
// `timescale 1 ps / 1 ps


// `resetall
// `timescale 1ns / 1ps
// `default_nettype none

/**

Based on the test bench in the corresponding video https://www.youtube.com/watch?v=qqI9QIkGFIQ 

Confirming that data interacts with AXI blocks as anticipated

*/
module axis_pvp_gen_v3_tb ();

    logic clk = 0;
    logic rstn;

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
        end

    localparam AXI_ADDR_WIDTH = 32;
    localparam AXI_DATA_WIDTH = 32;


    logic [31 : 0]                S_AXI_AWADDR;
    logic [2 : 0]                S_AXI_AWPROT;
    logic                        S_AXI_AWVALID;
    logic                        S_AXI_AWREADY;

    logic [AXI_ADDR_WIDTH/8-1 : 0] S_AXI_WSTRB;
    logic                          S_AXI_WVALID;
    logic                          S_AXI_WREADY;

    logic [1 : 0]                S_AXI_BRESP;
    logic                        S_AXI_BVALID;
    logic                        S_AXI_BREADY;

    logic [31 : 0]  S_AXI_ARADDR;
    logic [2 : 0]                 S_AXI_ARPROT;
    logic                         S_AXI_ARVALID;
    logic                         S_AXI_ARREADY;



    logic [31 : 0]                M_AXI_AWADDR;
    logic [2 : 0]                M_AXI_AWPROT;
    logic                        M_AXI_AWVALID;
    logic                        M_AXI_AWREADY;

    logic [AXI_DATA_WIDTH-1 : 0]   M_AXI_WADDR;
    logic [AXI_ADDR_WIDTH/8-1 : 0] M_AXI_WSTRB;
    logic                          M_AXI_WVALID;
    logic                          M_AXI_WREADY;

    logic [1 : 0]                M_AXI_BRESP;
    logic                        M_AXI_BVALID;
    logic                        M_AXI_BREADY;

    logic [31 : 0]  M_AXI_ARADDR;
    logic [2 : 0]                 M_AXI_ARPROT;
    logic                         M_AXI_ARVALID;
    logic                         M_AXI_ARREADY;



    logic         init_transaction;
    logic [31:0]  init_counter;

    logic [31:0] GPO;
    logic SS;
    logic SSN;
    logic SCLK;
    logic MOSI_OUTPUT;

    logic [31:0] M_AXI_WDATA;
    logic [31:0] S_AXI_WDATA;

    logic [31:0] M_AXI_RDATA;
    logic [31:0] S_AXI_RDATA;

    logic [1:0] M_AXI_RRESP;
    logic [1:0] S_AXI_RRESP;

    logic  M_AXI_RREADY;
    logic  S_AXI_RREADY;

    logic [4:0] mux;
    logic trigger_spi_o;

    always_ff @(posedge clk) begin
        if (~rstn) begin
            init_transaction <= 0;
            init_counter     <= 0;
        end else begin
            init_transaction <= 0;
            init_counter     <= init_counter+1;
        end

        if (init_counter == 10) begin init_transaction <= 1; end
    end
    
    axil_pvp_gen_v3 apg_i
    (
        .s_axi_aclk		(clk),
		.s_axi_aresetn	(rstn),

		.s_axi_awaddr	(S_AXI_AWADDR),
		.s_axi_awprot	(S_AXI_AWPROT),
		.s_axi_awvalid	(S_AXI_AWVALID),
		.s_axi_awready	(S_AXI_AWREADY),

		.s_axi_wdata	(S_AXI_WDATA),
		.s_axi_wstrb	(S_AXI_WSTRB),
		.s_axi_wvalid	(S_AXI_WVALID),
		.s_axi_wready	(S_AXI_WREADY),

		.s_axi_bresp	(S_AXI_BRESP),
		.s_axi_bvalid	(S_AXI_BVALID),
		.s_axi_bready	(S_AXI_BREADY),

		.s_axi_araddr	(S_AXI_ARADDR),
		.s_axi_arprot	(S_AXI_ARPROT),
		.s_axi_arvalid	(S_AXI_ARVALID),
		.s_axi_arready	(S_AXI_ARREADY),

		.s_axi_rdata	(S_AXI_RDATA),
		.s_axi_rresp	(S_AXI_RRESP),
		.s_axi_rvalid	(S_AXI_RVALID),
		.s_axi_rready	(S_AXI_RREADY),
		// AXIS Master for output.
		.m_axi_awaddr	(M_AXI_AWADDR),
		.m_axi_awprot	(M_AXI_AWPROT),
		.m_axi_awvalid	(M_AXI_AWVALID),
		.m_axi_awready	(M_AXI_AWREADY),

		.m_axi_wdata	(M_AXI_WDATA),
		.m_axi_wstrb	(M_AXI_WSTRB),
		.m_axi_wvalid	(M_AXI_WVALID),
		.m_axi_wready	(M_AXI_WREADY),

		.m_axi_bresp	(M_AXI_BRESP),
		.m_axi_bvalid	(M_AXI_BVALID),
		.m_axi_bready	(M_AXI_BREADY),

		.m_axi_araddr	(M_AXI_ARADDR),
		.m_axi_arprot	(M_AXI_ARPROT),
		.m_axi_arvalid	(M_AXI_ARVALID),
		.m_axi_arready	(M_AXI_ARREADY),

		.m_axi_rdata	(M_AXI_RDATA),
		.m_axi_rresp	(M_AXI_RRESP),
		.m_axi_rvalid	(M_AXI_RVALID),
		.m_axi_rready	(M_AXI_RREADY),


		// Non AXI-LITE 
		.TRIGGER_AWG_REG (init_transaction), // trigger for AWG
		.select  (mux), // DAC demuxing set of 5 pins

		.trigger_spi_o (trigger_spi_o) // trigger for SPI
    );

    axi_lite_master
     #(
       .AXI_ADDR_WIDTH(32),
       .AXI_DATA_WIDTH(32)
       )
   axi_lite_master_i
     (
      .init_transaction(init_transaction),

      .M_AXI_ACLK(clk),
      .M_AXI_ARESETN(rstn),

      // aw
      .M_AXI_AWADDR(S_AXI_AWADDR),
      .M_AXI_AWPROT(S_AXI_AWPROT),
      .M_AXI_AWVALID(S_AXI_AWVALID),
      .M_AXI_AWREADY(S_AXI_AWREADY),

      // w
      .M_AXI_WDATA(S_AXI_WDATA),
      .M_AXI_WSTRB(S_AXI_WSTRB),
      .M_AXI_WVALID(S_AXI_WVALID),
      .M_AXI_WREADY(S_AXI_WREADY),

      // b resp
      .M_AXI_BRESP(S_AXI_BRESP),
      .M_AXI_BVALID(S_AXI_BVALID),
      .M_AXI_BREADY(S_AXI_BREADY),

      // ar
      .M_AXI_ARADDR(S_AXI_ARADDR),
      .M_AXI_ARPROT(S_AXI_ARPROT),
      .M_AXI_ARVALID(S_AXI_ARVALID),
      .M_AXI_ARREADY(S_AXI_ARREADY),

      // r
      .M_AXI_RDATA(S_AXI_RDATA),
      .M_AXI_RRESP(S_AXI_RRESP),
      .M_AXI_RVALID(S_AXI_RVALID),
      .M_AXI_RREADY(S_AXI_RREADY)

      );

    axi_spi_simple axi_spi_i
    (
        .saxi_aclk (clk),
        .saxi_aresetn(rstn),
        .saxi_awaddr(M_AXI_AWADDR),
		.saxi_awprot	(M_AXI_AWPROT),
		.saxi_awvalid	(M_AXI_AWVALID),
		.saxi_awready	(M_AXI_AWREADY),
		.saxi_wdata	(M_AXI_WDATA),
		.saxi_wstrb	(M_AXI_WSTRB),
		.saxi_wvalid	(M_AXI_WVALID),
		.saxi_wready	(M_AXI_WREADY),
		.saxi_bresp	(M_AXI_BRESP),
		.saxi_bvalid	(M_AXI_BVALID),
		.saxi_bready	(M_AXI_BREADY),
		.saxi_araddr	(M_AXI_ARADDR),
		.saxi_arprot	(M_AXI_ARPROT),
		.saxi_arvalid	(M_AXI_ARVALID),
		.saxi_arready	(M_AXI_ARREADY),
		.saxi_rdata	(M_AXI_RDATA),
		.saxi_rresp	(M_AXI_RRESP),
		.saxi_rvalid	(M_AXI_RVALID),
		.saxi_rready	(M_AXI_RREADY),
        .gpo (GPO),
        .ss (SS),
        .ssn (SSN),
        .sclk (SCLK),
        .miso (1'b0),
        .mosi (MOSI_OUTPUT)
    );

endmodule