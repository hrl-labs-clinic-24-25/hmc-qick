/***
  SPI Module: Assumed to be in Phase 0, Polarity 0
  
  @author: Zoe Worrall
        zworrall@g.hmc.edu
  @vrsion: 3/16/2025

*/


module spi
    (
        clk,
        rstn,
        DATA_IN,
        TRIGGER,
        sdo,
        sdi,
        cs,
        sck
     );

    /**
    * Input Logic
    */
    input clk;
    input rstn;
    input [31:0] DATA_IN;
    input TRIGGER;
    output sdo;
    input sdi;
    output cs;
    output sck;

    /**
    * Internal Logic
    */
    logic [7:0] counter; // 8 bit counter, 0 to 32

    logic clk_i;
    logic rstn_i;
    logic [31:0] DATA_IN_i;
    logic TRIGGER_i;
    logic sdo_o;
    logic sdi_i;
    logic cs_o;

    // POSEDGE CLOCK TEST - Phase = 1, Polarity = 0 and 
    always @(negedge clk) begin
        if (~rstn) begin
            sdo_o <= 0;
            counter <= 0;
            cs_o <= 0;
        end 
        if (TRIGGER) begin // start the transmission
            sdo_o <= DATA_IN[31];
            counter <= 0;
            cs_o <= 1;
        end else if (cs & (counter < 31)) begin // increment the counter, output the data in the designated bit
            sdo_o <= DATA_IN[30 - counter];
            counter <= counter + 1'b1;
            cs_o <= 1;
        end else begin
            sdo_o <= 0; //freeze counter so that it doesn't overflow and restart the sweep
            counter <= 0; 
            cs_o <= 0;
        end
    end

    assign cs = cs_o; // chip select
    assign sdo = sdo_o; // serial data out
    assign sck = cs ? clk : 1'b0; // the clock is 0 if not transmitting; if it is, it sends out the clock

endmodule


module spi_tb();

    logic rstn;
    logic clk;

    logic [31:0] track_out;
    logic trig;
    logic sdo;
    logic sdi;
    logic cs; 
    logic sck;

    logic [31:0] transmitted;

    // test generation of 16 evenly spaced steps
    spi dut ( clk, rstn, track_out, trig, sdo, sdi, cs, sck);

    // generate testbench clock
    always begin 
        clk = 0; #5; clk = 1; #5;
    end

    // initialize
    initial begin
        rstn = 0; trig = 0; #20; rstn = 1; #20;

        track_out = 32'h80f0_f0f1; // 1
        trig = 1; #10; trig = 0;
        #100; // wait for the transmission to finish

	end

endmodule
