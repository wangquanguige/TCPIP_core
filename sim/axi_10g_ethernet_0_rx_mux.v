`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/09/26 17:16:54
// Design Name: 
// Module Name: axi_10g_ethernet_0_rx_mux
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


module axi_10g_ethernet_0_rx_mux(
        input                       aclk               ,
        input                       areset             ,

        output   reg [63:0]         rx_user_tdata      ,
        output   reg [7:0]          rx_user_tkeep      ,
        input                       rx_user_tready     ,
        output   reg                rx_user_tvalid     ,

        input        [63:0]         rx_user_ram_tdata     ,
        input        [7:0]          rx_user_ram_tkeep     ,
        input                       rx_user_ram_tvalid    ,

        input        [63:0]         rx_user_fifo_tdata     ,
        input        [7:0]          rx_user_fifo_tkeep     ,
        input                       rx_user_fifo_tvalid     
    );

    always @(rx_user_ram_tvalid or rx_user_fifo_tvalid) begin
        if (rx_user_tready) begin
            if (rx_user_ram_tvalid) begin
                rx_user_tdata       <=  rx_user_ram_tdata;
                rx_user_tkeep       <=  rx_user_ram_tkeep;
                rx_user_tvalid      <=  rx_user_ram_tvalid;
            end
            else if(rx_user_fifo_tvalid) begin
                rx_user_tdata       <=  rx_user_fifo_tdata;
                rx_user_tkeep       <=  rx_user_fifo_tkeep;
                rx_user_tvalid      <=  rx_user_fifo_tvalid;
            end
            else begin
                rx_user_tdata       <=  0;
                rx_user_tkeep       <=  0;
                rx_user_tvalid      <=  0;
            end
        end 
    end

endmodule
