`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/12 20:02:06
// Design Name: 
// Module Name: axi_10g_ethernet_0_arp_parser
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


`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/12/30 15:30:03
// Design Name: 
// Module Name: axi_10g_ethernet_0_arp_parser
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


module axi_10g_ethernet_0_arp_parser #(
    parameter           BOARD_MAC          =          48'h02_00_c0_a8_0a_0a           ,
    parameter           BOARD_IP           =          {8'd192,8'd168,8'd2,8'd20}      ,

    parameter             show_message_type  =          1               
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

    // 解析arp报文输出解析数据
    output  reg                     tx_arp_en                         ,   // 发送arp应答报文使能信号     
    output  reg                     arp_rx_type                       ,   // 接收arp报文类型  0 ：请求   1 ：应答 
    output  reg    [47:0]           arp_src_mac                       ,
    output  reg    [31:0]           arp_src_ip                          
);

localparam ARP_TYPE         =       16'h0806;
localparam IDLE             =       0,
           ARP_HEAD         =       1,
           OP               =       2,
           MAC_IP           =       3,
           DATA             =       4;

reg         [2:0]       state;
reg         [47:0]      src_mac;
reg         [47:0]      des_mac;
reg         [31:0]      src_ip;
reg         [31:0]      des_ip;
reg         [15:0]      rx_type;
reg         [15:0]      op_code;

assign          rx_axis_tready           =           1           ;

always @(posedge aclk) begin
    if (areset) begin
        state <= IDLE;
    end
    else begin
        case (state)
            IDLE : begin
                if (rx_axis_tvalid & rx_axis_tkeep != 0) begin
                    des_mac             <=      rx_axis_tdata[47:0]         ;
                    src_mac[15:0]       <=      rx_axis_tdata[63:48]        ;

                    state               <=      ARP_HEAD                    ;
                end
                else begin
                    state               <=      IDLE                        ;
                end
            end
            ARP_HEAD : begin
                if (rx_axis_tvalid & rx_axis_tkeep != 0) begin
                    src_mac[47:16]      <=      rx_axis_tdata[31:0]         ;
                    rx_type             <=      rx_axis_tdata[47:32]        ;
                    
                    state               <=      OP                          ;
                end
                else begin
                    state               <=      IDLE                        ;
                end
            end
            OP : begin
                if (rx_axis_tvalid & rx_axis_tkeep != 0) begin
                    op_code             <=      rx_axis_tdata[47:32]        ;

                    state               <=      MAC_IP;
                end
                else begin
                    state               <=      IDLE                        ;
                end
            end
            MAC_IP : begin
                if (rx_axis_tvalid & rx_axis_tkeep != 0) begin
                    src_ip              <=      rx_axis_tdata[63:32]        ;

                    state               <=      DATA                        ;
                end
                else begin
                    state               <=      IDLE                        ;
                end
            end
            DATA : begin
                if (rx_axis_tvalid & rx_axis_tkeep != 0 & rx_axis_tlast) begin
                    state               <=      IDLE                        ;
                end
            end
        endcase
    end
end

always @(posedge aclk) begin
    if (areset) begin
        arp_src_mac             <=                  0                   ;
        arp_src_ip              <=                  0                   ;
        tx_arp_en               <=                  0                   ;
        arp_rx_type             <=                  0                   ;
    end
    else if (state == DATA & rx_axis_tlast) begin
        if ({des_mac[7:0], des_mac[15:8], des_mac[23:16], des_mac[31:24], des_mac[39:32], des_mac[47:40]} != BOARD_MAC  & des_mac != 48'hff_ff_ff_ff_ff_ff) begin
            arp_src_mac             <=                  0                   ;
            arp_src_ip              <=                  0                   ;
            tx_arp_en               <=                  0                   ;
            arp_rx_type             <=                  0                   ;
        end
        else if ({rx_type[7:0], rx_type[15:8]} != ARP_TYPE) begin
            arp_src_mac             <=                  0                   ;
            arp_src_ip              <=                  0                   ;
            tx_arp_en               <=                  0                   ;
            arp_rx_type             <=                  0                   ;
        end
        else begin
            if ({op_code[7:0], op_code[15:8]} == 16'h00_01) begin
                arp_src_mac             <=                  src_mac             ;
                arp_src_ip              <=                  src_ip              ;
                tx_arp_en               <=                  1                   ;
                arp_rx_type             <=                  0                   ;

                if (show_message_type == 1) begin
                    $display("Received message is arp_request.");
                end
            end
            else begin
                arp_src_mac             <=                  src_mac             ;
                arp_src_ip              <=                  src_ip              ;
                tx_arp_en               <=                  0                   ;
                arp_rx_type             <=                  1                   ;

                if (show_message_type == 1) begin
                    $display("Received message is arp_reply.");
                end
            end
        end
    end
    else begin
        arp_src_mac             <=                  0                   ;
        arp_src_ip              <=                  0                   ;
        tx_arp_en               <=                  0                   ;
        arp_rx_type             <=                  0                   ;
    end
end

endmodule
