// Modelsim-ASE requires a timescale directive
// `timescale 1 ps / 1 ps


// `resetall
// `timescale 1ns / 1ps
// `default_nettype none

/**

Based on the test bench in the corresponding video https://www.youtube.com/watch?v=qqI9QIkGFIQ 

Confirming that data interacts with AXI blocks as anticipated

*/
module axi_lite_tb ();

    logic clk = 0;
    logic rstn;

    localparam freq = 50.0e6;
    localparam clk_period = (1/freq)/1e-9;


    logic miso;
    logic mosi;

    always begin
        clk = #(clk_period/2) ~clk;
    end

    initial
        begin
            rstn = 0;
            #100
            rstn = 1;
            #100;
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
            // begin increasing the counter. The counter is 
            init_transaction <= 0;
            init_counter     <= init_counter+1;
        end

        if (init_counter == 25) begin init_transaction <= 1; end
    end
    

    axi_lite_master
     #(
       .AXI_ADDR_WIDTH(32),
       .AXI_DATA_WIDTH(32)
       )
   axi_lite_master_i
     (
      .init_transaction(init_transaction),

      .M_AXI_ACLK(clk),
      .M_AXI_ARESETN(~rstn),

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


    // testing the axi lite slave to confirm that it run properly when
        // configured with other AXI streams
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
			.s_axil_awaddr			(S_AXI_AWADDR 	),
			.s_axil_awprot			(S_AXI_AWPROT 	),
			.s_axil_awvalid		    (S_AXI_AWVALID	),
			.s_axil_awready		    (S_AXI_AWREADY	),

			// Write Data Channel.
			.s_axil_wdata			(init_counter	),
			.s_axil_wstrb			(S_AXI_WSTRB	),
			.s_axil_wvalid			(S_AXI_WVALID   ),
			.s_axil_wready			(S_AXI_WREADY	),

			// Write Response Channel.
			.s_axil_bresp			(S_AXI_BRESP	),
			.s_axil_bvalid			(S_AXI_BVALID	),
			.s_axil_bready			(S_AXI_BREADY	),

			// Read Address Channel.
			.s_axil_araddr			(S_AXI_ARADDR 	),
			.s_axil_arprot			(S_AXI_ARPROT 	),
			.s_axil_arvalid			(S_AXI_ARVALID	),
			.s_axil_arready			(S_AXI_ARREADY	),

			// Read Data Channel.
			.s_axil_rdata			(S_AXI_RDATA	),
			.s_axil_rresp			(S_AXI_RRESP	),
			.s_axil_rvalid			(S_AXI_RVALID	),
			.s_axil_rready			(S_AXI_RREADY	),

			// OUTPUT AXI
			// Write Address Channel.
			.m_axil_awaddr			(M_AXI_AWADDR 	),
			.m_axil_awprot			(M_AXI_AWPROT 	),
			.m_axil_awvalid			(M_AXI_AWVALID	),
			.m_axil_awready			(M_AXI_AWREADY	),

			// Write Data Channel.
			.m_axil_wdata			(M_AXI_WDATA	),
			.m_axil_wstrb			(M_AXI_WSTRB	),
			.m_axil_wvalid			(M_AXI_WVALID   ),
			.m_axil_wready			(M_AXI_WREADY	),

			// Write Response Channel.
			.m_axil_bresp			(M_AXI_BRESP	),
			.m_axil_bvalid			(M_AXI_BVALID	),
			.m_axil_bready			(M_AXI_BREADY	),

			// Read Address Channel.
			.m_axil_araddr			(M_AXI_ARADDR 	),
			.m_axil_arprot			(M_AXI_ARPROT 	),
			.m_axil_arvalid		    (M_AXI_ARVALID	),
			.m_axil_arready		    (M_AXI_ARREADY	),

			// Read Data Channel.
			.m_axil_rdata			(M_AXI_RDATA	),
			.m_axil_rresp			(M_AXI_RRESP	),
			.m_axil_rvalid			(M_AXI_RVALID	),
			.m_axil_rready			(M_AXI_RREADY	)
		);

    // axi_spi_simple axi_spi_i
    // (
    //     .saxi_aclk (clk),
    //     .saxi_aresetn(rstn),
    //     .saxi_awaddr(M_AXI_AWADDR),
	// 	.saxi_awprot	(M_AXI_AWPROT),
	// 	.saxi_awvalid	(M_AXI_AWVALID),
	// 	.saxi_awready	(M_AXI_AWVREADY),
	// 	.saxi_wdata	(M_AXI_WDATA),
	// 	.saxi_wstrb	(M_AXI_WSTRB),
	// 	.saxi_wvalid	(M_AXI_WVALID),
	// 	.saxi_wready	(M_AXI_WREADY),
	// 	.saxi_bresp	(M_AXI_BRESP),
	// 	.saxi_bvalid	(M_AXI_BVALID),
	// 	.saxi_bready	(M_AXI_BREADY),
	// 	.saxi_araddr	(M_AXI_ARADDR),
	// 	.saxi_arprot	(M_AXI_ARPROT),
	// 	.saxi_arvalid	(M_AXI_ARVALID),
	// 	.saxi_arready	(M_AXI_ARREADY),
	// 	.saxi_rdata	(M_AXI_RDATA),
	// 	.saxi_rresp	(M_AXI_RRESP),
	// 	.saxi_rvalid	(M_AXI_RVALID),
	// 	.saxi_rready	(M_AXI_RREEADY),
    //     .gpo (GPO),
    //     .ss (SS),
    //     .ssn (SSN),
    //     .sclk (SCLK),
    //     .miso (miso),
    //     .mosi (MOSI_OUTPUT)
    // );

endmodule