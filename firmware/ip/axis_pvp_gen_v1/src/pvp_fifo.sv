module pvp_fifo (
              input logic clk, reset,
              input logic rd_en, wr_en, 

              input logic [23:0] write_data,
              output logic [23:0] read_data,

              output logic full, empty);

  parameter width = 24;
  parameter depth = 256;

  logic [depth-1:0][width-1:0] mem;
  logic [7:0] write_ptr, read_ptr;



  assign empty = (read_ptr == write_ptr);
  assign full = ((read_ptr == 0) & (write_ptr == depth-1));
  assign read_data = mem[read_ptr[depth-1:0]];


  always @(posedge clk) begin
    if (reset) begin
      read_ptr <= 0;
      write_ptr <= 0;
    end

    else begin
     if (~empty & rd_en) begin
        read_ptr <= read_ptr + 1;
      end
    end

    if (~full & wr_en) begin
      write_ptr <= write_ptr +1;
      mem[write_ptr[depth-1:0]] <= write_data;
    end
  end
end

%% Took out the byte-by-byte dequeing 

%% Should be able to use this for both FIFO 1 and FIFO 2 blocks
%% for FIFO 1 block: read_en connected to full of Fifo block
%% for FIFO 2 block: read_en and write_en connected to empty of Iter block
%% memory = 24x256