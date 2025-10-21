`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/17 16:31:11
// Design Name: 
// Module Name: axi_10g_ethernet_0_tcp_tx_block
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


module axi_10g_ethernet_0_tcp_tx_block #(
        parameter             BOARD_MAC          =          48'h02_00_c0_a8_0a_0a           ,
        parameter             BOARD_IP           =          {8'd192,8'd168,8'd2,8'd20}      ,
        parameter             PORT               =          16'h00_24                       ,

        parameter             RAM_ADDR_WIDTH     =          11                              ,

        parameter             TCP_DATA_LENGTH    =          40                              ,

        parameter             FRAME_TOTAL_LENGTH =          (54 + TCP_DATA_LENGTH + 7) / 8 + 1 ,    //190            // 总长度：一个8B 时间戳 + 完整报文8B数
        parameter   [15:0]    TOTAL_LENGTH       =          TCP_DATA_LENGTH + 40
    )
    (
        input                   aclk                           ,
        input                   areset                         ,

        input        [31:0]     seq_number_local               ,   // 本机seq
        input        [31:0]     ack_number_local               ,   // 本机ack
        input        [31:0]     ack_number_opposite            ,   // 对方对本机的ack_number
        output  reg  [31:0]     seq_number_data_new            ,   // 发送报文长度

        input        [15:0]     rx_window_size                 ,

        input        [15:0]     ip_identification              ,
        output  reg             ip_identification_data_new     ,

        input                   established_moment             ,

        input        [31:0]     tx_ip                          ,
        input        [47:0]     tx_mac                         ,
        input        [15:0]     tx_port                        ,
        input        [3:0]      tcp_state                      ,

        input        [7:0]      now_shift_count                ,
        input        [15:0]     now_opposite_window            ,
        input                   now_acked                      ,
        input        [15:0]     data_len                       ,

        input        [63:0]     link_clk_cnt                   ,

        input                   rx_user_tready                 ,

        input                   tx_user_tvalid                    ,
        output  reg             tx_user_tready                    ,
        input        [63:0]     tx_user_tdata                     ,
        input        [7:0]      tx_user_tkeep                     ,

        output  reg             user_checksum_rd_en            ,
        input        [15:0]     user_checksum_dout             ,              
        input                   user_checksum_empty            ,

        output  reg             clk_en_a                       ,
        output  reg  [RAM_ADDR_WIDTH-1:0]      wr_addr                        ,  
        output  reg  [67:0]     dina                           ,  
        output  reg             clk_en_b                       ,  
        output  reg  [RAM_ADDR_WIDTH-1:0]      rd_addr                        ,  
        input        [67:0]     doutb                          ,  

        output  reg  [63:0]     tcp_tx_tdata                   ,
        output  reg  [7:0]      tcp_tx_tkeep                   ,
        output  reg             tcp_tx_tvalid                  ,
        output  reg             tcp_tx_tlast                   ,

        input                   tcp_tx_tready                  ,
        output  reg             tcp_tx_en                      ,
        output  reg             tcp_tx_done                    ,

        output  reg             disconnect_signal
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

// size 必须是偶数 <=20
task calc_checksum;
    input   [4 :0] size;
    input   [159:0] data_in;
    inout   [31:0] checksum;
    integer       I;
    reg    [15:0]  data [0:9];

    begin
        data[0] = data_in[15:0];
        data[1] = data_in[31:16];
        data[2] = data_in[47:32];
        data[3] = data_in[63:48];
        data[4] = data_in[79:64];
        data[5] = data_in[95:80];
        data[6] = data_in[111:96];
        data[7] = data_in[127:112];
        data[8] = data_in[143:128];
        data[9] = data_in[159:144];

        for (I = 0; I < size/2; I = I + 1)
        begin
            checksum = checksum + {data[I][7:0], data[I][15:8]};
        end
    end
endtask

task add_data_to_reg;
    input [63:0]  data_in;
    input [7:0]   keep_in;
    inout [135:0] data_out;

    reg [7:0] data_cnt;
    reg [3:0] keep_to_cnt;
    begin
        data_cnt = data_out[135:128];
        case (keep_in)
            8'b0000_0000 : begin
                keep_to_cnt = 4'd0;
            end
            8'b0000_0001 : begin
                keep_to_cnt = 4'd1;
            end
            8'b0000_0011 : begin
                keep_to_cnt = 4'd2;
            end
            8'b0000_0111 : begin
                keep_to_cnt = 4'd3;
            end
            8'b0000_1111 : begin
                keep_to_cnt = 4'd4;
            end
            8'b0001_1111 : begin
                keep_to_cnt = 4'd5;
            end
            8'b0011_1111 : begin
                keep_to_cnt = 4'd6;
            end
            8'b0111_1111 : begin
                keep_to_cnt = 4'd7;
            end
            8'b1111_1111 : begin
                keep_to_cnt = 4'd8;
            end
        endcase

        case (data_cnt)
            8'b0000_0000 : begin
                data_out[135:128] = data_out[135:128] + keep_to_cnt;
                data_out[127:0] = {64'b0, data_in[63:0]};
            end
            8'b0000_0001 : begin
                data_out[135:128] = data_out[135:128] + keep_to_cnt;
                data_out[127:8] = {56'b0, data_in[63:0]};
            end
            8'b0000_0010 : begin
                data_out[135:128] = data_out[135:128] + keep_to_cnt;
                data_out[127:16] = {48'b0, data_in[63:0]};
            end
            8'b0000_0011 : begin
                data_out[135:128] = data_out[135:128] + keep_to_cnt;
                data_out[127:24] = {40'b0, data_in[63:0]};
            end
            8'b0000_0100 : begin
                data_out[135:128] = data_out[135:128] + keep_to_cnt;
                data_out[127:32] = {32'b0, data_in[63:0]};
            end
            8'b0000_0101 : begin
                data_out[135:128] = data_out[135:128] + keep_to_cnt;
                data_out[127:40] = {24'b0, data_in[63:0]};
            end
            8'b0000_0110 : begin
                data_out[135:128] = data_out[135:128] + keep_to_cnt;
                data_out[127:48] = {16'b0, data_in[63:0]};
            end
            8'b0000_0111 : begin
                data_out[135:128] = data_out[135:128] + keep_to_cnt;
                data_out[127:56] = {8'b0, data_in[63:0]};
            end
            8'b0000_1000 : begin
                data_out[135:128] = data_out[135:128] + keep_to_cnt;
                data_out[127:64] = data_in[63:0];
            end
        endcase
    end
endtask

    reg [63:0] judge_time_temp;
    reg [63:0] diff_time_temp;

    // 全部大端
    function check_seq_acked_or_not(input reg [31:0] send_seq, input reg [31:0] acked_opposite, input reg [31:0] start_seq);
        if (acked_opposite >= start_seq) begin
            if (send_seq >= start_seq & send_seq <= acked_opposite) begin
                check_seq_acked_or_not = 1'b1;
            end
            else begin
                check_seq_acked_or_not = 1'b0;
            end
        end
        else begin
            if (send_seq > acked_opposite & send_seq < start_seq) begin
                check_seq_acked_or_not = 1'b0;
            end
            else begin
                check_seq_acked_or_not = 1'b1;
            end
        end
    endfunction

    // localparam RAM_ADDR_WIDTH = 10;
    localparam ram_depth = 2 ** RAM_ADDR_WIDTH;

    (* mark_debug = "true" *)reg [3:0] state;
    (* mark_debug = "true" *)reg [3:0] tx_state;
    (* mark_debug = "true" *)reg [3:0] head_state;

    (* mark_debug = "true" *)wire [RAM_ADDR_WIDTH-1:0]    diff_addr;

    (* mark_debug = "true" *)reg [31:0] tcp_checksum;
    (* mark_debug = "true" *)reg [31:0] ip_checksum;
    reg [15:0] tcp_length;
    (* mark_debug = "true" *)reg [15:0] tcp_get_length;  

    (* mark_debug = "true" *)reg [135:0] Tx_data_reg;

    wire [256:0] tx_window_size;
    //wire [15:0] rx_window_size;
    wire [256:0] now_send;

    //assign  rx_window_size  =   (rx_user_tready) ? 16'h20_14 : 0;

    reg [63:0] tx_time_last;

    (* mark_debug = "true" *)reg [31:0] ack_number_already; // 本机对对方的ack_number
    (* mark_debug = "true" *)reg [31:0] send_window_start;  // 滑动窗口start的seq

    (* mark_debug = "true" *)reg [3:0]  ack_state;     
    (* mark_debug = "true" *)reg [3:0]  retransmission_state;   
    (* mark_debug = "true" *)reg [3:0]  clear_state;    // 清除已ack报文状态机

    (* mark_debug = "true" *)reg [RAM_ADDR_WIDTH-1:0] store_addr_start;  // start == end 说明空
    (* mark_debug = "true" *)reg [RAM_ADDR_WIDTH-1:0] store_addr_end;  
    (* mark_debug = "true" *)reg [63:0] store_frame_number; 

    reg [67:0]           doutb_temp;
    (* mark_debug = "true" *)reg [31:0]           seq_number_local_temp;

    (* mark_debug = "true" *)reg now_acked_reg;
    (* mark_debug = "true" *)reg [15:0] data_len_reg;

    (* mark_debug = "true" *)reg debug_signal;

    (* mark_debug = "true" *)reg [5:0] continue_time;


    always @(retransmission_state == 4'b0001 or areset) begin
        // 超时判定固定采用 0.1s -- 0.2s -- 0.4s -- 0.8s -- 1.6s
        // 时间戳前缀1001 1010 1011 1100 1101 与data前缀区分
        if (retransmission_state == 4'b0001) begin
            case (doutb[67:64])
                4'b1001 : begin
                    judge_time_temp = 64'd156_250_00;  //64'd46_875_000;   //156_250 * 300;
                end
                4'b1010 : begin
                    judge_time_temp = 64'd312_500_00;  //64'd93_750_000;   //156_250 * 600;
                end
                4'b1011 : begin
                    judge_time_temp = 64'd625_000_00;  //64'd187_500_000;  //156_250 * 1200;
                end
                4'b1100 : begin
                    judge_time_temp = 64'd1_250_000_00;    //64'd375_000_000;  //156_250 * 2400;
                end
                4'b1101 : begin
                    judge_time_temp = 64'd2_500_000_00;    //64'd750_000_000;  //156_250 * 4800;
                end
                default : begin
                    //judge_time_temp = 64'd156_250_000;
                end
            endcase

            if (doutb[67:64] > 4'b1101) begin
                //disconnect_signal   =   1;
            end

            diff_time_temp = link_clk_cnt - doutb[63:0];
        end

        if (areset) begin
            disconnect_signal   =   0;
            judge_time_temp     =   0;
        end
    end

    assign diff_addr           =           ram_depth - 1 - (store_addr_end + ram_depth - store_addr_start) % ram_depth;
    assign tx_window_size      =           {now_opposite_window[7:0], now_opposite_window[15:8]} * (2**now_shift_count);
    assign now_send            =           store_frame_number * TOTAL_LENGTH;

    always @(posedge aclk) begin
        if (head_state == 0 && ack_state == 0) begin
            ip_checksum     <=  0   ;
        end
        else if (head_state) begin
            case (head_state)
                4'b0001 : begin
                    calc_checksum(20, {tx_ip, BOARD_IP[7:0], BOARD_IP[15:8], BOARD_IP[23:16], BOARD_IP[31:24], 16'h00_00, 8'h06, 8'hff, 16'h00_40, ip_identification[7:0], ip_identification[15:8], TOTAL_LENGTH[7:0], TOTAL_LENGTH[15:8], 8'h00, 8'h45}, ip_checksum);
                end
                4'b0010 : begin
                    ip_checksum <= ip_checksum[31:16] + ip_checksum[15:0];
                end
                4'b0011 : begin
                    ip_checksum <= ip_checksum[31:16] + ip_checksum[15:0];
                end
            endcase
        end
        else begin
            case(ack_state)
                4'b0001 : begin
                    calc_checksum(20, {tx_ip, BOARD_IP[7:0], BOARD_IP[15:8], BOARD_IP[23:16], BOARD_IP[31:24], 16'h00_00, 8'h06, 8'hff, 16'h00_40, ip_identification[7:0], ip_identification[15:8], 16'h28_00, 8'h00, 8'h45}, ip_checksum);
                end
                4'b0010 : begin
                    ip_checksum <= ip_checksum[31:16] + ip_checksum[15:0];
                end
                4'b0011 : begin
                    ip_checksum <= ip_checksum[31:16] + ip_checksum[15:0];
                end
            endcase
        end
    end

    always @(posedge aclk) begin
        if (head_state == 0 && ack_state == 0) begin
            tcp_checksum     <=  0   ;
        end
        else if (head_state) begin
            case (head_state)
                4'b0001 : begin
                    tcp_checksum        <=          user_checksum_dout;
                end
                4'b0010 : begin
                    calc_checksum(12, {tcp_length[7:0], tcp_length[15:8], 8'h06, 8'h00, tx_ip, BOARD_IP[7:0], BOARD_IP[15:8], BOARD_IP[23:16], BOARD_IP[31:24]}, tcp_checksum);
                end
                4'b0011 : begin
                    calc_checksum(20, {16'h00_00, 16'h00_00, rx_window_size[7:0], rx_window_size[15:8], 8'b0001_0000, 8'h50, ack_number_local, seq_number_local[31:16], seq_number_local[15:0], tx_port, PORT[7:0], PORT[15:8]}, tcp_checksum);
                end
                4'b0100 : begin
                    tcp_checksum <= tcp_checksum[31:16] + tcp_checksum[15:0];
                end
                4'b0101 : begin
                    tcp_checksum <= tcp_checksum[31:16] + tcp_checksum[15:0];
                end
            endcase
        end
        else begin
            case(ack_state)
                4'b0001 : begin
                    calc_checksum(12, {8'h14, 8'h00, 8'h06, 8'h00, tx_ip, BOARD_IP[7:0], BOARD_IP[15:8], BOARD_IP[23:16], BOARD_IP[31:24]}, tcp_checksum);
                end
                4'b0010 : begin
                    calc_checksum(20, {16'h00_00, 16'h00_00, rx_window_size[7:0], rx_window_size[15:8], 4'b0001, 4'b0000, 8'h50, ack_number_local, seq_number_local[31:16], seq_number_local[15:0], tx_port, PORT[7:0], PORT[15:8]}, tcp_checksum);
                end
                4'b0011 : begin
                    tcp_checksum <= tcp_checksum[31:16] + tcp_checksum[15:0];
                end
                4'b0100 : begin
                    tcp_checksum <= tcp_checksum[31:16] + tcp_checksum[15:0];
                end
            endcase
        end
    end

    always @(posedge aclk) begin
        if (areset | established_moment) begin
            state           <=          4'b0000           ;
            head_state      <=          4'b0000           ;
            clk_en_a        <=          0           ;
            clk_en_b        <=          0           ;

            tcp_length      <=          0           ;

            wr_addr         <=          {RAM_ADDR_WIDTH{1'b1}}           ;
            rd_addr         <=          0           ;

            tcp_tx_en       <=          0           ;

            now_acked_reg   <=          0           ;

            store_addr_start<=          0           ;
            store_addr_end  <=          0           ;  
            store_frame_number<=        0           ;

            send_window_start   <=   1   ;

            debug_signal    <=   0;
            tx_user_tready  <=   0;
        end 
        else begin
            if (continue_time >= 30) begin
                debug_signal    <=   1;
            end

            /*if (clk_en_a) begin
                wr_addr         =          (wr_addr +  1) % ram_depth            ;
            end*/

            /*if (established_moment) begin
                send_window_start   =   1   ;
            end*/

            if (now_acked) begin
                now_acked_reg <= 1 ;
                data_len_reg    <=  data_len;
            end

            case (state)
                4'b0000 : begin
                    seq_number_data_new     <=       0              ;
                    clk_en_a                <=       0              ;

                    tcp_tx_tdata            <=       0              ;
                    tcp_tx_tkeep            <=       8'h0           ;
                    tcp_tx_tvalid           <=       0              ;
                    tcp_tx_tlast            <=       0              ;
                    tcp_tx_done             <=       0              ;

                    Tx_data_reg             <=       0              ;
                    
                    continue_time           <=       0              ;


                    // 能发就发
                    if (diff_addr >= FRAME_TOTAL_LENGTH + 1 & tcp_state == 4'd3 & rx_window_size > 0 & tx_window_size > 0 & tx_window_size - now_send > TCP_DATA_LENGTH & user_checksum_empty == 0
                    ) begin
                    // & (tx_time_last == 0 || link_clk_cnt - tx_time_last >= 64'd156_2)) begin
                    //& (tx_time_last == 0 || dif_time({year, month, day, hour, minute, second, clk_cnt}, tx_time_last) == 1)) begin
                        tx_time_last        <=          link_clk_cnt                    ;

                        tcp_tx_en           <=          1'b1                            ;
                        state               <=          4'b0001                         ;
                        head_state          <=          4'b0000                         ;
                        tx_state            <=          4'b0001                         ;
                    end 
                    else if (tcp_state == 4'd3) begin    
                        if (now_acked_reg) begin
                            if (tx_window_size == 0 | ack_number_already != ack_number_local | data_len_reg) begin  // 对方发送zero_window报文或者带数据报文
                                state       <=          4'b1010     ;
                                tcp_tx_en   <=          1           ;
                                ack_state   <=          4'b0000     ;
                            end
                            else if (store_frame_number != 0) begin                                                             // 对方发送ack报文，准备清除
                                clk_en_b    <=          1           ;
                                rd_addr     <=          store_addr_start;
                                state       <=          4'b1110     ;
                                clear_state <=          4'b0000           ;
                            end

                            now_acked_reg   <=          0           ;
                            data_len_reg    <=          0           ;
                        end   
                        else if (store_addr_end != store_addr_start) begin                  // 监视时间戳，超时重传
                            clk_en_b            <=           1           ;
                            rd_addr             <=           store_addr_start;
                            state               <=           4'b1100     ;
                            retransmission_state<=           4'b0000     ;
                        end                                     
                    end
                end
                
                4'b0001 : begin
                    case(tx_state)
                        // 先存时间戳
                        4'b0001 :begin
                            continue_time <= continue_time+1;

                            tcp_length          <=          20 + TCP_DATA_LENGTH ;

                            if (tcp_tx_tready == 1 & tcp_tx_done == 0) begin
                                head_state          <=          4'b0001     ;
                                tx_state            <=          4'b0010     ;
                                tcp_tx_en           <=          0           ;

                                clk_en_a            <=          1           ;
                                wr_addr             <=          wr_addr +  1;
                                dina                <=          {4'b1001, link_clk_cnt}       ;   // 时间戳信息
                            end
                        end
                        // 存mac头，ip头，tcp头（要是tkeep可以随意指定就简单了）
                        4'b0010 : begin          
                            case (head_state) 
                                4'b0001 : begin
                                    clk_en_a            <=          1           ;
                                    wr_addr             <=          wr_addr +  1;
                                    dina                <=          {4'b1000, BOARD_MAC[39:32],   BOARD_MAC[47:40],  tx_mac}         ;
                                    head_state          <=          4'b0010      ;

                                    tcp_tx_tdata        <=           {BOARD_MAC[39:32],   BOARD_MAC[47:40],  tx_mac}      ;
                                    tcp_tx_tvalid       <=           1               ;
                                    tcp_tx_tkeep        <=           8'b1111_1111    ;
                                    tcp_tx_tlast        <=           0               ;

                                    user_checksum_rd_en <=          1                               ;
                                end
                                4'b0010 : begin
                                    clk_en_a            <=          1           ;
                                    wr_addr             <=          wr_addr +  1;
                                    dina                <=          {4'b1000, 8'h00, 8'h45, 8'h00, 8'h08, BOARD_MAC[7:0], BOARD_MAC[15:8], BOARD_MAC[23:16], BOARD_MAC[31:24]}         ;
                                    head_state          <=          4'b0011      ;

                                    tcp_tx_tdata        <=           {8'h00, 8'h45, 8'h00, 8'h08, BOARD_MAC[7:0], BOARD_MAC[15:8], BOARD_MAC[23:16], BOARD_MAC[31:24]}      ;
                                    tcp_tx_tvalid       <=           1               ;
                                    tcp_tx_tkeep        <=           8'b1111_1111    ;
                                    tcp_tx_tlast        <=           0               ;

                                    user_checksum_rd_en <=           0               ;
                                end
                                4'b0011 : begin
                                    clk_en_a            <=          1           ;
                                    wr_addr             <=          wr_addr +  1;
                                    dina                <=          {4'b1000, 8'h06, 8'hff, 16'h00_40, ip_identification[7:0], ip_identification[15:8], TOTAL_LENGTH[7:0], TOTAL_LENGTH[15:8]}         ;
                                    head_state          <=          4'b0100      ;

                                    tcp_tx_tdata        <=           {8'h06, 8'hff, 16'h00_40, ip_identification[7:0], ip_identification[15:8], TOTAL_LENGTH[7:0], TOTAL_LENGTH[15:8]}      ;
                                    tcp_tx_tvalid       <=           1               ;
                                    tcp_tx_tkeep        <=           8'b1111_1111    ;
                                    tcp_tx_tlast        <=           0               ;
                                end
                                4'b0100 : begin
                                    clk_en_a            <=          1           ;
                                    wr_addr             <=          wr_addr +  1;
                                    dina                <=          {4'b1000, tx_ip[15:0], BOARD_IP[7:0], BOARD_IP[15:8], BOARD_IP[23:16], BOARD_IP[31:24], ~ip_checksum[7:0], ~ip_checksum[15:8]}         ;
                                    head_state          <=          4'b0101      ;

                                    tcp_tx_tdata        <=           {tx_ip[15:0], BOARD_IP[7:0], BOARD_IP[15:8], BOARD_IP[23:16], BOARD_IP[31:24], ~ip_checksum[7:0], ~ip_checksum[15:8]}      ;
                                    tcp_tx_tvalid       <=           1               ;
                                    tcp_tx_tkeep        <=           8'b1111_1111    ;
                                    tcp_tx_tlast        <=           0               ;
                                end
                                4'b0101 : begin
                                    clk_en_a            <=          1           ;
                                    wr_addr             <=          wr_addr +  1;
                                    dina                <=          {4'b1000, seq_number_local[15:0], tx_port, PORT[7:0], PORT[15:8], tx_ip[31:16]}         ;
                                    head_state          <=          4'b0110      ;

                                    tcp_tx_tdata        <=           {seq_number_local[15:0], tx_port, PORT[7:0], PORT[15:8], tx_ip[31:16]}      ;
                                    tcp_tx_tvalid       <=           1               ;
                                    tcp_tx_tkeep        <=           8'b1111_1111    ;
                                    tcp_tx_tlast        <=           0               ;

                                    tx_user_tready      <=         1;
                                    tcp_get_length      <=         8;
                                end
                                4'b0110 : begin
                                    clk_en_a            <=          1           ;
                                    wr_addr             <=          wr_addr +  1;
                                    dina                <=          {4'b1000, 8'b0001_0000, 8'h50, ack_number_local, seq_number_local[31:16]}         ;
                                    ack_number_already  <=          ack_number_local ;
                                    head_state          <=          4'b0111      ;

                                    tcp_tx_tdata        <=           {8'b0001_0000, 8'h50, ack_number_local, seq_number_local[31:16]}      ;
                                    tcp_tx_tvalid       <=           1               ;
                                    tcp_tx_tkeep        <=           8'b1111_1111    ;
                                    tcp_tx_tlast        <=           0               ;

                                    Tx_data_reg[63:0]   <=         tx_user_tdata;
                                    Tx_data_reg[135:128] <=        8;

                                    if (tcp_get_length >= TCP_DATA_LENGTH) begin
                                        tx_user_tready  <=  0;
                                    end
                                    else begin
                                        tcp_get_length  <= tcp_get_length + 8;
                                    end
                                end
                                // 得先来一个2B data，options填充不行
                                4'b0111 : begin
                                    if (Tx_data_reg[135:128] >= 8'd2) begin
                                        clk_en_a            <=          1           ;
                                        wr_addr             <=          wr_addr +  1;
                                        dina <= {4'b1000, Tx_data_reg[15:0], 16'h00_00, ~tcp_checksum[7:0], ~tcp_checksum[15:8], rx_window_size[7:0], rx_window_size[15:8]};

                                        tcp_tx_tdata        <=           {Tx_data_reg[15:0], 16'h00_00, ~tcp_checksum[7:0], ~tcp_checksum[15:8], rx_window_size[7:0], rx_window_size[15:8]}      ;
                                        tcp_tx_tvalid       <=           1               ;
                                        tcp_tx_tkeep        <=           8'b1111_1111    ;
                                        tcp_tx_tlast        <=           0               ;

                                        if (tx_user_tready) begin
                                            Tx_data_reg[135:128] <= Tx_data_reg[135:128] + 6;
                                            Tx_data_reg[111:0] <= {tx_user_tdata, Tx_data_reg[63:16]};
                                        end
                                        else begin
                                            Tx_data_reg[135:128] <= Tx_data_reg[135:128] - 2;
                                            Tx_data_reg[63:0] <= {16'h0, Tx_data_reg[63:16]};
                                        end

                                        if (tcp_get_length >= TCP_DATA_LENGTH) begin
                                            tx_user_tready  <=  0;
                                        end
                                        else begin
                                            tcp_get_length  <= tcp_get_length + 8;
                                        end

                                        head_state          <=          4'b0000         ;
                                        tx_state            <=          4'b0011      ;
                                    end
                                end
                            endcase
                        end
                        // 存data
                        4'b0011 : begin
                            if (tx_user_tready) begin
                                Tx_data_reg[111:0] <= {tx_user_tdata, Tx_data_reg[111:64]};
                            end
                            else begin
                                if (Tx_data_reg[135:128] > 8) begin
                                    Tx_data_reg[135:128] <= Tx_data_reg[135:128] - 8;
                                    Tx_data_reg[127:0] <= {64'h0, Tx_data_reg[127:64]};
                                end
                                else begin
                                    Tx_data_reg <=  0;
                                end
                            end

                            if (tcp_get_length >= TCP_DATA_LENGTH) begin
                                tx_user_tready  <=  0;
                            end
                            else begin
                                tcp_get_length  <= tcp_get_length + 8;
                            end

                            if (Tx_data_reg[135:128]) begin
                                if (Tx_data_reg[135:128] > 8'd8) begin
                                    clk_en_a            <=          1           ;
                                    wr_addr             <=          wr_addr +  1;
                                    dina <= {4'b1000, Tx_data_reg[63:0]};

                                    tcp_tx_tdata        <=           Tx_data_reg[63:0] ;
                                    tcp_tx_tvalid       <=           1               ;
                                    tcp_tx_tkeep        <=           8'b1111_1111    ;
                                    tcp_tx_tlast        <=           0               ;
                                end
                                else begin
                                    clk_en_a            <=          1           ;
                                    wr_addr             <=          wr_addr +  1;
                                    dina <= {Tx_data_reg[131:128], Tx_data_reg[63:0]};

                                    tcp_tx_tdata        <=           Tx_data_reg[63:0]      ;
                                    tcp_tx_tvalid       <=           1               ;
                                    tcp_tx_tlast        <=           1               ;
                                    tcp_tx_done         <=           1               ;

                                    if (Tx_data_reg[131:128] % 2 == 1) begin
                                        case (Tx_data_reg[131:128])
                                            4'b0001 : begin
                                                tcp_tx_tkeep <= 8'b0000_0001 ;
                                            end
                                            4'b0011 : begin
                                                tcp_tx_tkeep <= 8'b0000_0111 ;
                                            end
                                            4'b0101 : begin
                                                tcp_tx_tkeep <= 8'b0001_1111 ;
                                            end
                                            4'b0111 : begin
                                                tcp_tx_tkeep <= 8'b0111_1111 ;
                                            end
                                        endcase
                                    end
                                    else begin
                                        case (Tx_data_reg[131:128])
                                            4'b0000 : begin
                                                //
                                            end
                                            4'b0010 : begin
                                                tcp_tx_tkeep <= 8'b0000_0011 ;
                                            end
                                            4'b0100 : begin
                                                tcp_tx_tkeep <= 8'b0000_1111 ;
                                            end
                                            4'b0110 : begin
                                                tcp_tx_tkeep <= 8'b0011_1111 ;
                                            end
                                            4'b1000 : begin
                                                tcp_tx_tkeep <= 8'b1111_1111 ;
                                            end
                                        endcase
                                    end
                                end
                            end
                            else begin
                                tx_state            <=   4'b0100;
                                ip_identification_data_new  <=  1;
                            end
                        end    
                        // 后续处理
                        4'b0100 : begin
                            store_addr_end          <=   store_addr_end + FRAME_TOTAL_LENGTH;
                            store_frame_number      <=   store_frame_number + 1             ;
                            seq_number_data_new     <=   TCP_DATA_LENGTH                    ;

                            clk_en_a                <=   0                                  ;

                            tx_state                <=   4'b0000                            ;

                            tcp_tx_done             <=   0                                  ;
                            state                   <=   4'b0000                            ;

                            tcp_tx_tdata            <=   0                                  ;   
                            tcp_tx_tvalid           <=   0                                  ;   
                            tcp_tx_tlast            <=   0                                  ;   
                            tcp_tx_tkeep            <=   0                                  ;

                            ip_identification_data_new  <=  0                               ;
                        end
                    endcase
                end

                // ack报文发送逻辑
                4'b1010 : begin
                    continue_time <= continue_time+1;
                    if (tcp_tx_tready == 1 & tcp_tx_done != 1) begin
                        tcp_tx_en   <=   0;
                        ack_state   <=   4'b0001;
                        state       <=   4'b1011;

                    end
                end

                4'b1011 : begin
                    case (ack_state)
                        4'b0001 : begin
                            tcp_tx_tdata            <=      {BOARD_MAC[39:32],   BOARD_MAC[47:40],  tx_mac}                 ;
                            tcp_tx_tvalid           <=      1                                                               ;
                            tcp_tx_tkeep            <=      8'b1111_1111                                                    ;
                            tcp_tx_tlast            <=      0                                                               ;
                            ack_state               <=      4'b0010                                                         ;
                        end
                        4'b0010 : begin
                            tcp_tx_tdata            <=      {8'h00, 8'h45, 8'h00, 8'h08, BOARD_MAC[7:0], BOARD_MAC[15:8], BOARD_MAC[23:16], BOARD_MAC[31:24]}                 ;
                            tcp_tx_tvalid           <=      1                                                               ;
                            tcp_tx_tkeep            <=      8'b1111_1111                                                    ;
                            tcp_tx_tlast            <=      0                                                               ;
                            ack_state               <=      4'b0011                                                         ;
                        end
                        4'b0011 : begin
                            tcp_tx_tdata          <=          {8'h06, 8'hff, 16'h00_40, ip_identification[7:0], ip_identification[15:8], 16'h28_00}         ;
                            tcp_tx_tkeep          <=          8'b1111_1111                                            ;
                            tcp_tx_tvalid         <=          1                                                       ;
                            tcp_tx_tlast          <=          0                                                       ;
                            ack_state             <=          4'b0100                                         ;
                        end
                        4'b0100 : begin
                            //ip首部校验和全0
                            tcp_tx_tdata          <=          {tx_ip[15:0], BOARD_IP[7:0], BOARD_IP[15:8], BOARD_IP[23:16], BOARD_IP[31:24], ~ip_checksum[7:0], ~ip_checksum[15:8]}         ;
                            tcp_tx_tkeep          <=          8'b1111_1111                                            ;
                            tcp_tx_tvalid         <=          1                                                       ;
                            tcp_tx_tlast          <=          0                                                       ;
                            ack_state             <=          4'b0101                                                 ;
                        end
                        4'b0101 : begin
                            tcp_tx_tdata          <=          {seq_number_local[15:0], tx_port, PORT[7:0], PORT[15:8], tx_ip[31:16]}         ;
                            tcp_tx_tkeep          <=          8'b1111_1111                                            ;
                            tcp_tx_tvalid         <=          1                                                       ;
                            tcp_tx_tlast          <=          0                                                       ;
                            ack_state             <=          4'b0110                                                 ;
                        end
                        4'b0110 : begin
                            tcp_tx_tdata          <=          {4'b0001, 4'b0000, 8'h50, ack_number_local, seq_number_local[31:16]}         ;
                            tcp_tx_tkeep          <=          8'b1111_1111                                            ;
                            tcp_tx_tvalid         <=          1                                                       ;
                            tcp_tx_tlast          <=          0                                                       ;
                            ack_state             <=          4'b0111                                                 ;
                        end
                        4'b0111 : begin
                            // window窗口初始固定20_14 << 8
                            tcp_tx_tdata          <=          {16'h00_00, 16'h00_00, ~tcp_checksum[7:0], ~tcp_checksum[15:8], rx_window_size[7:0], rx_window_size[15:8]}            ;
                            tcp_tx_tkeep          <=          8'b1111_1111                                            ;
                            tcp_tx_tvalid         <=          1                                                       ;
                            tcp_tx_tlast          <=          0                                                       ;
                            ack_state             <=          4'b1000                                                    ;
                            ip_identification_data_new  <=   1           ;
                        end
                        4'b1000 : begin
                            tcp_tx_tdata          <=          64'b0;
                            tcp_tx_tkeep          <=          8'b0000_1111;   
                            tcp_tx_tvalid         <=          1                                                       ;
                            tcp_tx_tlast          <=          1                                                       ;
                            ack_state             <=          4'b0000                                                 ;
                            tcp_tx_done           <=          1                                                       ;
                            ack_number_already    <=          ack_number_local                                         ;
                            state                 <=          4'b0000                                                         ;
                            ip_identification_data_new      <=       0       ;
                        end
                    endcase
                end

                4'b1100 : begin
                    case(retransmission_state)
                        // 判断是否超时重传
                        4'b0000 : begin
                            rd_addr <=  rd_addr + 1;
                            retransmission_state <= 4'b0001;
                        end
                        4'b0001 : begin
                            if (diff_time_temp >= judge_time_temp) begin
                                retransmission_state       <=          4'b0010     ;
                                tcp_tx_en                  <=          1           ;

                                clk_en_a                   <=          1           ;
                                dina                       <=          {(doutb[67:64] + 1'b1), link_clk_cnt};
                                wr_addr                    <=           store_addr_start;
                            end
                            else begin
                                clk_en_b                   <=          0           ;
                                state                      <=          4'b0000           ;
                                retransmission_state       <=          4'b0000           ;
                            end
                        end

                        // 超时重传逻辑
                        4'b0010 : begin
                            clk_en_a                   <=          0           ;
                            wr_addr                    <=          store_addr_end   ;

                            if (tcp_tx_tready) begin
                                doutb_temp          <=          doutb       ;
                                rd_addr             <=          rd_addr + 1 ;

                                retransmission_state<=          4'b0011     ;
                            end
                        end
                        4'b0011 : begin
                            clk_en_a            <=          0           ;

                            doutb_temp          <=          doutb       ;    // doutb延迟一个时钟周期，方便判断tdata_last
                            rd_addr             <=          rd_addr + 1 ;
                            retransmission_state<=          4'b0100     ;
                        end
                        4'b0100 : begin
                            if (tcp_tx_tready == 1 & tcp_tx_done != 1) begin
                                tcp_tx_en           <=           0           ;

                                case (doutb_temp[67:64])
                                    4'b0001 : begin
                                        tcp_tx_tkeep    <=       8'b0000_0001;
                                    end
                                    4'b0010 : begin
                                        tcp_tx_tkeep    <=       8'b0000_0011;
                                    end
                                    4'b0011 : begin
                                        tcp_tx_tkeep    <=       8'b0000_0111;
                                    end
                                    4'b0100 : begin
                                        tcp_tx_tkeep    <=       8'b0000_1111;
                                    end
                                    4'b0101 : begin
                                        tcp_tx_tkeep    <=       8'b0001_1111;
                                    end
                                    4'b0110 : begin
                                        tcp_tx_tkeep    <=       8'b0011_1111;
                                    end
                                    4'b0111 : begin
                                        tcp_tx_tkeep    <=       8'b0111_1111;
                                    end
                                    4'b1000 : begin
                                        tcp_tx_tkeep    <=       8'b1111_1111;
                                    end
                                endcase

                                if (rd_addr == store_addr_end + 1 || doutb[67:64] > 8) begin
                                    tcp_tx_tlast            <=   1   ;
                                    tcp_tx_done             <=   1   ;

                                    clk_en_a                <=   0   ;

                                    state                   <=   4'b0000   ;
                                    retransmission_state    <=   4'b0000   ;

                                    //store_addr_end          =   store_addr_end + FRAME_TOTAL_LENGTH;
                                    //store_addr_start        =   store_addr_start + FRAME_TOTAL_LENGTH;
                                end
                                else begin
                                    tcp_tx_tlast    <=   0   ;
                                end

                                rd_addr             <=   rd_addr + 1 ;

                                //clk_en_a            =   1           ;
                                //dina                =   doutb_temp  ;

                                tcp_tx_tdata        <=   doutb_temp[63:0] ;
                                tcp_tx_tvalid       <=   1           ;

                                doutb_temp          <=   doutb       ;
                            end
                            else begin
                                tcp_tx_tdata           <=          0         ;
                                tcp_tx_tkeep           <=          8'h0      ;
                                tcp_tx_tvalid          <=          0         ;
                                tcp_tx_tlast           <=          0         ;
                                tcp_tx_done            <=          0         ;
                            end
                        end
                    endcase
                end

                // 清除已ack报文
                4'b1110 : begin
                    // 一条一条遍历清除，想更快后续可以实现二分
                    case (clear_state)
                        4'b0000 : begin     
                            clear_state <=  4'b0001;
                            rd_addr <=  rd_addr + 1 ;
                        end
                        4'b0001 : begin
                            clear_state <= 4'b0010;      // 时间戳
                            rd_addr <=  rd_addr + 1 ;
                        end
                        4'b0010 : begin
                            clear_state <= 4'b0011;
                            rd_addr <=  rd_addr + 1 ;
                        end
                        4'b0011 : begin
                            clear_state <= 4'b0100;
                            rd_addr <=  rd_addr + 1 ;
                        end
                        4'b0100 : begin
                            clear_state <= 4'b0101;
                            rd_addr <=  rd_addr + 1 ;
                        end
                        4'b0101 : begin
                            clear_state <= 4'b0110;
                            rd_addr <=  rd_addr + 1 ;
                        end
                        4'b0110 : begin
                            clear_state <= 4'b0111;
                            seq_number_local_temp[31:16] <= {doutb[55:48], doutb[63:56]};
                            rd_addr <=  rd_addr + 1 ;
                        end
                        4'b0111 : begin
                            clear_state <= 4'b1000;
                            seq_number_local_temp[15:0] <= {doutb[7:0], doutb[15:8]};
                            rd_addr <=  rd_addr + 1 ;
                        end
                        4'b1000 : begin
                            if (check_seq_acked_or_not(seq_number_local_temp + TCP_DATA_LENGTH, 
                                                        {ack_number_opposite[7:0], ack_number_opposite[15:8], ack_number_opposite[23:16], ack_number_opposite[31:24]}, 
                                                        send_window_start)) begin
                                clear_state <= 4'b1001 ;
                            end
                            else begin
                                //send_window_start <= {ack_number_opposite[7:0], ack_number_opposite[15:8], ack_number_opposite[23:16], ack_number_opposite[31:24]};
                                send_window_start   <=  seq_number_local_temp;
                                clear_state <= 4'b1010 ;
                            end
                        end
                        4'b1001 : begin    
                            store_addr_start <= store_addr_start + FRAME_TOTAL_LENGTH;   // 清除一个报文
                            store_frame_number <= store_frame_number - 1;

                            if (store_frame_number == 1) begin
                                clear_state <= 4'b1010 ;
                                send_window_start   <=  seq_number_local_temp + TCP_DATA_LENGTH;
                            end
                            else begin
                                clear_state <= 4'b0000 ;
                                rd_addr <= store_addr_start;
                            end
                        end
                        4'b1010 : begin
                            clear_state <= 4'b0000 ;
                            state   <=   4'b0000;
                            // 最后处理
                            // send_window_start   =       {ack_number_opposite[7:0], ack_number_opposite[15:8], ack_number_opposite[23:16], ack_number_opposite[31:24]};

                            /*if (seq_number_local_temp < send_window_start) begin
                                debug_signal    <=1;
                            end*/
                        end
                    endcase
                end
                default : begin
                    state   <=  4'b0000;
                end
            endcase
        end
    end

endmodule