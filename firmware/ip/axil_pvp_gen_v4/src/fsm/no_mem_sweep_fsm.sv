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


module no_mem_sweep_fsm #(parameter DEPTH = 256)
                    (input logic [19:0] start, step,
                    input logic [7:0] index, //index for sweep
                    input logic clk, rstn, enable, direction,
                    input logic [1:0] mode,
                    output logic [31:0] mosi,
                    output logic top, base
                    );

    parameter [3:0] start_bits = 4'b0001;
    logic [7:0] counter;
    logic [19:0] curr_val, next_val, top_val, base_val;
    logic [19:0] potential_val;

    // Compute boundaries based on mode.
    // For mode 2 ("Spiral"), adjust the boundaries using 'index'.
    // For other modes, use fixed boundaries.
    always_comb begin
        if (mode == 2) begin
            base_val = start + (index * step);
            top_val  = start + ((DEPTH - index) * step);
        end else begin
            base_val = start;
            top_val  = start + (DEPTH * step);
        end
    end

    // Compute the potential next value (without boundary checks).
    assign potential_val = direction ? (curr_val + step) : (curr_val - step);

    always_ff @(posedge clk) begin
        if (~rstn) begin
            curr_val <= base_val;
            counter <= 0;
        end
        else if (enable) begin
            case (mode)
                2'b10: begin //"Spiral" increment mode

                    if (direction && (curr_val < top_val)) begin
                        curr_val <= next_val;
                        counter <= counter + 1;
                    end 
                    else if (!direction && (curr_val > base_val)) begin
                        curr_val <= next_val;
                        counter <= counter - 1;
                    end
                    else begin
                        curr_val <= curr_val;
                        counter <= counter; // Freeze counter to prevent overflow
                    end
                end
                2'b01: begin // "Top-Bottom" increment mode
                    if (direction == 1 && counter < DEPTH) begin
                        curr_val <= next_val;
                        counter <= counter + 1;
                    end 
                    else if (direction == 0 && counter > 0) begin
                        curr_val <= next_val;
                        counter <= counter - 1;
                    end
                end
                2'b00: begin // Default mode (increment only)
                    if (counter < DEPTH) begin
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

    // Clamp the potential value between base_val and top_val.
    always_comb begin
        if (potential_val > top_val)
            next_val = top_val;
        else if (potential_val < base_val)
            next_val = base_val;
        else
            next_val = potential_val;
    end

    assign mosi = ({{{2'h00}}, start_bits, curr_val});
    assign top = (mode == 2)? ((curr_val == (start + (DEPTH-index)*step))) : ((curr_val == (start + (DEPTH)*step))); // indicate 1 before top (works with FSM)
    assign base =(mode == 2)? ((curr_val == (start + index*step))) : ((curr_val == start));
endmodule


module no_mem_sweep_tb();
    logic rstn, clk, enable;
    logic [19:0] start, step;
    logic [31:0] mosi;
    logic [1:0] mode;

    // test generation of 256 evenly spaced steps
    no_mem_sweep #(4) dut (.rstn(rstn), .clk(clk), .start(start), .step(step), .enable(enable), .mode(mode), .mosi(mosi));

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

        #110; // Counter will hit the max (256) during this amount of delay time
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
