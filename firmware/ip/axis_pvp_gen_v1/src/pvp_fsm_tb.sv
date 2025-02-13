/***
  A Testbench meant to test all possible cases of switch pins used within the lab.
	Based off of the fulladder testbench inside of the MicroP's page.

  Calls on a text file "lab02_testvectors.tv", however due to odd pathing the full
	address of the file to computer needed to be written. For future users, it
	will be necessary to replace this current pathing with their own to ensure
	the right connection and no errors being thrown during Simulation.

  @author: zoe worrall
	   zworrall@g.hmc.edu
  @version: 09/05/2024
  
*/
`timescale 1ns/1ns
`default_nettype none
`define N_TV 1

module pvp_fsm_tb();

 // Set up test signals
// logic clk, reset; 					// clk is necessary in all test benches
// logic [23:0] dac1, dac2, dac3, dac4;
// logic [4:0] mux;
// logic trigger, en, 

  logic clk, rstn;
  logic [97:0]	 data_i;
  logic					 tvalid_i;

  logic					 iter_rd_en_o;
  logic					 iter_wr_en_o;
  logic					 iter_empty_i;
  logic	         iter_full_i;

  logic	[23:0]   iter_din_o;

  logic [4:0] c_mux_o;

  logic [10:0] placeholder;

 // Instatiation of lab 1's top module
    pvp_fsm_gen fsm (
    .rstn,
	  .clk,

    .data_i,
	  .tvalid_i,

    .iter_rd_en_o,
    .iter_wr_en_o,
    .iter_empty_i,
	  .iter_full_i,

    .iter_din_o,
    .c_mux_o
   );
   
 // Create dumpfile
 initial
   begin
     $dumpfile("testbench_pvp_fsm_tb.vcd");
     $dumpvars(0, pvp_fsm_tb);
   end
    
    // generate clock and load signals
		always begin
				clk = 1'b0; #5;
				clk = 1'b1; #5;
		end
		// to do: walk through the FSM
    // 1. WAIT_LOAD -- confirm nothing happens while waiting
        // confirm that after muxes are loaded the state changes to LOAD
    // 2. LOAD -- load 2 DACs
        // confirm that the state changes when the iter signal is full
        // confirm wr_en is turned on
        // confirm that the DAC's being put in via mem_i are coming out of iter_din_x's
    // 3. WAIT_SEND -- confirm that nothing happens until the mem_i[97] is 1
    // 4. SEND -- confirm that rd_en is turned on
        // confirm that state changes when the iterator is empty
initial
	begin
    
    
      rstn = 0;
      #10;
      rstn = 1;
      #10;

      placeholder = 1;

      // all things happen a clock tick behind when they are sent out initially - that is to say that we need to delay 20 beats rather than 10 in order to confirm our outputs make
      // sense with the inputs

      // WAIT_LOAD
      // no trigger or mux value set
      data_i = 98'b0_0_010101010101010101010101_110011001100110011001100_111100001111000011110000_111111111111000000000000;
      tvalid_i = 1;
      iter_empty_i = 1;
      iter_full_i = 0;
      #27;
      if (iter_rd_en_o) begin $display("e1 - read shouldn't be enabled"); end
      else if (iter_wr_en_o) begin $display("e1 - write shouldn't be enabled"); end
      else if (iter_din_o != 0) begin $display("e1 - there shouldn't be any output at the moment"); end
      else $display("Testbench ran successfully");

      #10;
      placeholder = 2;

      // LOADing starts when we set mux_en to enabled; SHOULDN'T RUN
      data_i = 98'b1_0_010101010101010101010101_110011001100110011001100_111100001111000011110000_111111111111000000000000;
      tvalid_i = 1;
      iter_empty_i = 1;
      iter_full_i = 0;
      #10;
      if (iter_rd_en_o) begin $display("e2 - read shouldn't be enabled"); end
      else if (iter_wr_en_o) begin $display("e2 - write shouldn't be enabled"); end
      else if (iter_din_o != 0) begin $display("e2 - there shouldn't be any output at the moment"); end
      else $display("Testbench ran successfully");

    
      #10;
      placeholder = 3;

    // LOAD_MUX state should start after we send this instruction
    // in LOAD_MUX state, the muxes are loaded with the current last 5 digits of every dac address
    // takes two ticks(?)
      data_i = 98'b0_1__00000000_00000000_00000101__00000000_00000000_00001100__00000000_00000000_00001111__00000000_00000000_00000100;
      tvalid_i = 1;
      iter_empty_i = 1;
      iter_full_i = 0;
      #20;
      $display("MUX VAL %h", c_mux_o);
      $display("ITER VALS %h", iter_din_o!=0);
      if (iter_rd_en_o) begin $display("e3 - read shouldn't be enabled (LOAD ONLY)"); end
      else if (iter_wr_en_o) begin $display("e3 - write shouldn't be enabled (SEND ONLY)"); end
      else if (iter_din_o != 0) begin $display("e3 - there shouldn't be any output at the moment, %h", iter_din_o); end
      else if (c_mux_o == 5'b0100) begin $display("Testbench ran successfully"); end
      else $display("e3 - wsomething's gone wrong with the multiplexed values");

      
      #10;
      placeholder = 4;


    // LOADing starts when we set mux_en to enabled; muxes should stay the same, nothing should change
      data_i = 98'b0_0__00000000_00000000_00000111__00000000_00000000_00001111__00000000_00000000_00001100__00000000_00000000_00000101;
      tvalid_i = 1;
      iter_empty_i = 1;
      iter_full_i = 0;
      #20;
      $display("MUX VAL %h", c_mux_o);
      if (~iter_rd_en_o) begin $display("e4 - Iterator should be reading during LOAD state"); end
      else if (iter_wr_en_o) begin $display("e4 - write shouldn't be enabled (SEND ONLY)"); end
      else if (iter_din_o != 0 ) begin $display("e4 - there shouldn't be any output at the moment"); end
      else if (c_mux_o == 5'b0100) begin $display("Testbench ran successfully"); end
      else $display("e4 - wsomething's gone wrong with the multiplexed values");

      
      #10;
      placeholder = 5;

    // WAIT TO SEND
      data_i = 98'b1_0_010101010101010101010101_110011001100110011001100_111100001111000011110000_111111111111000000000000;
      tvalid_i = 1;
      iter_empty_i = 1;
      iter_full_i = 0;
      #20;
      $display("MUX VAL %h", c_mux_o);
      if (~iter_rd_en_o) begin $display("e5 - rIterator should be reading during LOAD state"); end
      else if (iter_wr_en_o) begin $display("e5 - write shouldn't be enabled (SEND ONLY)"); end
      else if (iter_din_o == 0) begin $display("e5 - there shouldn't be any output at the moment"); end
      else if (c_mux_o == 5'b0100) begin $display("Testbench ran successfully"); end
      else $display("e5 - something's gone wrong with the multiplexed values");

      #10;
      placeholder = 6;
      
    // SEND state
      data_i = 98'b1_0_010101010101010101010101_110011001100110011001100_111100001111000011110000_111111111111000000000000;
      tvalid_i = 1;
      iter_empty_i = 0;
      iter_full_i = 1;
      #20;
      $display("MUX VAL %h", c_mux_o);
      $display("ITER VALS %h", iter_din_o!=0);
      if (iter_rd_en_o) begin $display("e6 - read shouldn't be enabled (LOAD ONLY)"); end
      else if (~iter_wr_en_o) begin $display("e6 - write should be enabled (SEND ONLY)"); end
      else if (iter_din_o!= 0) begin $display("e6 - there shouldn't be any output at the moment"); end
      else if (c_mux_o == 5'b0100) begin $display("Testbench ran successfully"); end
      else $display("e6 - something's gone wrong with the multiplexed values");

      
      #10;
      placeholder = 7;
       
    // we should return to the wait_send state
      data_i = 98'b0_0_010101010101010101010101_110011001100110011001100_111100001111000011110000_111111111111000000000000;
      tvalid_i = 1;
      iter_empty_i = 1; // we should leave
      iter_full_i = 0;
      #20;
      $display("MUX VAL %h", c_mux_o);
      if (iter_rd_en_o) begin $display("e7 - read shouldn't be enabled (LOAD ONLY)"); end
      else if (iter_wr_en_o) begin $display("e7 - write shouldn't be enabled (SEND ONLY)"); end
      else if (iter_din_o != 0) begin $display("e7 - there shouldn't be any output at the moment"); end
      else if (c_mux_o == 5'b0100) begin $display("Testbench ran successfully"); end
      else $display("e7 - something's gone wrong with the multiplexed values");

      #10;
      placeholder = 8;
      rstn = 0;
      #10;
      rstn = 1;
      #10;

       // we should return to the wait_send state
      data_i = 98'b0_0_010101010101010101010101_110011001100110011001100_111100001111000011110000_111111111111000000000000;
      tvalid_i = 1;
      iter_empty_i = 1; // we should leave
      iter_full_i = 0;
      #20;
      $display("MUX VAL %h", c_mux_o);
      if (iter_rd_en_o) begin $display("e8 - read shouldn't be enabled (LOAD ONLY)"); end
      else if (iter_wr_en_o) begin $display("e8 - write shouldn't be enabled (SEND ONLY)"); end
      else if (iter_din_o != 0) begin $display("e8 - there shouldn't be any output at the moment"); end
      else if (c_mux_o == 0) begin $display("Testbench ran successfully"); end
      else $display("e8 - something's gone wrong with the multiplexed values");



 end


endmodule