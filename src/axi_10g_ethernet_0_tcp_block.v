`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/17 16:21:39
// Design Name: 
// Module Name: axi_10g_ethernet_0_tcp_block
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


module axi_10g_ethernet_0_tcp_block #(
        parameter           BOARD_MAC          =          48'h02_00_c0_a8_0a_0a           ,
        parameter           BOARD_IP           =          {8'd192,8'd168,8'd2,8'd20}      ,
        parameter           PORT               =          16'h00_18                       ,
        parameter           TCP_DATA_LENGTH    =          40                              ,
        parameter           RAM_ADDR_WIDTH     =          13                              
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

        output              [63:0]      tcp_link_tdata                   ,
        output              [ 7:0]      tcp_link_tkeep                   ,
        output                          tcp_link_tvalid                  ,
        output                          tcp_link_tlast                   ,
        input                           tcp_link_tready                  ,
        output                          tcp_link_en                      ,
        output                          tcp_link_done                    ,

        output              [63:0]      tcp_user_tdata                   ,
        output              [ 7:0]      tcp_user_tkeep                   ,
        output                          tcp_user_tvalid                  ,
        output                          tcp_user_tlast                   ,
        input                           tcp_user_tready                  ,
        output                          tcp_user_en                      ,
        output                          tcp_user_done                    ,

        // 上层TX_USER数据
        input                           tx_user_tvalid                   ,
        output                          tx_user_tready                   ,
        input               [63:0]      tx_user_tdata                    ,
        input               [7:0]       tx_user_tkeep                    ,
        // 上层RX_USER数据
        output                          rx_user_tvalid                   ,
        input                           rx_user_tready                   ,
        output              [63:0]      rx_user_tdata                    ,
        output              [7:0]       rx_user_tkeep                    ,

        output                          user_checksum_rd_en              ,
        input               [15:0]      user_checksum_dout               ,
        input                           user_checksum_empty              ,

        output              [3:0]       tcp_state_out                    ,

        output                          state_reset
    );

    (* mark_debug = "true"*)wire                syn;
    (* mark_debug = "true"*)wire                fin;
    (* mark_debug = "true"*)wire                ack;
    (* mark_debug = "true"*)wire                rst;
    (* mark_debug = "true"*)wire [31:0]         seq_number;
    (* mark_debug = "true"*)wire [31:0]         ack_number;
    (* mark_debug = "true"*)wire                state_message;

    (* mark_debug = "true"*)wire [3:0]          tcp_state;

    assign tcp_state_out = tcp_state;

    wire                send_syn_rcvd;
    wire                send_fin_1;
    wire                send_fin_2;

    wire [31:0]         seq_number_local;
    (* mark_debug = "true"*)wire [31:0]         ack_number_local;
    (* mark_debug = "true"*)wire [31:0]         rx_store_ack_number_local;
    (* mark_debug = "true"*)wire [31:0]         ack_number_opposite;
    wire [31:0]         seq_number_link_new;
    wire [31:0]         seq_number_data_new;

    wire [31:0]         rx_ip;
    wire [47:0]         rx_mac;
    wire [15:0]         rx_port;
    wire [31:0]         tx_ip;
    wire [47:0]         tx_mac;
    wire [15:0]         tx_port;

    wire [7:0]          shift_count;
    wire [15:0]         opposite_window;
    wire [7:0]          now_shift_count;
    wire [15:0]         now_opposite_window;
    
    wire            established_moment;
    (* mark_debug = "true"*)wire                now_acked;

    (* mark_debug = "true"*)wire [15:0]         data_len;


    (*mark_debug = "true" *)wire [63:0]         link_clk_cnt                    ;

    (* mark_debug = "true"*)wire         disconnect_signal;

    (* mark_debug = "true"*)wire [15:0] ip_identification;
    (* mark_debug = "true"*)wire        ip_identification_data_new;
    (* mark_debug = "true"*)wire        ip_identification_link_new;

    (* mark_debug = "true"*)wire                          rx_not_stored_user_tvalid                   ;
    (* mark_debug = "true"*)wire                          rx_not_stored_user_tready                   ;
    (* mark_debug = "true"*)wire              [63:0]      rx_not_stored_user_tdata                    ;
    (* mark_debug = "true"*)wire              [7:0]       rx_not_stored_user_tkeep                    ;
    (* mark_debug = "true"*)wire              [31:0]      seq_number_store                            ;

    (* mark_debug = "true"*)wire                          rx_not_stored_user_tvalid_resize                   ;
    (* mark_debug = "true"*)wire                          rx_not_stored_user_tready_resize                   ;
    (* mark_debug = "true"*)wire              [63:0]      rx_not_stored_user_tdata_resize                    ;
    (* mark_debug = "true"*)wire              [7:0]       rx_not_stored_user_tkeep_resize                    ;
    (* mark_debug = "true"*)wire              [31:0]      seq_number_store_resize                            ;

    (* mark_debug = "true"*)wire              [15:0]      rx_window_size                              ;
    (* mark_debug = "true"*)wire                          rx_store_signal                               ;

    wire  [31:0]      rd_addr_start             ;
    
    axi_10g_ethernet_0_rx_mux rx_mux (
        .aclk               (aclk),
        .areset             (areset),

        .rx_user_tdata      (rx_user_tdata),
        .rx_user_tkeep      (rx_user_tkeep),
        .rx_user_tvalid     (rx_user_tvalid),
        .rx_user_tready     (rx_user_tready),

        .rx_user_ram_tvalid     (rx_user_ram_tvalid),
        .rx_user_ram_tdata      (rx_user_ram_tdata),
        .rx_user_ram_tkeep      (rx_user_ram_tkeep),

        .rx_user_fifo_tvalid     (rx_user_fifo_tvalid),
        .rx_user_fifo_tdata      (rx_user_fifo_tdata),
        .rx_user_fifo_tkeep      (rx_user_fifo_tkeep)                   
    );

    axi_10g_ethernet_0_tcp_parser #(
        .BOARD_MAC(BOARD_MAC),
        .BOARD_IP(BOARD_IP),
        .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
        .PORT(PORT)
    ) tcp_parser (
        .aclk               (aclk),
        .areset             (areset),

        .rx_axis_tdata      (rx_axis_tdata),
        .rx_axis_tkeep      (rx_axis_tkeep),
        .rx_axis_tvalid     (rx_axis_tvalid),
        .rx_axis_tlast      (rx_axis_tlast),
        .rx_axis_tready     (rx_axis_tready),

        .seq_number_store   (seq_number_store),
        .rx_user_to_ram_tvalid     (rx_not_stored_user_tvalid),
        .rx_user_to_ram_tready     (rx_not_stored_user_tready),
        .rx_user_to_ram_tdata      (rx_not_stored_user_tdata),
        .rx_user_to_ram_tkeep      (rx_not_stored_user_tkeep),

        .rx_user_to_fifo_tvalid     (rx_user_fifo_tvalid),
        .rx_user_to_fifo_tready     (rx_user_fifo_tready),
        .rx_user_to_fifo_tdata      (rx_user_fifo_tdata),
        .rx_user_to_fifo_tkeep      (rx_user_fifo_tkeep),
        
        .syn                (syn),
        .fin                (fin),
        .ack                (ack),
        .rst                (rst),
        .seq_number         (seq_number),
        .ack_number         (ack_number),
        .state_message      (state_message),
        .counter_ip         (rx_ip),
        .counter_mac        (rx_mac),
        .counter_port       (rx_port),
        .shift_count        (shift_count),
        .opposite_window    (opposite_window),

        .ack_number_local   (ack_number_local),

        .data_len           (data_len),

        .tcp_state          (tcp_state)
    );

    axi_10g_ethernet_0_rx_store #(
        .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH)
    )
    rx_store (
        .aclk               (aclk),
        .areset             (areset),

        .rd_addr_start      (rd_addr_start),
        .established_moment (established_moment),

        .seq_number_store_resize   (seq_number_store_resize),

        .rx_not_stored_user_tvalid_resize     (rx_not_stored_user_tvalid_resize),
        .rx_not_stored_user_tready_resize     (rx_not_stored_user_tready_resize),
        .rx_not_stored_user_tdata_resize      (rx_not_stored_user_tdata_resize),
        .rx_not_stored_user_tkeep_resize      (rx_not_stored_user_tkeep_resize),

        .rx_user_tvalid     (rx_user_ram_tvalid),
        .rx_user_tready     (rx_user_ram_tready),
        .rx_user_tdata      (rx_user_ram_tdata),
        .rx_user_tkeep      (rx_user_ram_tkeep),

        .rx_window_size     (rx_window_size),

        .ack_number_local   (ack_number_local),

        .rx_store_ack_number_local      (rx_store_ack_number_local),
        .rx_store_signal    (rx_store_signal)
    );

    axi_10g_ethernet_0_rx_data_resize data_resize (
        .aclk               (aclk),
        .areset             (areset),

        .seq_number_store   (seq_number_store),
        .rx_not_stored_user_tvalid     (rx_not_stored_user_tvalid),
        .rx_not_stored_user_tready     (rx_not_stored_user_tready),
        .rx_not_stored_user_tdata      (rx_not_stored_user_tdata),
        .rx_not_stored_user_tkeep      (rx_not_stored_user_tkeep),

        .seq_number_store_resize   (seq_number_store_resize),
        .rx_not_stored_user_tvalid_resize     (rx_not_stored_user_tvalid_resize),
        .rx_not_stored_user_tready_resize     (rx_not_stored_user_tready_resize),
        .rx_not_stored_user_tdata_resize      (rx_not_stored_user_tdata_resize),
        .rx_not_stored_user_tkeep_resize      (rx_not_stored_user_tkeep_resize)

        
    );

    axi_10g_ethernet_0_tcp_state_manager #(
        .BOARD_MAC(BOARD_MAC),
        .BOARD_IP(BOARD_IP),
        .PORT(PORT)
    ) tcp_state_manager (
        .aclk               (aclk),
        .areset             (areset),
        
        .syn                (syn),
        .fin                (fin),
        .ack                (ack),
        .rst                (rst),
        .seq_number         (seq_number),
        .ack_number         (ack_number),
        .state_message      (state_message),

        .send_syn_rcvd      (send_syn_rcvd),
        .send_fin_1         (send_fin_1),
        .send_fin_2         (send_fin_2),

        .rx_store_ack_number_local  (rx_store_ack_number_local),
        .rx_store_signal    (rx_store_signal),

        .seq_number_local   (seq_number_local),
        .ack_number_local   (ack_number_local),
        .ack_number_opposite(ack_number_opposite),
        .seq_number_link_new     (seq_number_link_new),
        .seq_number_data_new     (seq_number_data_new),

        .established_moment (established_moment),

        .rd_addr_start      (rd_addr_start),

        .shift_count        (shift_count),
        .opposite_window    (opposite_window),
        .now_shift_count    (now_shift_count),
        .now_opposite_window(now_opposite_window),
        .now_acked          (now_acked),

        .data_len           (data_len),

        .rx_ip              (rx_ip),
        .rx_mac             (rx_mac),
        .rx_port            (rx_port),
        .tx_ip              (tx_ip),
        .tx_mac             (tx_mac),
        .tx_port            (tx_port),

        .link_clk_cnt       (link_clk_cnt),

        .tcp_state          (tcp_state),

        .state_reset        (state_reset),

        .ip_identification  (ip_identification),
        .ip_identification_data_new(ip_identification_data_new),
        .ip_identification_link_new(ip_identification_link_new),

        .disconnect_signal  (disconnect_signal)
    );

    axi_10g_ethernet_0_tcp_generator #(
        .BOARD_MAC(BOARD_MAC),
        .BOARD_IP(BOARD_IP),
        .PORT(PORT),
        .TCP_DATA_LENGTH(TCP_DATA_LENGTH),
        .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH)
    ) tcp_generator (
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
        .ack_number_opposite(ack_number_opposite),
        .seq_number_link_new(seq_number_link_new),
        .seq_number_data_new(seq_number_data_new),

        .rx_window_size     (rx_window_size),

        .ip_identification  (ip_identification),
        .ip_identification_data_new(ip_identification_data_new),
        .ip_identification_link_new(ip_identification_link_new),

        .now_shift_count    (now_shift_count),
        .now_opposite_window(now_opposite_window),

        .now_acked          (now_acked),  //防止ack丢失
        .data_len           (data_len),    

        .tcp_state          (tcp_state),
        .established_moment (established_moment),

        .link_clk_cnt       (link_clk_cnt),

        .rx_user_tready     (rx_user_tready),

        .tcp_link_tdata     (tcp_link_tdata),
        .tcp_link_tkeep     (tcp_link_tkeep),
        .tcp_link_tvalid    (tcp_link_tvalid),
        .tcp_link_tlast     (tcp_link_tlast),
        .tcp_link_tready    (tcp_link_tready),
        .tcp_link_en        (tcp_link_en),
        .tcp_link_done      (tcp_link_done),
 
        .tcp_user_tdata     (tcp_user_tdata),
        .tcp_user_tkeep     (tcp_user_tkeep),
        .tcp_user_tvalid    (tcp_user_tvalid),
        .tcp_user_tlast     (tcp_user_tlast),
        .tcp_user_tready    (tcp_user_tready),
        .tcp_user_en        (tcp_user_en),
        .tcp_user_done      (tcp_user_done),

        .tx_user_tvalid     (tx_user_tvalid)          ,
        .tx_user_tready     (tx_user_tready)          ,
        .tx_user_tdata      (tx_user_tdata)           ,
        .tx_user_tkeep      (tx_user_tkeep)           ,

        .user_checksum_rd_en(user_checksum_rd_en)  ,
        .user_checksum_dout (user_checksum_dout)   ,
        .user_checksum_empty(user_checksum_empty)  ,

        .disconnect_signal  (disconnect_signal)
    );

endmodule
