`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/14 17:28:21
// Design Name: 
// Module Name: axi_10g_ethernet_0_icmp_generator
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


module axi_10g_ethernet_0_icmp_generator #(
        parameter             BOARD_MAC          =          48'h02_00_c0_a8_0a_0a,
        parameter             BOARD_IP           =          {8'd192,8'd168,8'd2,8'd20}
    )
    (
        input                           aclk                                ,          
        input                           areset                              ,       

        input                           tx_icmp_en                          ,
        input               [47:0]      icmp_src_mac                        ,
        input               [31:0]      icmp_src_ip                         ,
        input               [15:0]      icmp_src_identifier                 ,
        input               [15:0]      icmp_src_sequence_number            ,
        input               [255:0]     icmp_src_data                       ,

        output              [63:0]      tx_axis_tdata                       ,
        output              [ 7:0]      tx_axis_tkeep                       ,
        output                          tx_axis_tvalid                      ,
        output                          tx_axis_tlast                       ,

        input                           icmp_reply_tready                   ,
        output                          icmp_reply_en                       ,
        output                          icmp_reply_done
    );

    axi_10g_ethernet_0_icmp_reply #(
        .BOARD_MAC(BOARD_MAC),
        .BOARD_IP(BOARD_IP)
    ) icmp_reply
    (
        .aclk                       (aclk),          
        .areset                     (areset),       

        .tx_icmp_en                 (tx_icmp_en),
        .icmp_src_mac               (icmp_src_mac),
        .icmp_src_ip                (icmp_src_ip),
        .icmp_src_identifier        (icmp_src_identifier),
        .icmp_src_sequence_number   (icmp_src_sequence_number),
        .icmp_src_data              (icmp_src_data),

        .tx_axis_tdata              (tx_axis_tdata),
        .tx_axis_tkeep              (tx_axis_tkeep),
        .tx_axis_tvalid             (tx_axis_tvalid),
        .tx_axis_tlast              (tx_axis_tlast),

        .icmp_reply_tready          (icmp_reply_tready),
        .icmp_reply_en              (icmp_reply_en),
        .icmp_reply_done            (icmp_reply_done)
    );
endmodule
