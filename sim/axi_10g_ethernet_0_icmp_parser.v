`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/14 17:05:52
// Design Name: 
// Module Name: axi_10g_ethernet_0_icmp_parser
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


module axi_10g_ethernet_0_icmp_parser #(
    parameter             BOARD_MAC          =          48'h02_00_c0_a8_0a_0a           ,
    parameter             BOARD_IP           =          {8'd192,8'd168,8'd2,8'd20}      ,

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

    // 解析icmp报文输出解析数据
    output  reg                     tx_icmp_en                        ,   // 发送icmp应答报文使能信号 
    output  reg    [47:0]           icmp_src_mac                      ,
    output  reg    [31:0]           icmp_src_ip                       ,
    output  reg    [15:0]           icmp_src_identifier               ,
    output  reg    [15:0]           icmp_src_sequence_number          ,
    output  reg    [255:0]          icmp_src_data
);

localparam ICMP_TYPE        =       16'h0800;
localparam IDLE             =       0,
           MAC_HEAD         =       1,
           IP_HEAD          =       2,
           IP_HEAD_SRC_IP   =       3,
           ICMP_HEAD        =       4,
           DATA1            =       5,
           DATA2            =       6,
           DATA3            =       7,
           DATA4            =       8,
           DATA5            =       9,
           HANDLE           =       10;

reg         [3:0]       state;
reg         [47:0]      src_mac;
reg         [47:0]      des_mac;
reg         [31:0]      src_ip;
reg         [31:0]      des_ip;
reg         [15:0]      rx_type;
reg         [15:0]      op_code;
reg         [15:0]      src_identifier;
reg         [15:0]      src_sequence_number;
reg         [255:0]     src_data;

reg                     rx_axis_tlast_reg;

assign          rx_axis_tready           =           1           ;

always @(posedge aclk) begin
    rx_axis_tlast_reg               <=                  rx_axis_tlast           ;
end

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

                    state               <=      MAC_HEAD                    ;
                end
                else begin
                    state               <=      IDLE                        ;
                end     
            end
            MAC_HEAD : begin
                if (rx_axis_tvalid & rx_axis_tkeep != 0) begin
                    src_mac[47:16]      <=      rx_axis_tdata[31:0]         ;
                    rx_type             <=      rx_axis_tdata[47:32]        ;
                    
                    state               <=      IP_HEAD                     ;
                end
                else begin
                    state               <=      IDLE                        ;
                end
            end
            IP_HEAD : begin
                if (rx_axis_tvalid & rx_axis_tkeep != 0) begin
                    state               <=      IP_HEAD_SRC_IP;
                end
                else begin
                    state               <=      IDLE                        ;
                end 
            end
            IP_HEAD_SRC_IP : begin
                if (rx_axis_tvalid & rx_axis_tkeep != 0) begin
                    src_ip              <=      rx_axis_tdata[47:16]        ;
                    des_ip[15:0]        <=      rx_axis_tdata[63:48]        ;

                    state               <=      ICMP_HEAD                   ;
                end
                else begin
                    state               <=      IDLE                        ;
                end 
            end
            ICMP_HEAD : begin
                if (rx_axis_tvalid & rx_axis_tkeep != 0) begin
                    des_ip[31:16]       <=      rx_axis_tdata[15:0]         ;
                    op_code             <=      rx_axis_tdata[31:16]        ;
                    src_identifier      <=      rx_axis_tdata[63:48]        ;

                    state               <=      DATA1                       ;
                end
                else begin
                    state               <=      IDLE                        ;
                end 
            end
            DATA1 : begin
                if (rx_axis_tvalid & rx_axis_tkeep != 0) begin
                    src_sequence_number <=      rx_axis_tdata[15:0]         ;
                    src_data[47:0]      <=      rx_axis_tdata[63:16]        ;

                    state               <=      DATA2                       ;
                end
                else begin
                    state               <=      IDLE                        ;
                end 
            end
            DATA2 : begin
                if (rx_axis_tvalid & rx_axis_tkeep != 0) begin
                    src_data[111:48]    <=      rx_axis_tdata               ;

                    state               <=      DATA3                       ;
                end
                else begin
                    state               <=      IDLE                        ;
                end 
            end
            DATA3 : begin
                if (rx_axis_tvalid & rx_axis_tkeep != 0) begin
                    src_data[175:112]   <=      rx_axis_tdata               ;

                    state               <=      DATA4                       ;
                end
                else begin
                    state               <=      IDLE                        ;
                end 
            end
            DATA4 : begin
                if (rx_axis_tvalid & rx_axis_tkeep != 0) begin
                    src_data[239:176]   <=      rx_axis_tdata               ;

                    state               <=      DATA5                       ;
                end
                else begin
                    state               <=      IDLE                        ;
                end 
            end
            DATA5 : begin
                if (rx_axis_tvalid & rx_axis_tkeep != 0) begin
                    src_data[255:240]   <=      rx_axis_tdata[15:0]         ;

                    state               <=      HANDLE                      ;
                end
                else begin
                    state               <=      IDLE                        ;
                end
            end
            HANDLE : begin
                state               <=          IDLE                        ;
            end
        endcase
    end
end

always @(posedge aclk) begin
    if (areset) begin
        icmp_src_mac             <=                  0                   ;
        icmp_src_ip              <=                  0                   ;
        icmp_src_identifier      <=                  0                   ;
        icmp_src_sequence_number <=                  0                   ;
        icmp_src_data            <=                  0                   ;
        tx_icmp_en               <=                  0                   ;
    end
    else if (rx_axis_tlast == 0 && rx_axis_tlast_reg == 1) begin
        if ({des_mac[7:0], des_mac[15:8], des_mac[23:16], des_mac[31:24], des_mac[39:32], des_mac[47:40]} != BOARD_MAC) begin
            icmp_src_mac             <=                  0                   ;
            icmp_src_ip              <=                  0                   ;
            icmp_src_identifier      <=                  0                   ;
            icmp_src_sequence_number <=                  0                   ;
            icmp_src_data            <=                  0                   ;
            tx_icmp_en               <=                  0                   ;
        end
        else if ({rx_type[7:0], rx_type[15:8]} != ICMP_TYPE) begin
            icmp_src_mac             <=                  0                   ;
            icmp_src_ip              <=                  0                   ;
            icmp_src_identifier      <=                  0                   ;
            icmp_src_sequence_number <=                  0                   ;
            icmp_src_data            <=                  0                   ;
            tx_icmp_en               <=                  0                   ;
        end
        else begin
            if ({op_code[7:0], op_code[15:8]} == 16'h08_00) begin
                icmp_src_mac             <=                  src_mac             ;
                icmp_src_ip              <=                  src_ip              ;
                icmp_src_identifier      <=                  src_identifier      ;
                icmp_src_sequence_number <=                  src_sequence_number ;
                icmp_src_data            <=                  src_data            ;
                tx_icmp_en               <=                  1                   ;

                if (show_message_type == 1) begin
                    $display("Received message is ping_request.");
                end
            end
            else begin
                icmp_src_mac             <=                  src_mac             ;
                icmp_src_ip              <=                  src_ip              ;
                icmp_src_identifier      <=                  src_identifier      ;
                icmp_src_sequence_number <=                  src_sequence_number ;
                icmp_src_data            <=                  src_data            ;
                tx_icmp_en               <=                  0                   ;

                if (show_message_type == 1) begin
                    $display("Received message is ping_reply.");
                end

                /*
                TODO
                ping来回的时间，这里应该还是要把时间传给generator里的request，那里面有发送时间
                ???verilog不支持获取系统时间？？？
                */
            end
        end
    end
    else begin
        icmp_src_mac             <=                  0                   ;
        icmp_src_ip              <=                  0                   ;
        icmp_src_identifier      <=                  0                   ;
        icmp_src_sequence_number <=                  0                   ;
        icmp_src_data            <=                  0                   ;
        tx_icmp_en               <=                  0                   ;
    end
end

endmodule
