`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/06/17 17:21:08
// Design Name: 
// Module Name: axi_10g_ethernet_0_checksum
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


module axi_10g_ethernet_0_checksum #(
        parameter             TCP_DATA_LENGTH    =          40                    // 默认是8B倍数          
    )
    (
        input                    s_aclk,                // input wire s_aclk
        input                    s_areset,              // input wire s_areset
     
        input                    s_axis_tvalid, 
        input                    s_axis_tready,
        input       [63:0]       s_axis_tdata,  
        input       [7:0]        s_axis_tkeep,

        output  reg [15:0]       din,                  // input wire [15 : 0] din
        output  reg              wr_en,
        input                    full
    );

// size 必须是偶数
task calc_checksum;
    input   [3 :0] size;
    input   [63:0] data_in;
    inout   [31:0] checksum;
    integer       I;
    reg    [15:0]  data [0:3];

    begin
        data[0] = data_in[15:0];
        data[1] = data_in[31:16];
        data[2] = data_in[47:32];
        data[3] = data_in[63:48];

        for (I = 0; I < size/2; I = I + 1)
        begin
            checksum = checksum + {data[I][7:0], data[I][15:8]};
        end
    end
endtask

    (* mark_debug = "true" *)reg [15:0] now_length;
    (* mark_debug = "true" *)reg [31:0] tcp_checksum;

    (* mark_debug = "true" *)reg [31:0] din_reg;

    (* mark_debug = "true" *)reg [3:0] state;
/*
    always @(posedge s_aclk) begin
        if (s_areset) begin
            now_length  <=  0;
            tcp_checksum    <=  0;
            wr_en       <=  0;
        end
        else begin
            if (s_axis_tvalid) begin
                now_length <= now_length + 8;
                calc_checksum(8, s_axis_tdata, tcp_checksum);   // 默认存储data 8B有效
            end

            if (now_length == TCP_DATA_LENGTH & full == 0) begin
                tcp_checksum = tcp_checksum[31:16] + tcp_checksum[15:0];
                tcp_checksum = tcp_checksum[31:16] + tcp_checksum[15:0];

                wr_en   =  1;
                din     =  tcp_checksum[15:0];
                tcp_checksum    =   0;
                now_length  =   0;
            end
            else begin
                wr_en   <=  0;
            end
        end
    end
*/
    always @(posedge s_aclk) begin
        if (s_areset) begin
            now_length  <=  0;
            tcp_checksum    <=  0;
            wr_en       <=  0;
            state       <= 0;
        end
        else begin
            if (s_axis_tvalid && s_axis_tready) begin
                now_length <= now_length + 8;
                calc_checksum(8, s_axis_tdata, tcp_checksum);   // 默认存储data 8B有效
            end

            if (s_axis_tvalid && s_axis_tready && now_length + 8 == TCP_DATA_LENGTH & full == 0) begin
                din_reg <= tcp_checksum;

                tcp_checksum <=   0;
                now_length  <=   0;
                state       <=   4'b0001;
            end
            else begin
                wr_en   <=  0;
            end

            case(state)
                4'b0000 : begin
                    wr_en   <=  0;
                end
                4'b0001 : begin
                    din_reg <= din_reg[31:16] + din_reg[15:0];
                    state   <=  4'b0010;
                end
                4'b0010 : begin
                    din_reg <= din_reg[31:16] + din_reg[15:0];
                    state   <=  4'b0011;
                end
                4'b0011 : begin
                    wr_en   <=  1;
                    din     <=  din_reg[15:0];
                    state   <= 4'b0000;
                end
            endcase
        end
    end
endmodule
