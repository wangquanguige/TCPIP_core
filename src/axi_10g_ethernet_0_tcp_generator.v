`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/17 16:33:55
// Design Name: 
// Module Name: axi_10g_ethernet_0_tcp_generator
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


module axi_10g_ethernet_0_tcp_generator # (
        parameter           BOARD_MAC          =          48'h02_00_c0_a8_0a_0a           ,
        parameter           BOARD_IP           =          {8'd192,8'd168,8'd2,8'd20}      ,
        parameter           PORT               =          16'h00_24                       ,
        parameter           RAM_ADDR_WIDTH     =          13                              ,
        parameter           TCP_DATA_LENGTH    =          40
    )
    (
        input                    aclk                              ,
        input                    areset                            ,
                 
        input                    send_syn_rcvd                     ,
        input                    send_fin_1                        ,
        input                    send_fin_2                        ,
        input         [31:0]     tx_ip                             ,
        input         [47:0]     tx_mac                            ,
        input         [15:0]     tx_port                           ,
                 
        input         [31:0]     seq_number_local                  ,
        input         [31:0]     ack_number_local                  ,
        input         [31:0]     ack_number_opposite               ,
        output        [31:0]     seq_number_link_new               ,
        output        [31:0]     seq_number_data_new               ,

        input         [15:0]     ip_identification                 ,
        output                   ip_identification_data_new        ,
        output                   ip_identification_link_new        ,

        input         [15:0]     rx_window_size                    ,

        input         [7:0]      now_shift_count                   ,
        input         [15:0]     now_opposite_window               ,
        input                    now_acked                         ,
        input         [15:0]     data_len                          ,
                 
        input         [3:0]      tcp_state                         ,
        input                    established_moment                ,

        input         [63:0]     link_clk_cnt                      ,

        input                    rx_user_tready                    ,

        output        [63:0]     tcp_link_tdata                    ,
        output        [ 7:0]     tcp_link_tkeep                    ,
        output                   tcp_link_tvalid                   ,
        output                   tcp_link_tlast                    ,
        input                    tcp_link_tready                   ,
        output                   tcp_link_en                       ,
        output                   tcp_link_done                     ,

        output        [63:0]     tcp_user_tdata                    ,
        output        [ 7:0]     tcp_user_tkeep                    ,
        output                   tcp_user_tvalid                   ,
        output                   tcp_user_tlast                    ,
        input                    tcp_user_tready                   ,
        output                   tcp_user_en                       ,
        output                   tcp_user_done                     ,

        input                    tx_user_tvalid                    ,
        output                   tx_user_tready                    ,
        input         [63:0]     tx_user_tdata                     ,
        input         [7:0]      tx_user_tkeep                     ,

        output                   user_checksum_rd_en               ,
        input         [15:0]     user_checksum_dout                ,
        input                    user_checksum_empty               ,

        output                   disconnect_signal
    );

    wire             clk_en_a                       ;
    wire  [RAM_ADDR_WIDTH-1:0]      wr_addr                        ;
    wire  [67:0]     dina                           ;
    wire             clk_en_b                       ;
    wire  [RAM_ADDR_WIDTH-1:0]      rd_addr                        ;
    wire  [67:0]     doutb                          ;

    axi_10g_ethernet_0_tcp_link_manager #(
        .BOARD_MAC(BOARD_MAC),
        .BOARD_IP(BOARD_IP),
        .PORT(PORT)
    ) tcp_link_manager (
        .aclk               (aclk),
        .areset             (areset),

        .send_syn_rcvd      (send_syn_rcvd),
        .send_fin_1         (send_fin_1),
        .send_fin_2         (send_fin_2),
        .tx_ip              (tx_ip),
        .tx_mac             (tx_mac),   
        .tx_port            (tx_port),
        .seq_number_local   (seq_number_local),
        .ack_number_local   (ack_number_local),
        .seq_number_link_new     (seq_number_link_new),

        .ip_identification  (ip_identification),
        .ip_identification_link_new(ip_identification_link_new),

        .tcp_link_tdata     (tcp_link_tdata),
        .tcp_link_tkeep     (tcp_link_tkeep),
        .tcp_link_tvalid    (tcp_link_tvalid),
        .tcp_link_tlast     (tcp_link_tlast),
        .tcp_link_tready    (tcp_link_tready),
        .tcp_link_en        (tcp_link_en),
        .tcp_link_done      (tcp_link_done)
    );

    axi_10g_ethernet_0_tcp_tx_block #(
        .BOARD_MAC(BOARD_MAC),
        .BOARD_IP(BOARD_IP),
        .PORT(PORT),
        .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),

        .TCP_DATA_LENGTH(TCP_DATA_LENGTH)
    ) tcp_tx_block
    (
        .aclk               (aclk),
        .areset             (areset),

        .seq_number_local   (seq_number_local),
        .ack_number_local   (ack_number_local),
        .ack_number_opposite(ack_number_opposite),
        .seq_number_data_new     (seq_number_data_new),

        .rx_window_size     (rx_window_size),

        .ip_identification  (ip_identification),
        .ip_identification_data_new(ip_identification_data_new),

        .established_moment (established_moment),

        .tx_ip              (tx_ip),
        .tx_mac             (tx_mac),
        .tx_port            (tx_port),
        .tcp_state          (tcp_state),

        .now_opposite_window(now_opposite_window),
        .now_shift_count    (now_shift_count),
        .now_acked          (now_acked),
        .data_len           (data_len),

        .link_clk_cnt       (link_clk_cnt),

        .rx_user_tready     (rx_user_tready),

        .tx_user_tvalid     (tx_user_tvalid),
        .tx_user_tready     (tx_user_tready),
        .tx_user_tdata      (tx_user_tdata),
        .tx_user_tkeep      (tx_user_tkeep),

        .user_checksum_rd_en(user_checksum_rd_en)  ,
        .user_checksum_dout (user_checksum_dout)   ,
        .user_checksum_empty(user_checksum_empty)  ,

        .clk_en_a(clk_en_a),
        .wr_addr(wr_addr),
        .dina(dina),    
        .clk_en_b(clk_en_b), 
        .rd_addr(rd_addr),
        .doutb(doutb),  

        .tcp_tx_tdata       (tcp_user_tdata),
        .tcp_tx_tkeep       (tcp_user_tkeep),
        .tcp_tx_tvalid      (tcp_user_tvalid),
        .tcp_tx_tlast       (tcp_user_tlast),

        .tcp_tx_tready      (tcp_user_tready),
        .tcp_tx_en          (tcp_user_en),
        .tcp_tx_done        (tcp_user_done),

        .disconnect_signal  (disconnect_signal)      
    );

    blk_mem_gen_0 TCP_TX_RAM (
        .clka(aclk),    // input wire clka
        .ena(clk_en_a),      // input wire ena
        .wea(1),      // input wire [0 : 0] wea
        .addra(wr_addr),  // input wire [RAM_ADDR_WIDTH-1 : 0] addra
        .dina(dina),    // input wire [67 : 0] dina
        .clkb(aclk),    // input wire clkb
        .enb(clk_en_b),      // input wire enb
        .addrb(rd_addr),  // input wire [RAM_ADDR_WIDTH-1 : 0] addrb
        .doutb(doutb)  // output wire [67 : 0] doutb
    );

    /*axi_10g_ethernet_0_ram #(RAM_ADDR_WIDTH) tcp_ram
   (
      .wr_clk                          (aclk),
      .wr_addr                         (wr_addr),
      .data_in                         (dina),
      .wr_allow                        (clk_en_a),
      
      .rd_clk                          (aclk),
      .rd_sreset                       (areset),
      .rd_addr                         (rd_addr),
      .data_out                        (doutb),
      .rd_allow                        (clk_en_b)
   );*/
endmodule
