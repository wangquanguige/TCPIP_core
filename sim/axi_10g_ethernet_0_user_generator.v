`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/04/14 17:39:40
// Design Name: 
// Module Name: axi_10g_ethernet_0_user_generator
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


module axi_10g_ethernet_0_user_generator(
        input                    s_aclk,                // input wire s_aclk
        input                    s_areset,              // input wire s_areset
     
        output reg               s_axis_tvalid,  // input wire s_axis_tvalid
        input                    s_axis_tready,  // output wire s_axis_tready
        output reg  [63:0]       s_axis_tdata,  // input wire [63 : 0] s_axis_tdata
        output reg  [7:0]        s_axis_tkeep,

        input                    tx_packet_start_signal,

        input       [3:0]        tcp_state_out
    );

    reg [63:0] state    ;

    always @(posedge s_aclk) begin
        if (s_areset) begin
            s_axis_tdata        <=      64'b0;
            s_axis_tkeep        <=      8'b0000_0000;
            s_axis_tvalid       <=      0;

            state               <=      0       ;
        end
        else if(tcp_state_out == 4'b0011) begin
            if (s_axis_tready == 1 & tx_packet_start_signal == 1) begin
                state            <=      state + 1;

                s_axis_tdata     <=      state;
                s_axis_tkeep     <=      8'b1111_1111;

                s_axis_tvalid    <=      1;

                
                /*s_axis_tdata     <=      0;
                s_axis_tkeep     <=      0;

                s_axis_tvalid    <=      0;*/
                
            end
            else begin
                s_axis_tdata     <=      0;
                s_axis_tkeep     <=      0;

                s_axis_tvalid    <=      0;
            end
            
            /*if (state <= 64'd100000) begin
                s_axis_tdata     =      state;
                s_axis_tkeep     =      8'b1111_1111;
                s_axis_tvalid    =      1;
                state            =      state + 1;
            end
            else begin
                s_axis_tdata     =      state;
                s_axis_tkeep     =      8'b0000_0000;
                s_axis_tvalid    =      0;
            end*/

            /*case(state)
                4'b0000 : begin
                    s_axis_tdata    <=      64'h11_11_11_11_11_11_11_11;
                    s_axis_tkeep    <=      8'b1111_1111;
                    s_axis_tvalid   <=      1;

                    state           <=      4'b0001;
                end
                4'b0001 : begin
                    s_axis_tdata    <=      64'h11_11_11_11_11_11_11_22;
                    s_axis_tkeep    <=      8'b1111_1111;
                    s_axis_tvalid   <=      1;

                    state           <=      4'b0010;
                end
                4'b0010 : begin
                    s_axis_tdata    <=      64'h11_11_11_11_11_11_11_33;
                    s_axis_tkeep    <=      8'b1111_1111;
                    s_axis_tvalid   <=      1;

                    state           <=      4'b0011;
                end
                4'b0011 : begin
                    s_axis_tdata    <=      64'h11_11_11_11_11_11_11_44;
                    s_axis_tkeep    <=      8'b1111_1111;
                    s_axis_tvalid   <=      1;

                    state           <=      4'b0100;
                end
                4'b0100 : begin
                    s_axis_tdata    <=      64'h11_11_11_11_11_11_11_55;
                    s_axis_tkeep    <=      8'b1111_1111;
                    s_axis_tvalid   <=      1;

                    state           <=      4'b0101;
                end
                4'b0101 : begin
                    s_axis_tdata    <=      64'h11_11_11_11_11_11_11_66;
                    s_axis_tkeep    <=      8'b1111_1111;
                    s_axis_tvalid   <=      1;

                    state           <=      4'b0000;
                end
            endcase*/
        end
    end

endmodule
