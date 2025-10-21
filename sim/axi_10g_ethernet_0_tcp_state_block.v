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
/*

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
*/