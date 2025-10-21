`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/12 20:22:10
// Design Name: 
// Module Name: axi_10g_ethernet_0_arp_request
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


module axi_10g_ethernet_0_arp_request #(
    parameter           BOARD_MAC          =          48'h02_00_c0_a8_0a_0a           ,
    parameter           BOARD_IP           =          {8'd192,8'd168,8'd2,8'd20}      
)
(
    input                               aclk                     ,
    input                               areset                   ,

    input               [31:0]          arp_request_ip           ,       // tcp层发送报文的ip
    input                               tx_tcp_en                ,       // tcp发送报文使能信号
    output      reg                     tx_tcp_tready            ,       // tcp允许发送报文
    input                               tx_tcp_done              ,

    input                               arp_rx_type              ,       // 值为1时表示接收arp应答报文，填list表
    input               [47:0]          arp_src_mac              ,
    input               [31:0]          arp_src_ip               ,

    input                               arp_request_tready       ,
    output      reg                     arp_request_en           ,
    output      reg                     arp_request_done         ,

    output      reg     [63:0]          tx_axis_tdata            ,
    output      reg     [7:0]           tx_axis_tkeep            ,
    output      reg                     tx_axis_tvalid           ,
    output      reg                     tx_axis_tlast            
);

localparam IDLE             =       0,
           ARP_HEAD         =       1,
           OP               =       2,
           MAC_IP           =       3,
           DES_MAC          =       4,
           DES_IP           =       5,
           PAD_ONE          =       6,
           PAD_TWO          =       7; 

reg         [ 3:0]          state                              ;
reg         [31:0]          arp_request_ip_reg                 ;

reg         [47:0]          mac_list            [9:0]          ;
reg         [31:0]          ip_list             [9:0]          ;
reg         list_index      ;                                    // ip-mac缓存表添加位置索引

reg         exist_flag      ;   
integer     index           ;

always @(posedge aclk) begin
    if (areset) begin
        list_index          <=          0           ;
        exist_flag          <=          0           ;
    end
    else begin
        if (tx_tcp_en) begin
            arp_request_ip_reg      <=      arp_request_ip          ;
        end
    end
end

always @(posedge aclk) begin
    if (arp_rx_type == 1) begin                                                 // 接收arp应答报文，添加进list
        mac_list    [list_index]        <=          arp_src_mac         ;
        ip_list     [list_index]        <=          arp_src_ip          ;
        list_index          <=          (list_index +   1)  %   10      ;
    end
end

always @(posedge aclk) begin
    if (tx_tcp_en == 1) begin
        for (index = 0; index < 10; index = index + 1) begin
            if (ip_list[index] == arp_request_ip) begin
                exist_flag          <=          1           ;
            end
        end
        if (exist_flag == 1) begin
            
            tx_tcp_tready           <=          1           ;
        end
        else begin
            arp_request_en          <=          1           ;
            exist_flag              <=          0           ;
        end
    end

    if (tx_tcp_done == 1) begin
        tx_tcp_tready       <=          0           ;
    end 
end

always @(posedge aclk) begin
    if (areset) begin
        arp_request_done    <=          0           ;
        arp_request_en      <=          0           ;
        state               <=          IDLE        ;
    end
end

always @(posedge aclk) begin
    if (arp_request_tready == 1) begin
        arp_request_en          <=          0           ;

        case (state)
            IDLE : begin
                tx_axis_tdata           <=          {BOARD_MAC[39:32],   BOARD_MAC[47:40],    48'hff_ff_ff_ff_ff_ff}   ;
                tx_axis_tkeep           <=          8'b1111_1111                                                    ;
                tx_axis_tvalid          <=          1                                                               ;
                tx_axis_tlast           <=          0                                                               ;

                state                   <=          ARP_HEAD                                                        ;
            end 
            ARP_HEAD : begin
                tx_axis_tdata           <=          {8'h01, 8'h00, 8'h06, 8'h08, BOARD_MAC[7:0], BOARD_MAC[15:8], BOARD_MAC[23:16], BOARD_MAC[31:24]}    ;
                tx_axis_tkeep           <=          8'b1111_1111                                                    ;
                tx_axis_tvalid          <=          1                                                               ;
                tx_axis_tlast           <=          0                                                               ;

                state                   <=          OP                                                              ;
            end
            OP : begin
                tx_axis_tdata           <=          {BOARD_MAC[39:32], BOARD_MAC[47:40], 8'h01, 8'h00, 8'h04, 8'h06, 8'h00, 8'h08}    ;
                tx_axis_tkeep           <=          8'b1111_1111                                                    ;
                tx_axis_tvalid          <=          1                                                               ;
                tx_axis_tlast           <=          0                                                               ;

                state                   <=          MAC_IP                                                          ;
            end
            MAC_IP : begin
                tx_axis_tdata           <=          {BOARD_IP[7:0], BOARD_IP[15:8], BOARD_IP[23:16], BOARD_IP[31:24], BOARD_MAC[7:0], BOARD_MAC[15:8], BOARD_MAC[23:16], BOARD_MAC[31:24]}    ;
                tx_axis_tkeep           <=          8'b1111_1111                                                    ;
                tx_axis_tvalid          <=          1                                                               ;
                tx_axis_tlast           <=          0                                                               ;

                state                   <=          DES_MAC                                                         ;
            end
            DES_MAC : begin
                tx_axis_tdata           <=          {arp_request_ip_reg[15:0],  48'h0}                              ;
                tx_axis_tkeep           <=          8'b1111_1111                                                    ;
                tx_axis_tvalid          <=          1                                                               ;
                tx_axis_tlast           <=          0                                                               ;

                state                   <=          DES_IP                                                          ;
            end
            DES_IP : begin
                tx_axis_tdata           <=          {48'b0,     arp_request_ip_reg[31:16]}                          ;
                tx_axis_tkeep           <=          8'b1111_1111                                                    ;
                tx_axis_tvalid          <=          1                                                               ;
                tx_axis_tlast           <=          0                                                               ;

                state                   <=          PAD_ONE                                                         ;
            end
            PAD_ONE : begin
                tx_axis_tdata           <=          64'b0                                                           ;
                tx_axis_tkeep           <=          8'b1111_1111                                                    ;
                tx_axis_tvalid          <=          1                                                               ;
                tx_axis_tlast           <=          0                                                               ;

                state                   <=          PAD_TWO                                                         ;
            end
            PAD_TWO : begin
                tx_axis_tdata           <=          64'b0                                                           ;
                tx_axis_tkeep           <=          8'b0000_1111                                                    ;
                tx_axis_tvalid          <=          1                                                               ;
                tx_axis_tlast           <=          1                                                               ;

                state                   <=          IDLE                                                            ;
                arp_request_done        <=          1                                                               ;
            end
        endcase
    end 
    else begin
        arp_request_done          <=          0           ;
    end
end

endmodule
