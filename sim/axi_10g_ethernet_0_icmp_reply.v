`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/14 17:06:15
// Design Name: 
// Module Name: axi_10g_ethernet_0_icmp_reply
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


module axi_10g_ethernet_0_icmp_reply #(
    parameter             BOARD_MAC          =          48'h02_00_c0_a8_0a_0a,
    parameter             BOARD_IP           =          {8'd192,8'd168,8'd2,8'd20}
)
(
    input                           aclk                                ,          
    input                           areset                              ,       

    input                           tx_icmp_en                          ,
    input               [47:0]      icmp_src_mac                        ,
    input               [31:0]      icmp_src_ip                         ,
    input               [15:0]      icmp_src_identifier                 ,
    input               [15:0]      icmp_src_sequence_number            ,
    input               [255:0]     icmp_src_data                       ,

    output      reg     [63:0]      tx_axis_tdata                       ,
    output      reg     [ 7:0]      tx_axis_tkeep                       ,
    output      reg                 tx_axis_tvalid                      ,
    output      reg                 tx_axis_tlast                       ,

    input                           icmp_reply_tready                   ,
    output      reg                 icmp_reply_en                       ,
    output      reg                 icmp_reply_done
);

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

localparam MAC_HEAD_1       =       0,
           MAC_HEAD_2       =       1,
           IP_HEAD_1        =       2,
           IP_HEAD_2        =       3,
           ICMP_HEAD        =       4,
           DATA1            =       5,
           DATA2            =       6,
           DATA3            =       7,
           DATA4            =       8,
           DATA5            =       9;

reg         [47:0]          icmp_src_mac_reg             ;
reg         [31:0]          icmp_src_ip_reg              ;
reg         [15:0]          icmp_src_identifier_reg      ;
reg         [15:0]          icmp_src_sequence_number_reg ;
reg         [255:0]         icmp_src_data_reg            ;

reg         [ 3:0]          state       ;
reg         [31:0]          ip_checksum ;
reg         [31:0]          icmp_checksum;

always @(posedge aclk) begin
    if (areset) begin
        icmp_src_mac_reg             <=          0                       ;
        icmp_src_ip_reg              <=          0                       ;
        icmp_src_identifier_reg      <=          0                       ;
        icmp_src_sequence_number_reg <=          0                       ;
        icmp_src_data_reg            <=          0                       ;
    end
    else begin
        if (tx_icmp_en) begin
            icmp_src_mac_reg             <=          icmp_src_mac             ;
            icmp_src_ip_reg              <=          icmp_src_ip              ;
            icmp_src_identifier_reg      <=          icmp_src_identifier      ;
            icmp_src_sequence_number_reg <=          icmp_src_sequence_number ;
            icmp_src_data_reg            <=          icmp_src_data            ;
        end
    end
end

always @(posedge aclk) begin
    if (areset) begin
        state                       <=          MAC_HEAD_1              ;
        icmp_reply_en               <=          0                       ;

    end 
    if (tx_icmp_en == 1) begin
        icmp_reply_en               <=          1                       ;
    end

    if (icmp_reply_tready == 1 & icmp_reply_done != 1) begin
        icmp_reply_en               <=          0                       ;

        case (state)
            MAC_HEAD_1 : begin
                tx_axis_tdata           =          {BOARD_MAC[39:32],   BOARD_MAC[47:40],    icmp_src_mac_reg}     ;
                tx_axis_tkeep           =          8'b1111_1111                                                    ;
                tx_axis_tvalid          =          1                                                               ;
                tx_axis_tlast           =          0                                                               ;

                state                   =          MAC_HEAD_2                                                     ;
                
                ip_checksum  = 32'b0;
                icmp_checksum= 32'b0;
            end                    
            MAC_HEAD_2 : begin
                tx_axis_tdata           =          {8'h00, 8'h45, 8'h00, 8'h08, BOARD_MAC[7:0], BOARD_MAC[15:8], BOARD_MAC[23:16], BOARD_MAC[31:24]}    ;
                tx_axis_tkeep           =          8'b1111_1111                                                    ;
                tx_axis_tvalid          =          1                                                               ;
                tx_axis_tlast           =          0                                                               ;

                state                   =          IP_HEAD_1                                                       ;

                calc_checksum(2, tx_axis_tdata[63:48], ip_checksum);
            end
            IP_HEAD_1 : begin
                tx_axis_tdata           =          {8'h01, 8'h40, 8'h00, 8'h00, 8'h19, 8'h79, 8'h3c, 8'h00}        ;
                tx_axis_tkeep           =          8'b1111_1111                                                    ;
                tx_axis_tvalid          =          1                                                               ;
                tx_axis_tlast           =          0                                                               ;

                state                   =          IP_HEAD_2                                                       ;

                calc_checksum(8, tx_axis_tdata, ip_checksum);
            end
            IP_HEAD_2 : begin
                tx_axis_tdata           =          {icmp_src_ip_reg[15:0], BOARD_IP[7:0], BOARD_IP[15:8], BOARD_IP[23:16], BOARD_IP[31:24], 8'h00, 8'h00}    ;
                tx_axis_tkeep           =          8'b1111_1111                                                    ;
                tx_axis_tvalid          =          1                                                               ;
                tx_axis_tlast           =          0                                                               ;

                state                   =          ICMP_HEAD                                                       ;

                calc_checksum(8, tx_axis_tdata, ip_checksum);
                calc_checksum(2, icmp_src_ip_reg[31:16], ip_checksum);
                ip_checksum = ip_checksum[31:16] + ip_checksum[15:0];
                ip_checksum = ip_checksum[31:16] + ip_checksum[15:0];
                tx_axis_tdata[15:0] = {~ip_checksum[7:0], ~ip_checksum[15:8]};
            end
            ICMP_HEAD : begin
                tx_axis_tdata           =          {icmp_src_identifier_reg, 8'h00, 8'h00, 8'h00, 8'h00,  icmp_src_ip_reg[31:16]}                        ;
                tx_axis_tkeep           =          8'b1111_1111                                                    ;
                tx_axis_tvalid          =          1                                                               ;
                tx_axis_tlast           =          0                                                               ;

                state                   =          DATA1                                                           ;

                calc_checksum(8, {icmp_src_sequence_number_reg, tx_axis_tdata[63:16]}, icmp_checksum);
                calc_checksum(8, icmp_src_data_reg[63:0], icmp_checksum);
                calc_checksum(8, icmp_src_data_reg[127:64], icmp_checksum);
                calc_checksum(8, icmp_src_data_reg[191:128], icmp_checksum);
                calc_checksum(8, icmp_src_data_reg[255:192], icmp_checksum);
                icmp_checksum = icmp_checksum[31:16] + icmp_checksum[15:0];
                icmp_checksum = icmp_checksum[31:16] + icmp_checksum[15:0];
                tx_axis_tdata[47:32] = {~icmp_checksum[7:0], ~icmp_checksum[15:8]};
            end
            DATA1 : begin
                tx_axis_tdata           =          {icmp_src_data_reg[47:0],   icmp_src_sequence_number_reg}       ;
                tx_axis_tkeep           =          8'b1111_1111                                                    ;
                tx_axis_tvalid          =          1                                                               ;
                tx_axis_tlast           =          0                                                               ;

                state                   =          DATA2                                                           ;
            end
            DATA2 : begin
                tx_axis_tdata           =          icmp_src_data_reg[111:48]                                       ;
                tx_axis_tkeep           =          8'b1111_1111                                                    ;
                tx_axis_tvalid          =          1                                                               ;
                tx_axis_tlast           =          0                                                               ;

                state                   =          DATA3                                                           ;
            end
            DATA3 : begin
                tx_axis_tdata           =          icmp_src_data_reg[175:112]                                      ;
                tx_axis_tkeep           =          8'b1111_1111                                                    ;
                tx_axis_tvalid          =          1                                                               ;
                tx_axis_tlast           =          0                                                               ;

                state                   =          DATA4                                                           ;
            end
            DATA4 : begin
                tx_axis_tdata           =          icmp_src_data_reg[239:176]                                      ;
                tx_axis_tkeep           =          8'b1111_1111                                                    ;
                tx_axis_tvalid          =          1                                                               ;
                tx_axis_tlast           =          0                                                               ;

                state                   =          DATA5                                                           ;
            end
            DATA5 : begin
                tx_axis_tdata           =          {48'h07_07_07_07_07_07, icmp_src_data_reg[255:240]}             ;
                tx_axis_tkeep           =          8'h03                                                           ;
                //tx_axis_tdata           =          {56'h07_07_07_07_07, icmp_src_data_reg[255:248]}             ;
                //tx_axis_tkeep           =          8'b0000_0001                                                           ;
                tx_axis_tvalid          =          1                                                               ;
                tx_axis_tlast           =          1                                                               ;

                state                   =          MAC_HEAD_1                                                      ;

                icmp_reply_done         =          1                                                               ;
            end
        endcase
    end
    else begin
        tx_axis_tdata            <=          0                                                               ;
        tx_axis_tkeep            <=          8'h0                                                            ;
        tx_axis_tvalid           <=          0                                                               ;
        tx_axis_tlast            <=          0                                                               ;
        
        icmp_reply_done          <=          0                                                               ;
    end
end

endmodule
