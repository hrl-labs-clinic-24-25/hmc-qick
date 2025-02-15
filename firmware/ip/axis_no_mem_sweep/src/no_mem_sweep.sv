/***
  no_mem_sweep is a deterministic module that counts up from a given start value in increments of the given step value for 
  a given number of cycles. it formats the output as the 24 bit commands that will be sent via SPI to a given DAC.

  no_mem_sweep_tb is a testbench to test the operation of the above module

  @author: Ellie Sundheim
	   esundheim@g.hmc.edu
  @version: 2/12/2025
  
*/


module no_mem_sweep #(parameter DEPTH = 256)
                    (input logic [19:0] start,
                    input logic [19:0] step,
                    input logic clk, rstn,
                    output logic [31:0] mosi
                    );

parameter [3:0] start_bits = 4'b0001;
logic [7:0] counter;
logic [19:0] curr_val, next_val;

always @(posedge clk)
    if (~rstn) begin
        curr_val <= start;
        counter <= 0;
    end
    else if (counter < DEPTH) begin
        curr_val <= next_val;
        counter <= counter + 1;
    end
    else begin
        curr_val <= curr_val;
        counter <= counter; //freeze counter so that it doesn't overflow and restart the sweep
    end

assign next_val = curr_val + counter*step;
assign mosi = {8'b0, start_bits, curr_val};

endmodule


module no_mem_sweep_tb();
    logic rstn, clk;
    logic [19:0] start, step;
    logic [31:0] mosi;

    // test generation of 16 evenly spaced steps
    no_mem_sweep #(16) dut ( .rstn(rstn), .clk(clk), .start(start), .step(step), .mosi(mosi));

    // generate testbench clock
    always begin 
        clk = 0; #5; clk = 1; #5;
    end

    // initialize
    initial begin
        start = 20'b01010_10010_10101_01010;
        step = 20'b00000_00000_00000_10000;
	    rstn = 0; #12; rstn = 1; 
	end

    // apply test vectors on rising edge of clk 
    always @(posedge clk) 
        begin
	
        end 

    always @(negedge clk)
        begin
        
        end
endmodule
