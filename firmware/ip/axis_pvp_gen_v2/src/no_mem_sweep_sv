/***
  no_mem_sweep is a deterministic module that counts up from a given start value in increments of the given step value for 
  a given number of cycles. it formats the output as the 24 bit commands that will be sent via SPI to a given DAC.

  no_mem_sweep_tb is a testbench to test the operation of the above module

  @author: Ellie Sundheim
	   esundheim@g.hmc.edu
  @version: 2/12/2025

  @author: Cameron Hernandez
        cahernandez@g.hmc.edu
  @version: 2/26/2025
  
*/


module no_mem_sweep #(parameter numSteps = 256)
                    (input logic [19:0] start, step,
                    input logic clk, rstn, enable,
                    input logic [1:0] mode,
                    output logic [31:0] mosi,
                    output logic top, base
                    );

    parameter [3:0] start_bits = 4'b0001;
    logic [7:0] counter;
    logic [19:0] curr_val, next_val;
    logic direction;

    always @(posedge clk) begin
        if (~rstn) begin
            curr_val <= start;
            counter <= 0;
            direction <= 1; 
        end
        else if (enable) begin
            case (mode)
                2'b10: begin //"Spiral" increment mode
                    if (counter < numSteps) begin
                        if (counter % 2 ==0)begin 
                            curr_val <= curr_val + (numSteps - counter);
                        end
                        else begin
                            curr_val <= curr_val - (numSteps - counter);
                        end
                        counter <= counter + 1;
                    end 
                    else begin
                        curr_val <= curr_val;
                        counter <= counter; // Freeze counter to prevent overflow
                    end
                end
                2'b01: begin // "Top-Bottom" increment mode
                    if (counter == 0) begin
                        direction <= 1;  
                    end
                    else if (counter == numSteps - 1) begin
                        direction <= 0;
                    end
                    if (direction == 1 && counter < numSteps - 1) begin
                        curr_val <= next_val;
                        counter <= counter + 1;
                    end 
                    else if (direction == 0 && counter > 0) begin
                        curr_val <= next_val;
                        counter <= counter - 1;
                    end
                end
                2'b00: begin // Default mode (increment only)
                    direction <= 1;
                    if (counter < numSteps - 1) begin
                        curr_val <= next_val;
                        counter <= counter + 1;
                    end
                    else begin
                        curr_val <= curr_val;
                        counter <= counter; // Freeze counter to prevent overflow
                    end
                end
                default: begin
                    // Handle unexpected mode values (optional)
                end
            endcase
        end
    end

    assign next_val = direction ? (curr_val + step) : (curr_val - step); //muxing if direction == 1 add 1 else subtract 1
    assign mosi = {start_bits, curr_val};
    assign top = (curr_val == (start + (numSteps-1)*step)); // indicate 1 before top (works with FSM)
    assign base = (curr_val == start);

endmodule


module no_mem_sweep_tb();
    logic rstn, clk, enable;
    logic [19:0] start, step;
    logic [31:0] mosi;
    logic [1:0] mode;

    // test generation of 256 evenly spaced steps
    no_mem_sweep #(256) dut (.rstn(rstn), .clk(clk), .start(start), .step(step), .enable(enable), .mode(mode), .mosi(mosi));

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
        mode = 1; //toggle between "Default" (mode = 0), "Top-Bottom" (mode = 1),"Sweep" (mode = 2) increment
        #12; 
        
        rstn = 1; 

        $display("MOSI STARTING VALUE IS:", mosi);

        if (mode == 0)begin
            $display("Default mode (increment only)");
        end
        else if (mode == 1)begin
            $display("Testing Top-Bottom mode");
        end
        else begin
            $display("Testing Spiral mode");
        end

        enable = 1;

        #5110; // Counter will hit the max (256) during this amount of delay time
        $finish;
	end

    // Prints time, counter, current value, direciton, and mosi values every clock cycle
    initial begin
       if (mode == 0 | mode == 2)begin
            // Prints time, counter, current value, direciton, and mosi values every clock cycle
            $monitor("Time = %0t: counter = %d, curr_val = %d, mosi = %d",
            $time, dut.counter, dut.curr_val, mosi);
       end
       else begin
            // Prints time, counter, current value, direciton, and mosi values every clock cycle
            $monitor("Time = %0t: counter = %d, curr_val = %d, direction = %d, mosi = %d",
                $time, dut.counter, dut.curr_val, dut.direction, mosi);
       end
    end

    // apply test vectors on rising edge of clk 
    always @(posedge clk) 
        begin
	
        end 

    always @(negedge clk)
        begin
        
        end
endmodule
