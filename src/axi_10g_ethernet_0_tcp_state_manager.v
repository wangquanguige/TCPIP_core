`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/17 16:33:20
// Design Name: 
// Module Name: axi_10g_ethernet_0_tcp_state_manager
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


module axi_10g_ethernet_0_tcp_state_manager #(
        parameter           BOARD_MAC          =          48'h02_00_c0_a8_0a_0a           ,
        parameter           BOARD_IP           =          {8'd192,8'd168,8'd2,8'd20}      ,
        parameter           PORT               =          16'h00_24
    ) 
    (
        input                   aclk                       ,
        input                   areset                     ,
        
        input                   syn                        ,
        input                   fin                        ,
        input                   ack                        ,
        input                   rst                        ,
        input   [31:0]          seq_number                 ,
        input   [31:0]          ack_number                 ,
        input                   state_message              ,

        output  reg [31:0]      seq_number_local           ,       // 本地seq_number
        output  reg [31:0]      ack_number_local           ,       // 本地ack_number
        output  reg [31:0]      ack_number_opposite        ,
        input       [31:0]      seq_number_link_new        ,
        input       [31:0]      seq_number_data_new        ,

        input       [31:0]      rx_store_ack_number_local  ,
        input                   rx_store_signal            ,

        output  reg [15:0]      ip_identification          ,
        input                   ip_identification_link_new ,
        input                   ip_identification_data_new ,

        input       [7:0]       shift_count                ,
        input       [15:0]      opposite_window            ,
        output  reg [7:0]       now_shift_count            ,
        output  reg [15:0]      now_opposite_window        ,
        output  reg             now_acked                  ,

        input       [15:0]      data_len                   ,

        output  reg             established_moment         ,
        output  reg [31:0]      rd_addr_start              ,

        output  reg             send_syn_rcvd              ,
        output  reg             send_fin_1                 ,
        output  reg             send_fin_2                 ,

        input   [31:0]          rx_ip                      ,
        input   [47:0]          rx_mac                     ,
        input   [15:0]          rx_port                    ,
        output  reg [31:0]      tx_ip                      ,
        output  reg [47:0]      tx_mac                     ,
        output  reg [15:0]      tx_port                    ,

        output  reg [63:0]      link_clk_cnt               ,

        // 0:IDLE  1:SYN_RCVD  2:SYN_SENT  3:ESTABLISHED  4:FIN_WAIT_1  5:FIN_WAIT_2  6:CLOSE_WAIT  7:LAST_ACK  8 TIME_WAIT
        output  reg [3:0]       tcp_state                  ,

        output  reg             state_reset                ,

        input                   disconnect_signal
    );
/*
task seq_ack_reverse;
    input   [31:0] local_seq;
    inout   [31:0] local_ack;
    
    reg    [31:0]  data;

    begin
        data = {local_seq[7:0], local_seq[15:8], local_seq[23:16], local_seq[31:24]} + 1 ;
        local_ack = {data[7:0], data[15:8], data[23:16], data[31:24]};
    end
endtask*/

task reverse_add;
    input   [31:0]  add_number;
    inout   [31:0]  seq_ack_number;
    reg     [31:0]  data;

    begin
        data = {seq_ack_number[7:0], seq_ack_number[15:8], seq_ack_number[23:16], seq_ack_number[31:24]} + add_number ;
        seq_ack_number = {data[7:0], data[15:8], data[23:16], data[31:24]};
    end
endtask

task reverse_add_opposite;
    input   [31:0]  opposite_number;
    inout   [31:0]  number;
    reg     [31:0]  data;

    begin
        data = {opposite_number[7:0], opposite_number[15:8], opposite_number[23:16], opposite_number[31:24]} + 1 ;
        number = {data[7:0], data[15:8], data[23:16], data[31:24]};
    end
endtask

    localparam IDLE             =       0,
               SYN_RCVD         =       1,
               SYN_SENT         =       2,
               ESTABLISHED      =       3,
               FIN_WAIT_1       =       4,
               FIN_WAIT_2       =       5,
               CLOSE_WAIT       =       6,
               LAST_ACK         =       7,
               TIME_WAIT        =       8;

    reg [31:0] local_tmp;   
    reg [31:0] fin_counter;

    reg [31:0] link_ip;
    reg [47:0] link_mac;
    reg [15:0] link_port;

    (* mark_debug = "true"*)reg test_signal;

    always @(posedge aclk) begin
        if (areset) begin
            seq_number_local    =          0           ;
        end
        else begin
            if (seq_number_data_new) reverse_add(seq_number_data_new, seq_number_local);
            if (seq_number_link_new) reverse_add(seq_number_link_new, seq_number_local);
        end
    end

    always @(posedge aclk) begin
        if (areset) begin
            ip_identification   <=   1;
        end
        else begin
            if (ip_identification_data_new) begin
                ip_identification   <=   ip_identification + 1;
            end
            if (ip_identification_link_new) begin
                ip_identification   <=   ip_identification + 1;
            end
        end
    end

    always @(posedge aclk) begin
        if (areset) begin
            tcp_state           <=          0           ;
            send_syn_rcvd       <=          0           ;
            send_fin_1          <=          0           ;
            send_fin_2          <=          0           ;

            fin_counter         <=          0           ;

            state_reset         <=          0           ;

            ack_number_local    <=          0           ;
            ack_number_opposite <=          0           ;
        end     
        else begin  
            if (now_acked) begin
                now_acked               <=      0                   ;
            end
            if (established_moment) begin
                established_moment      <=      0                   ;
            end
            if (rx_store_signal) begin
                test_signal <= 1;
                ack_number_local    <=   {rx_store_ack_number_local[7:0], rx_store_ack_number_local[15:8], rx_store_ack_number_local[23:16], rx_store_ack_number_local[31:24]};
            end

            case (tcp_state)
                IDLE : begin
                    if (syn == 1) begin
                        tcp_state           <=          SYN_RCVD            ;
                        tx_ip               <=          rx_ip               ;
                        tx_mac              <=          rx_mac              ;
                        tx_port             <=          rx_port             ;
                        /*cal_local           =          {seq_number[7:0], seq_number[15:8], seq_number[23:16], seq_number[31:24]};
                        cal_local           =          cal_local    +   1  ;
                        ack_number_local    =          {cal_local[7:0], cal_local[15:8], cal_local[23:16], cal_local[31:24]};*/
                        //ack_number_local    <=          reverse_add(seq_number);
                        reverse_add_opposite(seq_number, ack_number_local);

                        send_syn_rcvd       <=          1                   ;

                        now_shift_count     <=          shift_count         ;
                        now_opposite_window <=          opposite_window     ;
                    end 
                    else begin 
                        send_syn_rcvd       <=          0                   ;
                    end 
                end
                SYN_RCVD : begin
                    send_syn_rcvd       <=          0                   ;

                    if (ack == 1 & seq_number == ack_number_local & ack_number == seq_number_local ) begin
                        link_clk_cnt        <=          0                   ;

                        tcp_state           <=          ESTABLISHED         ;

                        established_moment  <=          1                   ;
                        rd_addr_start       <=          {seq_number[7:0], seq_number[15:8], seq_number[23:16], seq_number[31:24]}          ;

                        now_opposite_window <=          opposite_window     ;
                        //now_shift_count     <=          shift_count         ;
                    end 
                end
                ESTABLISHED : begin

                    link_clk_cnt    <=      link_clk_cnt    +   1   ;
                    if (rst == 1) begin
                        tcp_state           <=          IDLE                 ;
                    end
                    else if (fin == 1 & ack == 1 & seq_number == ack_number_local) begin
                        tcp_state           <=          CLOSE_WAIT          ;
                        //tcp_state           <=          LAST_ACK            ;
                        send_fin_1          <=          1                   ;

                        tx_ip               <=          rx_ip               ;
                        tx_mac              <=          rx_mac              ;
                        tx_port             <=          rx_port             ;

                        link_ip             <=          rx_ip               ;
                        link_mac            <=          rx_mac              ;
                        link_port           <=          rx_port             ;
                        
                        reverse_add_opposite(seq_number, ack_number_local);

                        fin_counter         <=          1                   ;
                    end
                    else if (ack == 1) begin
                        if(seq_number == ack_number_local) begin
                            reverse_add(data_len, ack_number_local);
                        end/*
                        else if(data_len !=0 && rx_store_ack_number_local != 0) begin
                            test_signal <= 1;
                            ack_number_local    <=   {rx_store_ack_number_local[7:0], rx_store_ack_number_local[15:8], rx_store_ack_number_local[23:16], rx_store_ack_number_local[31:24]};
                        end*/
                        
                        now_acked               <=      1                   ;

                        if ({seq_number_local[7:0], seq_number_local[15:8], seq_number_local[23:16], seq_number_local[31:24]} >= 
                                {ack_number_opposite[7:0], ack_number_opposite[15:8], ack_number_opposite[23:16], ack_number_opposite[31:24]}) begin
                            if ({ack_number[7:0], ack_number[15:8], ack_number[23:16], ack_number[31:24]} > 
                                {ack_number_opposite[7:0], ack_number_opposite[15:8], ack_number_opposite[23:16], ack_number_opposite[31:24]}) begin
                                ack_number_opposite     <=       ack_number         ;
                            end
                        end
                        else begin
                            if ({ack_number[7:0], ack_number[15:8], ack_number[23:16], ack_number[31:24]} > 
                                    {ack_number_opposite[7:0], ack_number_opposite[15:8], ack_number_opposite[23:16], ack_number_opposite[31:24]} | 
                                {ack_number[7:0], ack_number[15:8], ack_number[23:16], ack_number[31:24]} <= 
                                    {seq_number_local[7:0], seq_number_local[15:8], seq_number_local[23:16], seq_number_local[31:24]}) begin
                                ack_number_opposite     <=       ack_number         ;
                            end
                        end
                        // ack_number_opposite     =       ack_number         ;

                        now_opposite_window     <=      opposite_window     ;
                        //now_shift_count     <=          shift_count         ;
                    end
                end
                CLOSE_WAIT : begin                                                              // 第二次挥手遗失，客户端会再发送第一次挥手，这里暂时未考虑该情况
                    send_fin_1          <=          0                   ;                     
                    if (fin_counter == 32'd500) begin
                        fin_counter         <=          0                   ;
                        tcp_state           <=          LAST_ACK            ;
                        send_fin_2          <=          1                   ;

                        tx_ip               <=          link_ip             ;
                        tx_mac              <=          link_mac            ;
                        tx_port             <=          link_port           ;
                    end
                    else begin
                        fin_counter         <=          fin_counter +   1   ;
                    end 
                end
                LAST_ACK : begin
                    send_fin_1          <=          0                   ; 
                    send_fin_2          <=          0                   ;
                    if (ack == 1 & seq_number == ack_number_local & ack_number == seq_number_local) begin
                        tcp_state           <=          IDLE           ;
                    end 
                    tcp_state           <=          IDLE           ;
                end
                TIME_WAIT : begin             // 2*MSL (此处MSL指定为30s,RFC 793标准为2 minutes)
                    
                end
            endcase

            if (disconnect_signal == 1) begin
                tcp_state   =  IDLE;

                state_reset =   1   ;
            end
        end
    end

endmodule
