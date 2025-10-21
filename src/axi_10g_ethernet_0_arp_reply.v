`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/12 20:15:49
// Design Name: 
// Module Name: axi_10g_ethernet_0_arp_reply
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


// 模块负责生成arp响应报文
module axi_10g_ethernet_0_arp_reply #(
    parameter           BOARD_MAC          =          48'h02_00_c0_a8_0a_0a           ,
    parameter           BOARD_IP           =          {8'd192,8'd168,8'd2,8'd20}      
)
(
    input                               aclk                    ,
    input                               areset                  ,

    input                               tx_arp_en               ,          // 需要发送arp响应报文
    input               [47:0]          arp_src_mac             ,
    input               [31:0]          arp_src_ip              ,

    output      reg     [63:0]          tx_axis_tdata           ,
    output      reg     [7:0]           tx_axis_tkeep           ,
    output      reg                     tx_axis_tvalid          ,
    output      reg                     tx_axis_tlast           ,

    input                               arp_reply_tready        ,
    output      reg                     arp_reply_en            ,
    output      reg                     arp_reply_done
);

localparam IDLE             =       0,
           ARP_HEAD         =       1,
           OP               =       2,
           MAC_IP           =       3,
           DES_MAC          =       4,
           DES_IP           =       5,
           PAD_ONE          =       6,
           PAD_TWO          =       7; 

reg         [47:0]          arp_src_mac_reg             ;
reg         [31:0]          arp_src_ip_reg              ;

reg         [ 3:0]          state       ;

always @(posedge aclk) begin
    if (areset) begin
        arp_src_mac_reg             <=          0                       ;
        arp_src_ip_reg              <=          0                       ;
    end
    else begin
        if (tx_arp_en) begin
            arp_src_mac_reg             <=          arp_src_mac             ;
            arp_src_ip_reg              <=          arp_src_ip              ;
        end
    end
end

always @(posedge aclk) begin
    if (areset) begin
        state                       <=          IDLE                    ;
        arp_reply_en                <=          0                       ;
    end 

    if (tx_arp_en == 1) begin
        arp_reply_en                <=          1                       ;
    end

    if (arp_reply_tready == 1 & arp_reply_done != 1) begin
        arp_reply_en                <=          0                       ;

        case (state)
            IDLE : begin
                tx_axis_tdata           <=          {BOARD_MAC[39:32],   BOARD_MAC[47:40],    arp_src_mac_reg}         ;
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
                tx_axis_tdata           <=          {BOARD_MAC[39:32], BOARD_MAC[47:40], 8'h02, 8'h00, 8'h04, 8'h06, 8'h00, 8'h08}    ;
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
                tx_axis_tdata           <=          {arp_src_ip_reg[15:0],  arp_src_mac_reg}                        ;
                tx_axis_tkeep           <=          8'b1111_1111                                                    ;
                tx_axis_tvalid          <=          1                                                               ;
                tx_axis_tlast           <=          0                                                               ;

                state                   <=          DES_IP                                                          ;
            end
            DES_IP : begin
                tx_axis_tdata           <=          {48'b0,     arp_src_ip_reg[31:16]}                              ;
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
                arp_reply_done          <=          1                                                               ;
            end
        endcase
    end
    else begin
        tx_axis_tdata           <=          0                                                               ;
        tx_axis_tkeep           <=          8'h0                                                            ;
        tx_axis_tvalid          <=          0                                                               ;
        tx_axis_tlast           <=          0                                                               ;

        arp_reply_done          <=          0                                                               ;
    end
end

endmodule
