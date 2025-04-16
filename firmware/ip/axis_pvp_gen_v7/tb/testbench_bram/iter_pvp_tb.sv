// Modelsim-ASE requires a timescale directive
// `timescale 1 ps / 1 ps

/**

Based on the test bench in the corresponding video https://www.youtube.com/watch?v=qqI9QIkGFIQ 

Confirming that data interacts with AXI blocks as anticipated
Zoe Worrall, March 3 2025

*/
module iter_pvp_tb ();

    logic clk = 0;
    logic rstn;

    logic wr_en;
    logic [31:0] din;

    logic rd_en;
    logic [31:0] dout;

    logic top, base, full;

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
            #100

            wr_en = 1;
            din = 32'h0;
            while(!full) begin
                #20;
                if (full) begin
                    din = din + 3;
                    #40;
                    wr_en = 0;
                end
                din = din + 1;
            end
            // confirming that you can stop a trial while its running
            wr_en = 0;
            #100;
            
            rd_en = 1;
            while(!top) begin
                #20;
                if (top) begin
                    rd_en = 0;
                end
            end
            // confirming that you can stop a trial while its running
        end


iter_pvp #(.N (10), .B (32))
    pvp_i  (
		// Reset and clock.
		.rstn,
		.clk,

        .wr_en, // inputs
        .din,

        .rd_en, // inputs
        .dout,

        .top, // outputs
        .base,
        .full
	);

endmodule