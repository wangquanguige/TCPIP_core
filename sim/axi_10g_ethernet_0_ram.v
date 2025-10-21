`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/06/24 20:57:48
// Design Name: 
// Module Name: axi_10g_ethernet_0_ram
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module axi_10g_ethernet_0_ram#(
  parameter ADDR_WIDTH = 9)
  (
  input  wire                          wr_clk,
  input  wire  [(ADDR_WIDTH-1):0]      wr_addr,
  input  wire  [67:0]                  data_in,
  input  wire                          wr_allow,

  input  wire                          rd_clk,
  input  wire                          rd_sreset,
  input  wire  [(ADDR_WIDTH-1):0]      rd_addr,
  output wire  [67:0]                  data_out,
  input  wire                          rd_allow
 );

  localparam RAM_DEPTH = 2 ** ADDR_WIDTH;
  (* ram_style = "block" *)
  reg          [67:0]                  ram [RAM_DEPTH-1:0];

  reg          [67:0]                  wr_data_pipe = 0;
  reg                                  wr_allow_pipe = 0;
  reg          [(ADDR_WIDTH-1):0]      wr_addr_pipe = 0;

  wire         [67:0]                  wr_data;
  reg          [67:0]                  rd_data;

  wire                                 rd_allow_int;

  assign wr_data[67:0]                 = data_in;

  assign data_out                      = rd_data[67:0];

  // Block RAM must be enabled for synchronous reset to work.
  assign rd_allow_int                  = (rd_allow | rd_sreset);

  // For clean simulation
  integer val;
  initial
  begin
    for (val = 0; val < RAM_DEPTH; val = val+1) begin
      ram[val] <= 64'd0;
    end
  end

//----------------------------------------------------------------------
 // Infer BRAMs and connect them
 // appropriately.
//--------------------------------------------------------------------//

  always @(posedge wr_clk)
   begin
      wr_data_pipe                     <= wr_data;
      wr_allow_pipe                    <= wr_allow;
      wr_addr_pipe                     <= wr_addr;
   end

  always @(posedge wr_clk)
   begin
     if (wr_allow_pipe) begin
       ram[wr_addr_pipe] <= wr_data_pipe;
     end
   end

  always @(posedge rd_clk)
   begin
     if (rd_allow_int) begin
       if (rd_sreset) begin
         rd_data <= 68'd0;
       end
       else begin
         rd_data <= ram[rd_addr];
       end
     end
   end

endmodule
