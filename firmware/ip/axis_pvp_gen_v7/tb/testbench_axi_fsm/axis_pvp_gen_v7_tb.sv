/**
* File: axis_pvp_gen_v3_tb.sv
* Description:
*     This is a test bench for the AXI PVP generator. It is used to confirm that the data interacts with the AXI blocks as anticipated.
* Author: Zoe Worrall, zoe.worrall@me.com
* Date: March 13, 2025
*/


/**

Based on the test bench in the corresponding video https://www.youtube.com/watch?v=qqI9QIkGFIQ 
 50535, 248615
*/ 
module axis_pvp_gen_v7_tb ();

    logic clk = 0;
    logic rstn;

    localparam freq = 100.0e6;
    localparam clk_period = (1/freq)/1e-9;

    logic done;
    logic [31:0]  init_counter;

    always begin
        clk = #(clk_period/2) ~clk;
    end

    initial
        begin
            rstn = 0;
            #100
            rstn = 1;
        end

    parameter AXI_ADDR_WIDTH = 32;
    parameter AXI_DATA_WIDTH = 32;


    logic [5 : 0]                S_AXI_AWADDR;
    logic [2 : 0]                S_AXI_AWPROT;
    logic                        S_AXI_AWVALID;
    logic                        S_AXI_AWREADY;

    logic [3 : 0]                  S_AXI_WSTRB;
    logic                          S_AXI_WVALID;
    logic                          S_AXI_WREADY;
    logic [31:0]                   S_AXI_WDATA;

    logic [1 : 0]                S_AXI_BRESP;
    logic                        S_AXI_BVALID;
    logic                        S_AXI_BREADY;

    logic [5 : 0]                 S_AXI_ARADDR;
    logic [2 : 0]                 S_AXI_ARPROT;
    logic                         S_AXI_ARVALID;
    logic                         S_AXI_ARREADY;

    logic [31:0]                  S_AXI_RDATA;
    logic [1:0]                   S_AXI_RRESP;
    logic                         S_AXI_RREADY;

    logic         init_transaction;
    logic [31:0]  outsig;

    logic COPI;
    logic CS;
    logic SCK;
    logic LDACN;
    logic CLRN;


    logic [4:0] mux;
    logic trigger_spi_o;

    always_ff @(posedge clk) begin
        if (~rstn) begin
            // TRIGGER_PVP_REG <= 0;
            init_counter     <= 0;
        end else begin
            // TRIGGER_PVP_REG <= 0;
            init_counter     <= init_counter+1;
        end
    end
    
    axi_lite_master
     #(
       .AXI_ADDR_WIDTH(6),
       .AXI_DATA_WIDTH(32)
       )
   axi_lite_master_0
     (
      .init_transaction(init_transaction),
      .output_data (outsig),

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

    axi_pvp_gen_v5 pvp_gen_i
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

		// Non AXI-LITE 
		.TRIGGER_AWG_REG (init_transaction), // trigger for AWG
		.select_mux  (mux), // DAC demuxing set of 5 pins
        .COPI (COPI),
		.SCK (SCK),
		.LDACN (LDACN),
		.CLRN (CLRN),
		.CS (CS),
        .done (done)
    );

endmodule