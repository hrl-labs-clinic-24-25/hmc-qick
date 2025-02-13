`timescale 1ns/1ns
`default_nettype none
`define N_TV 15

module tb_fifo();
    logic rstn, clk, wr_en, rd_en, full, empty, full_exp, empty_exp;
    logic [3:0] din, dout, dout_exp;
    logic [15:0] vectornum;
    logic [11:0] testvectors[10000:0]; // r_en_ wr_en_ din[3:0]_dout[3:0]_full_empty

    // fifo with width of B = 4 bits, depth of N = 4
    iter #(.N(4), .B(4)) 
	dut ( .rstn(rstn), .clk(clk), .wr_en(wr_en), .din(din), .rd_en(rd_en), 
	.dout(dout), .full(full), .empty(empty));

    // generate testbench clock
    always begin 
        clk = 0; #5; clk = 1; #5;
    end

    // load some vectors and look for them on the reverse
    initial begin
        $readmemb("C:/Users/Ellie/Documents/GitHub/hmc-qick/firmware/ip/axis_pvp_gen_v1/src/tb/tb_fifo.tv", testvectors, 0, `N_TV - 1);
	    rstn = 0; #12; rstn = 1;  
        vectornum = 0; 
        dout = 4'b0; 
	end

    // apply test vectors on rising edge of clk 
    always @(posedge clk) 
    begin
      #1; {rd_en, wr_en, din, dout_exp, full_exp, empty_exp} = testvectors[vectornum]; 
    end 

    always @(negedge clk)
        begin
        vectornum = vectornum + 1;
        end

endmodule