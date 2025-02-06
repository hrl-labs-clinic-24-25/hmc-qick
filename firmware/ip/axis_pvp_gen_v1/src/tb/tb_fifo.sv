`timescale 1ns/1ns
`default_nettype none
`define N_TV 15

module tb_fifo();
    logic rstn, clk, wr_en, rd_en, full, empty, full_exp, empty_exp;
    logic [23:0] din, dout, dout_exp;
    logic [15:0] vectornum;
    logic [51:0] testvectors[10000:0]; // r_en_ wr_en_ din[23:0]_dout[23:0]_full_empty

    // fifo with default width of B = 4 bits, depth of N = 4
    fifo_pvp #(.N(4), .B(4)) dut (rstn, clk, wr_en, din, rd_en, dout, full, empty);

    // generate testbench clock
    always begin 
        clk = 0; #5; clk = 1; #5;
    end

    // load some vectors and look for them on the reverse
    initial begin
        rstn = 0; #12; rstn = 1;
        $readmemb("tb_fifo.tv", testvectors);
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