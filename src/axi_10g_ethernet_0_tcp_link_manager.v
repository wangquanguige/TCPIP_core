`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/18 15:53:42
// Design Name: 
// Module Name: axi_10g_ethernet_0_tcp_link_manager
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


module axi_10g_ethernet_0_tcp_link_manager #(
        parameter             BOARD_MAC          =          48'h02_00_c0_a8_0a_0a           ,
        parameter             BOARD_IP           =          {8'd192,8'd168,8'd2,8'd20}      ,
        parameter             PORT               =          16'h00_24              
    )
    (
        input                   aclk                           ,
        input                   areset                         ,

        input                   send_syn_rcvd                  ,
        input                   send_fin_1                     ,
        input                   send_fin_2                     ,
        input        [31:0]     tx_ip                          ,
        input        [47:0]     tx_mac                         ,
        input        [15:0]     tx_port                        ,

        input        [31:0]     seq_number_local               ,
        input        [31:0]     ack_number_local               ,
        output  reg  [31:0]     seq_number_link_new            ,

        input        [15:0]     ip_identification              ,
        output  reg             ip_identification_link_new     ,

        output  reg  [63:0]     tcp_link_tdata                 ,
        output  reg  [7:0]      tcp_link_tkeep                 ,
        output  reg             tcp_link_tvalid                ,
        output  reg             tcp_link_tlast                 ,

        input                   tcp_link_tready                ,
        output  reg             tcp_link_en                    ,
        output  reg             tcp_link_done                  
    );

task reverse_add;
    input   [31:0]  add_number;
    input   [31:0]  old_number;
    inout   [31:0]  new_number;
    reg     [31:0]  data;

    begin
        data = {old_number[7:0], old_number[15:8], old_number[23:16], old_number[31:24]} + add_number ;
        new_number = {data[7:0], data[15:8], data[23:16], data[31:24]};
    end
endtask

// size 必须是偶数
task calc_checksum;
    input   [3 :0] size;
    input   [63:0] data_in;
    inout   [31:0] checksum;
    integer       I;
    reg    [15:0]  data [0:3];

    begin
        data[0] = data_in[15:0];
        data[1] = data_in[31:16];
        data[2] = data_in[47:32];
        data[3] = data_in[63:48];

        for (I = 0; I < size/2; I = I + 1)
        begin
            checksum = checksum + {data[I][7:0], data[I][15:8]};
        end
    end
endtask

// 1:fin_1   2: fin_2    3: syn_ack
reg         [3:0]           send_type;   
reg                         send_fin;
reg                         send_ack;   
reg                         send_syn;  

reg         [31:0]          ip_checksum ;
reg         [31:0]          tcp_checksum;

    localparam IDLE             =       0,
               MAC_HEAD         =       1,
               IP_HEAD          =       2,
               IP_HEAD_SRC_IP   =       3,
               TCP_PORT         =       4,
               SEQ_ACK          =       5,
               WINDOW           =       6,
               DATA             =       7;

    reg     [3:0]       state;

    always @(posedge aclk) begin
        if(areset) begin
            state                     <=          IDLE            ;
            tcp_link_en               <=          0               ;

            ip_identification_link_new <=         0               ;
        end
        else begin
            if (send_syn_rcvd) begin
                tcp_link_en         <=          1           ;

                send_type           <=          3           ;
                send_fin            <=          0           ;
                send_ack            <=          1           ;
                send_syn            <=          1           ;
            end
            else if (send_fin_1) begin
                tcp_link_en         <=          1           ;

                send_type           <=          1           ;
                send_fin            <=          0           ;         // 此处设置为不支持半连接，即三次挥手
                send_ack            <=          1           ;
                send_syn            <=          0           ;
            end
            else if (send_fin_2) begin
                tcp_link_en         <=          1           ;

                send_type           <=          2           ;
                send_fin            <=          1           ;
                send_ack            <=          1           ;
                send_syn            <=          0           ;
            end

            if (tcp_link_tready == 1 & tcp_link_done != 1) begin
                tcp_link_en               <=          0                       ;
                case (state)
                    IDLE : begin
                        tcp_link_tdata          =          {BOARD_MAC[39:32],   BOARD_MAC[47:40],  tx_mac}         ;
                        tcp_link_tkeep          =          8'b1111_1111                                            ;
                        tcp_link_tvalid         =          1                                                       ;
                        tcp_link_tlast          =          0                                                       ;

                        seq_number_link_new     =          0                                                       ;

                        state                   =          MAC_HEAD                                                ;
                        ip_checksum             =          0                                                       ;
                        tcp_checksum            =          0                                                       ;

                        calc_checksum(4, {BOARD_IP[7:0], BOARD_IP[15:8], BOARD_IP[23:16], BOARD_IP[31:24]}, tcp_checksum);
                        calc_checksum(4, tx_ip, tcp_checksum);
                        calc_checksum(2, {8'h06, 8'h00}, tcp_checksum);
                        if (send_type == 3) begin
                            calc_checksum(2, {8'h1c, 8'h00}, tcp_checksum);
                        end
                        else begin
                            calc_checksum(2, {8'h14, 8'h00}, tcp_checksum);
                        end

                    end
                    MAC_HEAD : begin
                        tcp_link_tdata          =          {8'h00, 8'h45, 8'h00, 8'h08, BOARD_MAC[7:0], BOARD_MAC[15:8], BOARD_MAC[23:16], BOARD_MAC[31:24]}         ;
                        tcp_link_tkeep          =          8'b1111_1111                                            ;
                        tcp_link_tvalid         =          1                                                       ;
                        tcp_link_tlast          =          0                                                       ;

                        state                   =          IP_HEAD                                                 ;
                        calc_checksum(2, tcp_link_tdata[63:48], ip_checksum);
                    end
                    IP_HEAD : begin
                        tcp_link_tdata          =          {8'h06, 8'hff, 16'h00_40, ip_identification[7:0], ip_identification[15:8], 16'h28_00}         ;
                        tcp_link_tkeep          =          8'b1111_1111                                            ;
                        tcp_link_tvalid         =          1                                                       ;
                        tcp_link_tlast          =          0                                                       ;

                        state                   =          IP_HEAD_SRC_IP                                          ;
                        if (send_type == 3) begin
                            tcp_link_tdata[15:0] = 16'h30_00;
                        end 

                        calc_checksum(8, tcp_link_tdata, ip_checksum);
                    end
                    IP_HEAD_SRC_IP : begin
                        //ip首部校验和全0
                        tcp_link_tdata          =          {tx_ip[15:0], BOARD_IP[7:0], BOARD_IP[15:8], BOARD_IP[23:16], BOARD_IP[31:24], 16'h00_00}         ;
                        tcp_link_tkeep          =          8'b1111_1111                                            ;
                        tcp_link_tvalid         =          1                                                       ;
                        tcp_link_tlast          =          0                                                       ;

                        state                   =          TCP_PORT                                                ;

                        calc_checksum(8, tcp_link_tdata, ip_checksum);
                        calc_checksum(2, tx_ip[31:16], ip_checksum);
                        ip_checksum = ip_checksum[31:16] + ip_checksum[15:0];
                        ip_checksum = ip_checksum[31:16] + ip_checksum[15:0];
                        tcp_link_tdata[15:0] = {~ip_checksum[7:0], ~ip_checksum[15:8]};

                    end
                    TCP_PORT : begin
                        tcp_link_tdata          =          {seq_number_local[15:0], tx_port, PORT[7:0], PORT[15:8], tx_ip[31:16]}         ;
                        tcp_link_tkeep          =          8'b1111_1111                                            ;
                        tcp_link_tvalid         =          1                                                       ;
                        tcp_link_tlast          =          0                                                       ;

                        state                   =          SEQ_ACK                                                 ;
                        calc_checksum(6, tcp_link_tdata[63:16], tcp_checksum);
                    end
                    SEQ_ACK : begin
                        tcp_link_tdata          =          {3'b000, send_ack, 2'b00, send_syn, send_fin, 8'h50, ack_number_local, seq_number_local[31:16]}         ;
                        tcp_link_tkeep          =          8'b1111_1111                                            ;
                        tcp_link_tvalid         =          1                                                       ;
                        tcp_link_tlast          =          0                                                       ;

                        state                   =          WINDOW                                                  ;
                        if (send_type == 3) begin
                            tcp_link_tdata[55:48] = 8'h70;
                        end 

                        calc_checksum(8, tcp_link_tdata, tcp_checksum);
                    end
                    WINDOW : begin
                        // window窗口初始固定20_14 << 8
                        tcp_link_tdata          =          {16'h00_00, 16'h00_00, 16'h00_00, 16'h14_20}            ;
                        tcp_link_tkeep          =          8'b1111_1111                                            ;
                        tcp_link_tvalid         =          1                                                       ;
                        tcp_link_tlast          =          0                                                       ;

                        if (send_type == 3) begin
                            tcp_link_tdata[63:48] = 16'h04_02;
                        end

                        state                   =          DATA                                                    ;

                        calc_checksum(8, tcp_link_tdata, tcp_checksum);
                        if (send_type == 3) begin
                            calc_checksum(6, {16'h08_03, 16'h03_01, 16'hb4_05}, tcp_checksum);
                        end

                        tcp_checksum = tcp_checksum[31:16] + tcp_checksum[15:0];
                        tcp_checksum = tcp_checksum[31:16] + tcp_checksum[15:0];
                        tcp_link_tdata[31:16] = {~tcp_checksum[7:0], ~tcp_checksum[15:8]};

                        ip_identification_link_new  =   1;
                    end
                    DATA : begin
                        if (send_type == 3) begin
                            tcp_link_tdata          =          {16'h00_00, 16'h08_03, 16'h03_01, 16'hb4_05}            ;
                            tcp_link_tkeep          =          8'b0011_1111                                            ;
                        end
                        else begin
                            tcp_link_tdata          =           64'b0;
                            tcp_link_tkeep          =           8'b0000_1111;
                        end     
                        tcp_link_tvalid         =          1                                                       ;
                        tcp_link_tlast          =          1                                                       ;

                        state                   =          IDLE                                                    ;
                        tcp_link_done           =          1                                                       ;
                        if (send_syn | send_fin) begin
                            seq_number_link_new     =           1                                                   ;
                        end
                        
                        ip_identification_link_new  =  0;
                    end
                endcase
            end
            else begin
                tcp_link_tdata            <=          0                                                               ;
                tcp_link_tkeep            <=          8'h0                                                            ;
                tcp_link_tvalid           <=          0                                                               ;
                tcp_link_tlast            <=          0                                                               ;

                tcp_link_done             <=          0                                                               ;
                seq_number_link_new       <=          0                                                               ;
            end
        end 
    end

endmodule
