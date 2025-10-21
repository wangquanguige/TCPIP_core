`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/14 17:05:20
// Design Name: 
// Module Name: axi_10g_ethernet_0_icmp_block
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


module axi_10g_ethernet_0_icmp_block #(
        parameter           BOARD_MAC          =          48'h02_00_c0_a8_0a_0a           ,
        parameter           BOARD_IP           =          {8'd192,8'd168,8'd2,8'd20}      
    )
    (
        input                           aclk                              ,
        input                           areset                            ,

        // 接收数据
        input   [63:0]                  rx_axis_tdata                     ,
        input   [ 7:0]                  rx_axis_tkeep                     ,
        input                           rx_axis_tvalid                    ,
        input                           rx_axis_tlast                     ,
        output                          rx_axis_tready                    ,

        output              [63:0]      icmp_reply_tdata                  ,
        output              [ 7:0]      icmp_reply_tkeep                  ,
        output                          icmp_reply_tvalid                 ,
        output                          icmp_reply_tlast                  ,

        input                           icmp_reply_tready                 ,
        output                          icmp_reply_en                     ,
        output                          icmp_reply_done
    );

    wire                     tx_icmp_en                        ;   // 发送icmp应答报文使能信号 
    wire    [47:0]           icmp_src_mac                      ;
    wire    [31:0]           icmp_src_ip                       ;
    wire    [15:0]           icmp_src_identifier               ;
    wire    [15:0]           icmp_src_sequence_number          ;
    wire    [255:0]          icmp_src_data                     ;

    axi_10g_ethernet_0_icmp_parser #(
        .BOARD_MAC(BOARD_MAC),
        .BOARD_IP (BOARD_IP)           
    ) icmp_parser
    (
        .aclk                    (aclk)                      ,
        .areset                  (areset)                    ,
        
        .rx_axis_tdata           (rx_axis_tdata)             ,
        .rx_axis_tkeep           (rx_axis_tkeep)             ,
        .rx_axis_tvalid          (rx_axis_tvalid)            ,
        .rx_axis_tlast           (rx_axis_tlast)             ,
        .rx_axis_tready          (rx_axis_tready)            ,
        
        .tx_icmp_en              (tx_icmp_en)                ,
        .icmp_src_mac            (icmp_src_mac)              ,
        .icmp_src_ip             (icmp_src_ip)               ,
        .icmp_src_identifier     (icmp_src_identifier)       ,
        .icmp_src_sequence_number(icmp_src_sequence_number)  ,
        .icmp_src_data           (icmp_src_data)
    );

    axi_10g_ethernet_0_icmp_generator #(
        .BOARD_MAC(BOARD_MAC),
        .BOARD_IP (BOARD_IP)
    )
    (
        .aclk                      (aclk)                    ,          
        .areset                    (areset)                  ,       

        .tx_icmp_en                (tx_icmp_en)              ,
        .icmp_src_mac              (icmp_src_mac)            ,
        .icmp_src_ip               (icmp_src_ip)             ,
        .icmp_src_identifier       (icmp_src_identifier)     ,
        .icmp_src_sequence_number  (icmp_src_sequence_number),
        .icmp_src_data             (icmp_src_data)           ,

        .tx_axis_tdata             (icmp_reply_tdata)        ,
        .tx_axis_tkeep             (icmp_reply_tkeep)        ,
        .tx_axis_tvalid            (icmp_reply_tvalid)       ,
        .tx_axis_tlast             (icmp_reply_tlast)        ,

        .icmp_reply_tready         (icmp_reply_tready)       ,
        .icmp_reply_en             (icmp_reply_en)           ,
        .icmp_reply_done           (icmp_reply_done)
    );

endmodule
