/***
  no_mem_sweep is a deterministic module that counts up from a given start value in increments of the given step value for 
  a given number of cycles. it formats the output as the 32 bit commands that will be sent via SPI to a given DAC.

  no_mem_sweep_tb is a testbench to test the operation of the above module

  @author: Ellie Sundheim
	   esundheim@g.hmc.edu
  @version: 2/12/2025

  @author: Cameron Hernandez
        cahernandez@g.hmc.edu
  @version: 2/26/2025
  
  @author: Zoe Worrall
        zworrall@g.hmc.edu
  @vrsion: 3/4/2025

*/


module no_mem_sweep_fsm
                    (
                        start,
                        step,
                        clk,
                        enable,
                        rstn,
                        top,
                        // base,
                        mosi,
                        DEPTH
                    );

/**
* Input Logic
*/
input [19:0] start;
input [19:0] step;
input clk, enable, rstn;
output top; //, base;
output [31:0] mosi;
input [9:0] DEPTH;

parameter [3:0] start_bits = 4'b0001;

logic [7:0]  counter;
logic [19:0] curr_val, next_val;

always @(posedge clk) begin
    if (~rstn) begin
        curr_val <= 0;
        counter  <= 0;
    end
    else if (enable) begin
        if (counter < DEPTH) begin
            curr_val <= next_val;
            counter <= counter + 1;
        end
        else begin
            curr_val <= curr_val;
            counter <= counter; //freeze counter so that it doesn't overflow and restart the sweep
        end
    end 
end

assign next_val = start + step*counter;
assign mosi = {{{8'h00}}, start_bits, curr_val};     // start_bits is 4, curr_val is 20 bits
assign top = (curr_val == (start + (DEPTH-1)*step)); // indicate 1 before top (works with FSM)
// assign base = (curr_val == start);

endmodule


module no_mem_sweep_tb();
    logic rstn;
    logic clk;
    logic enable;
    logic [19:0] start, step;
    logic [31:0] mosi;

    // test generation of 16 evenly spaced steps
    no_mem_sweep #(16) dut ( .rstn(rstn), .clk(clk), .start(start), .step(step), .enable(enable), .mosi(mosi));

    // generate testbench clock
    always begin 
        clk = 0; #5; clk = 1; #5;
    end

    // initialize
    initial begin
        //start = 20'b01010_10010_10101_01010;
        //step = 20'b00000_00000_00000_10000;
        start = 30;
        step = 2;
	    rstn = 0; 
        enable = 0;
        #12; 
        
        rstn = 1; 

        //Test 1: enable is low, so mosi should remain unchanged
        #10;
        $display("Test 1, enalbe is off, mosi value is = %d", mosi);

        //Test 2: enable is now high, so mosi should change
        enable = 1;
        #10;
        $display("Test 2, enable is on, mosi value is = %d", mosi);

        //Test 3: enable is low, mosi should remain unchanged
        enable = 0;
        #10
        $display("Test 3, enalbe is off, mosi value is = %d", mosi);

        //Test 4: enable is now high, so mosi should change
        enable = 1;
        #10;
        $display("Test 4, enable is on, mosi value is = %d", mosi);


	end

    // apply test vectors on rising edge of clk 
    always @(posedge clk) 
        begin
	
        end 

    always @(negedge clk)
        begin
        
        end
endmodule
