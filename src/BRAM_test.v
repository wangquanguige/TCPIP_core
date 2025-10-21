`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/09/26 15:08:57
// Design Name: 
// Module Name: BRAM_test
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

module BRAM_test(clk,ena,wea,addra,addrb,dina,douta);
input clk,ena,wea;
input[13:0] addra;
input[13:0] addrb;
input[63:0] dina;
output[63:0] douta;

blk_mem_gen_1 bram_test(
        .clka(clk),    // input wire clka
        .ena(1),      // input wire ena
        .wea(1),      // input wire [0 : 0] wea
        .addra(addra),  // input wire [13 : 0] addra
        .dina(dina),    // input wire [104 : 0] dina

        .clkb(clk),    // input wire clkb
        .enb(1),      // input wire enb
        .addrb(addrb),  // input wire [13 : 0] addrb
        .doutb(douta)  // output wire [104 : 0] doutb
    );

endmodule

