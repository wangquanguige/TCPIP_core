`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/12 20:03:28
// Design Name: 
// Module Name: axi_10g_ethernet_0_arp_generator
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


module axi_10g_ethernet_0_arp_generator #(
    parameter           BOARD_MAC          =          48'h02_00_c0_a8_0a_0a           ,
    parameter           BOARD_IP           =          {8'd192,8'd168,8'd2,8'd20}      ,
    parameter           show_output_block           =           1           
)
(
    input                               aclk                    ,
    input                               areset                  ,

    // 接收parser模块解析数据
    input                               tx_arp_en               ,
    input                               arp_rx_type             ,
    input       [47:0]                  arp_src_mac             ,
    input       [31:0]                  arp_src_ip              ,

    // arp_reply输出数据
    output      [63:0]                  arp_reply_tdata         ,
    output      [7:0]                   arp_reply_tkeep         ,
    output                              arp_reply_tvalid        ,
    output                              arp_reply_tlast         ,
    input                               arp_reply_tready        ,
    output                              arp_reply_en            ,
    output                              arp_reply_done          ,

    // arp_request输出数据
    output      [63:0]                  arp_request_tdata       ,
    output      [7:0]                   arp_request_tkeep       ,
    output                              arp_request_tvalid      ,
    output                              arp_request_tlast       ,
    input                               arp_request_tready      ,
    output                              arp_request_en          ,
    output                              arp_request_done        ,

    // 上层发送报文时查询ip地址映射接口
    input       [31:0]                  arp_request_ip          ,
    input                               tx_tcp_en               ,
    output                              tx_tcp_tready           ,
    input                               tx_tcp_done             
); 

// 模块负责生成arp响应报文
axi_10g_ethernet_0_arp_reply #(
    .BOARD_MAC(BOARD_MAC),
    .BOARD_IP(BOARD_IP)
)
arp_reply ( 
    .aclk                            (aclk)                     ,
    .areset                          (areset)                   ,

    .tx_arp_en                       (tx_arp_en)                ,
    .arp_src_mac                     (arp_src_mac)              ,
    .arp_src_ip                      (arp_src_ip)               ,

    .tx_axis_tdata                   (arp_reply_tdata)          ,
    .tx_axis_tkeep                   (arp_reply_tkeep)          ,
    .tx_axis_tvalid                  (arp_reply_tvalid)         ,
    .tx_axis_tlast                   (arp_reply_tlast)          ,

    .arp_reply_tready                (arp_reply_tready)         ,       // 控制arp_reply发送报文
    .arp_reply_en                    (arp_reply_en)             ,
    .arp_reply_done                  (arp_reply_done)
);


// 模块负责生成arp请求报文，同时内部存储ip-mac表
axi_10g_ethernet_0_arp_request arp_request ( 
    .aclk                            (aclk)                     ,
    .areset                          (areset)                   ,

    .arp_request_ip                  (arp_request_ip)           ,       // tcp层发送报文的ip
    .tx_tcp_en                       (tx_tcp_en)                ,       // tcp发送报文使能信号
    .tx_tcp_tready                   (tx_tcp_tready)            ,       // tcp允许发送报文
    .tx_tcp_done                     (tx_tcp_done)              ,

    .arp_rx_type                     (arp_rx_type)              ,       // 值为1时表示接收arp应答报文，填list表
    .arp_src_mac                     (arp_src_mac)              ,
    .arp_src_ip                      (arp_src_ip)               ,

    .arp_request_tready              (arp_request_tready)       ,
    .arp_request_en                  (arp_request_en)           ,
    .arp_request_done                (arp_request_done)         ,

    .tx_axis_tdata                   (arp_request_tdata)        ,
    .tx_axis_tkeep                   (arp_request_tkeep)        ,
    .tx_axis_tvalid                  (arp_request_tvalid)       ,
    .tx_axis_tlast                   (arp_request_tlast)        
);

endmodule
