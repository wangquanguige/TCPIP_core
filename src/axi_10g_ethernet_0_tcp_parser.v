`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/17 16:32:37
// Design Name: 
// Module Name: axi_10g_ethernet_0_tcp_parser
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


module axi_10g_ethernet_0_tcp_parser #(
        parameter           BOARD_MAC          =          48'h02_00_c0_a8_0a_0a           ,
        parameter           BOARD_IP           =          {8'd192,8'd168,8'd2,8'd20}      ,
        parameter           RAM_ADDR_WIDTH     =          11                              ,
        parameter           PORT               =          16'h00_24             
    ) 
    (
        input                           aclk                              ,
        input                           areset                            ,

        input   [63:0]                  rx_axis_tdata                     ,
        input   [ 7:0]                  rx_axis_tkeep                     ,
        input                           rx_axis_tvalid                    ,
        input                           rx_axis_tlast                     ,
        output                          rx_axis_tready                    ,

        output  reg [31:0]              seq_number_store                  , 
        output  reg                     rx_user_to_ram_tvalid                    ,
        input                           rx_user_to_ram_tready                    ,
        output  reg [63:0]              rx_user_to_ram_tdata                     ,
        output  reg [7:0]               rx_user_to_ram_tkeep                     ,

        output  reg                     rx_user_to_fifo_tvalid                    ,
        input                           rx_user_to_fifo_tready                    ,
        output  reg [63:0]              rx_user_to_fifo_tdata                     ,
        output  reg [7:0]               rx_user_to_fifo_tkeep                     ,

        output  reg                     syn                               ,
        output  reg                     fin                               ,
        output  reg                     ack                               ,
        output  reg                     rst                               ,
        output  reg [31:0]              seq_number                        ,
        output  reg [31:0]              ack_number                        ,
        output  reg                     state_message                     ,
        output  reg [31:0]              counter_ip                        ,
        output  reg [47:0]              counter_mac                       ,
        output  reg [15:0]              counter_port                      ,
        output  reg [15:0]              opposite_window                   ,
        output  reg [7:0]               shift_count                       ,

        output  reg [15:0]              data_len                          ,

        input   [31:0]                  ack_number_local                  ,

        // 0:IDLE  1:SYN_RCVD  2:SYN_SENT  3:ESTABLISHED  4:FIN_WAIT_1  5:FIN_WAIT_2  6:CLOSE_WAIT  7:LAST_ACK  8 TIME_WAIT
        input       [3:0]               tcp_state                          
    );

    assign          rx_axis_tready           =           1           ;

    localparam TCP_TYPE         =       16'h0800;
    localparam IDLE             =       0,
               MAC_HEAD         =       1,
               IP_HEAD          =       2,
               IP_HEAD_SRC_IP   =       3,
               TCP_PORT         =       4,
               SEQ_ACK          =       5,
               WINDOW           =       6,
               DATA             =       7;//,
               //CUSHION          =       8;

    (* mark_debug = "true"*)reg         [3:0]       state;
    (* mark_debug = "true"*)reg         [47:0]      src_mac;
    (* mark_debug = "true"*)reg         [47:0]      des_mac;
    reg         [31:0]      src_ip;
    reg         [31:0]      des_ip;
    reg         [15:0]      rx_type;

    reg         [ 7:0]      protocol;
    reg         [15:0]      des_port;
    reg         [15:0]      src_port;
    (* mark_debug = "true"*)reg         [31:0]      seq_number_reg;
    (* mark_debug = "true"*)reg         [31:0]      ack_number_reg;
    reg                     syn_reg;
    reg                     fin_reg;
    reg                     ack_reg;
    reg                     rst_reg;

    assign          rx_axis_tready           =           1           ;

    reg         [7:0]       option_kind    ;
    reg         [7:0]       option_len     ;
    reg         [7:0]       option_next    ; // 1:kind 2:len 3:data 4:shift_count

    (* mark_debug = "true"*)reg         [5:0]       data_offset ; // TCP报头可选字段长度

    reg         [31:0]      seq_number_store_reg;

    integer i;

    (* mark_debug = "true" *)reg [15:0] total_len;
    (* mark_debug = "true" *)reg [15:0] ip_len;
    (* mark_debug = "true" *)reg [15:0] tcp_len;

    always @(posedge aclk) begin
        if (areset) begin
            state <= IDLE;
        end
        else begin
            case (state)
                IDLE : begin
                    rx_user_to_ram_tdata   <=  0;
                    rx_user_to_ram_tkeep   <=  0;
                    rx_user_to_ram_tvalid  <=  0;

                    rx_user_to_fifo_tdata   <=  0;
                    rx_user_to_fifo_tkeep   <=  0;
                    rx_user_to_fifo_tvalid  <=  0;

                    option_next             <=      1                           ;
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

                        ip_len              <=      rx_axis_tdata[51:48] * 4        ;

                        state               <=      IP_HEAD                     ;
                    end
                    else begin
                        state               <=      IDLE                        ;
                    end
                end
                IP_HEAD : begin
                    if (rx_axis_tvalid & rx_axis_tkeep != 0) begin
                        protocol            <=      rx_axis_tdata[63:56]        ;

                        total_len           <=      {rx_axis_tdata[7:0], rx_axis_tdata[15:8]};

                        state               <=      IP_HEAD_SRC_IP              ;
                    end
                    else begin
                        state               <=      IDLE                        ;
                    end
                end
                IP_HEAD_SRC_IP : begin
                    if (rx_axis_tvalid & rx_axis_tkeep != 0) begin
                        src_ip              <=      rx_axis_tdata[47:16]        ;
                        des_ip[15:0]        <=      rx_axis_tdata[63:48]        ;

                        state               <=      TCP_PORT                    ;
                    end
                    else begin
                        state               <=      IDLE                        ;
                    end
                end
                TCP_PORT : begin
                    if (rx_axis_tvalid & rx_axis_tkeep != 0) begin
                        des_ip[31:16]       <=      rx_axis_tdata[15:0]         ;
                        src_port            <=      rx_axis_tdata[31:16]        ;
                        des_port            <=      rx_axis_tdata[47:32]        ;
                        seq_number_reg[15:0]<=      rx_axis_tdata[63:48]        ;

                        seq_number_store_reg[31:16]<={rx_axis_tdata[55:48], rx_axis_tdata[63:56]};

                        state               <=      SEQ_ACK                     ;
                    end
                    else begin
                        state               <=      IDLE                        ;
                    end
                end
                SEQ_ACK : begin
                    if (rx_axis_tvalid & rx_axis_tkeep != 0) begin
                        seq_number_store_reg[15:0]<={rx_axis_tdata[7:0], rx_axis_tdata[15:8]};

                        seq_number_reg[31:16]<=     rx_axis_tdata[15:0]         ;
                        ack_number_reg      <=      rx_axis_tdata[47:16]        ;
                        data_offset         <=      rx_axis_tdata[55:52] * 4 -20       ;

                        ack_reg             <=      rx_axis_tdata[60]           ;
                        syn_reg             <=      rx_axis_tdata[57]           ;
                        fin_reg             <=      rx_axis_tdata[56]           ;
                        rst_reg             <=      rx_axis_tdata[58]           ;

                        tcp_len             <=      rx_axis_tdata[55:52] * 4    ;
                        data_len            <=      total_len - ip_len - rx_axis_tdata[55:52] * 4    ;

                        shift_count         <=      0                           ;

                        state               <=      WINDOW                      ;
                    end
                    else begin
                        state               <=      IDLE                        ;
                    end
                end
                WINDOW : begin
                    if (rx_axis_tvalid & rx_axis_tkeep != 0) begin
                        opposite_window      <=      rx_axis_tdata[15:0]         ;

                        state                <=      DATA                        ;
                    end
                    else begin
                        state               <=      IDLE                        ;
                    end

                    for (i = 6 ; i < 8 ; i = i + 1) begin
                        if (rx_axis_tkeep[i] == 1) begin
                            case(option_next)
                                1 : begin
                                    option_kind     =       rx_axis_tdata[i*8+7-:8]      ;
                                    if (option_kind == 0 || option_kind == 1) begin
                                        option_next     <=       1       ;
                                    end
                                    else if (option_kind == 3) begin
                                        option_next     <=       2       ;
                                    end
                                    else begin
                                        option_next     <=       2       ;
                                    end
                                end
                                2 : begin
                                    option_len      <=       rx_axis_tdata[i*8+7-:8] - 2 ;
                                    option_next     <=       3                           ;
                                end
                                3 : begin
                                    if (option_kind == 3) begin
                                        shift_count     <=   rx_axis_tdata[i*8+7-:8]     ;
                                        option_next     <=   1                           ;
                                    end
                                    else begin
                                        if (option_len > 1) begin
                                            option_next     <=       3       ;
                                        end
                                        else begin
                                            option_next     <=       1       ;
                                        end

                                        option_len      =       option_len  -  1    ;
                                    end
                                end
                            endcase
                        end
                    end

                    if (data_offset) begin
                        data_offset <=  data_offset - 2;
                    end
                    else begin
                        if (data_len !=0 && ack_reg == 1 && fin_reg == 0 && tcp_state == 3 // && seq_number_reg == ack_number_local 
                        && {des_mac[7:0], des_mac[15:8], des_mac[23:16], des_mac[31:24], des_mac[39:32], des_mac[47:40]} == BOARD_MAC &&
                            {rx_type[7:0], rx_type[15:8]} == TCP_TYPE && protocol == 8'h06 && des_port == {PORT[7:0], PORT[15:8]}) begin

                            if (seq_number_reg == ack_number_local) begin
                                rx_user_to_fifo_tdata   <=  rx_axis_tdata;
                                rx_user_to_fifo_tkeep   <=  rx_axis_tkeep;
                                rx_user_to_fifo_tvalid  <=  rx_axis_tvalid;
                            end
                            else begin
                                rx_user_to_ram_tdata   <=  {48'b0, rx_axis_tdata[63:48]};
                                rx_user_to_ram_tkeep   <=  8'b0000_0011;
                                rx_user_to_ram_tvalid  <=  1;
                                seq_number_store<=  seq_number_store_reg;
                                seq_number_store_reg <= seq_number_store_reg + 2;
                            end
                            
                        end
                    end
                end
                DATA : begin
                    for (i = 0 ; i < 8 ; i = i + 1) begin
                        if (rx_axis_tkeep[i] == 1) begin
                            case(option_next)
                                1 : begin
                                    option_kind     =       rx_axis_tdata[i*8+7-:8]      ;
                                    if (option_kind == 0 || option_kind == 1) begin
                                        option_next     =       1       ;
                                    end
                                    else if (option_kind == 3) begin
                                        option_next     =       2       ;
                                    end
                                    else begin
                                        option_next     =       2       ;
                                    end
                                end
                                2 : begin
                                    option_len      =       rx_axis_tdata[i*8+7-:8] - 2 ;
                                    option_next     =       3                           ;
                                end
                                3 : begin
                                    if (option_kind == 3) begin
                                        shift_count     =   rx_axis_tdata[i*8+7-:8]     ;
                                        option_next     =   1                           ;
                                    end
                                    else begin
                                        if (option_len > 1) begin
                                            option_next     =       3       ;
                                        end
                                        else begin
                                            option_next     =       1       ;
                                        end

                                        option_len      =       option_len  -  1    ;
                                    end
                                end
                            endcase
                        end
                    end

                    if (data_len !=0 && ack_reg == 1 && fin_reg == 0 && tcp_state == 3  //&& seq_number_reg == ack_number_local 
                    && {des_mac[7:0], des_mac[15:8], des_mac[23:16], des_mac[31:24], des_mac[39:32], des_mac[47:40]} == BOARD_MAC &&
                            {rx_type[7:0], rx_type[15:8]} == TCP_TYPE && protocol == 8'h06 && des_port == {PORT[7:0], PORT[15:8]}) begin
                        if (seq_number_reg == ack_number_local)  begin
                            rx_user_to_fifo_tdata   <=  rx_axis_tdata;
                            rx_user_to_fifo_tkeep   <=  rx_axis_tkeep;
                            rx_user_to_fifo_tvalid  <=  rx_axis_tvalid;
                        end 
                        else begin
                            case (data_offset) 
                                0 : begin
                                    rx_user_to_ram_tdata   <=  rx_axis_tdata;
                                    rx_user_to_ram_tkeep   <=  rx_axis_tkeep;
                                    rx_user_to_ram_tvalid  <=  rx_axis_tvalid;
                                end
                                2 : begin
                                    rx_user_to_ram_tdata   <=  {16'b0, rx_axis_tdata[63:16]};
                                    rx_user_to_ram_tkeep   <=  rx_axis_tkeep[7:2];
                                    rx_user_to_ram_tvalid  <=  rx_axis_tvalid;
                                    data_offset     <=  0;
                                end
                                6 : begin
                                    rx_user_to_ram_tdata   <=  {48'b0, rx_axis_tdata[63:48]};
                                    rx_user_to_ram_tkeep   <=  rx_axis_tkeep[7:6];
                                    rx_user_to_ram_tvalid  <=  rx_axis_tvalid;
                                    data_offset     <=  0  ;
                                end
                                default : begin
                                    rx_user_to_ram_tdata   <=  0;
                                    rx_user_to_ram_tkeep   <=  0;
                                    rx_user_to_ram_tvalid  <=  0;
                                    data_offset     <=  0;
                                end
                            endcase
                            seq_number_store <=  seq_number_store_reg;
                            seq_number_store_reg <= seq_number_store_reg + 8;
                        end
                    end

                    if (rx_axis_tvalid & rx_axis_tkeep != 0) begin
                        if (rx_axis_tlast) begin
                            option_kind         <=      0                           ;
                            option_len          <=      0                           ;
                            option_next         <=      0                           ;
                            state               <=      IDLE                        ;
                        end
                    end
                end
            endcase
        end
    end

    always @(posedge aclk) begin
        //if (state == DATA) begin
        if (rx_axis_tlast == 1) begin
            if ({des_mac[7:0], des_mac[15:8], des_mac[23:16], des_mac[31:24], des_mac[39:32], des_mac[47:40]} != BOARD_MAC ) begin
                syn                     <=                  0                   ;
                fin                     <=                  0                   ;
                ack                     <=                  0                   ;
                rst                     <=                  0                   ;
                seq_number              <=                  0                   ;
                ack_number              <=                  0                   ;
                state_message           <=                  0                   ;
                counter_ip              <=                  0                   ;
                counter_mac             <=                  0                   ;
                counter_port            <=                  0                   ;
            end
            else if ({rx_type[7:0], rx_type[15:8]} != TCP_TYPE | protocol != 8'h06 | des_port != {PORT[7:0], PORT[15:8]}) begin
                syn                     <=                  0                   ;
                fin                     <=                  0                   ;
                ack                     <=                  0                   ;
                rst                     <=                  0                   ;
                seq_number              <=                  0                   ;
                ack_number              <=                  0                   ;
                state_message           <=                  0                   ;
                counter_ip              <=                  0                   ;
                counter_mac             <=                  0                   ;
                counter_port            <=                  0                   ;
            end
            else begin
                if (1 //& fin_reg == 0
                ) begin                                     // established阶段发送数据 
                    syn                     <=                  syn_reg                 ;
                    fin                     <=                  fin_reg                 ;
                    ack                     <=                  ack_reg                 ;
                    rst                     <=                  rst_reg                 ;
                    seq_number              <=                  seq_number_reg          ;
                    ack_number              <=                  ack_number_reg          ;
                    state_message           <=                  0                       ;
                    counter_ip              <=                  src_ip                  ;
                    counter_mac             <=                  src_mac                 ;
                    counter_port            <=                  src_port                ;
                end
                else begin
                    /*syn                     <=                  syn_reg                 ;
                    fin                     <=                  fin_reg                 ;
                    ack                     <=                  ack_reg                 ;
                    rst                     <=                  rst_reg                 ;
                    seq_number              <=                  seq_number_reg          ;
                    ack_number              <=                  ack_number_reg          ;
                    state_message           <=                  1                       ;
                    counter_ip              <=                  src_ip                  ;
                    counter_mac             <=                  src_mac                 ;
                    counter_port            <=                  src_port                ;*/
                    syn                     <=                  0                       ;
                    fin                     <=                  0                       ;
                    ack                     <=                  0                       ;
                    rst                     <=                  0                       ;
                    seq_number              <=                  0                       ;
                    ack_number              <=                  0                       ;
                    state_message           <=                  0                       ;
                    counter_ip              <=                  0                       ;
                    counter_mac             <=                  0                       ;
                    counter_port            <=                  0                       ;
                end
            end
        end
        else begin
            syn                     <=                  0                   ;
            fin                     <=                  0                   ;
            ack                     <=                  0                   ;
            rst                     <=                  0                   ;
            seq_number              <=                  0                   ;
            ack_number              <=                  0                   ;
            state_message           <=                  0                   ;
            counter_ip              <=                  0                   ;
            counter_mac             <=                  0                   ;
            counter_port            <=                  0                   ;
        end
    end

endmodule
