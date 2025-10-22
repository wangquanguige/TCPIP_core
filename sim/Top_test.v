`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/12 14:52:02
// Design Name: 
// Module Name: Top
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


module Top_test #(
        parameter           BOARD_MAC          =          48'h02_00_c0_a8_0a_0a           ,
        parameter           BOARD_IP           =          {8'd192,8'd168,8'd10,8'd16}      ,
        parameter           TCP_DATA_LENGTH    =       1456,//40
        parameter           RAM_ADDR_WIDTH     =       14 
    )
    (
    input                   clk,
    input                   GT_DIFF_REFCLK1_0_clk_n,
    input                   GT_DIFF_REFCLK1_0_clk_p,

    // SiTCP Tx Rx
    output                  ETH_TXP, 
    output                  ETH_TXN, 
    input                   ETH_RXP, 
    input                   ETH_RXN,

    input                   s_axis_tvalid,
    output                  s_axis_tready,
    input            [63:0] s_axis_tdata,
    input            [7:0]  s_axis_tkeep,

    output                  m_axis_tvalid,
    input                   m_axis_tready,
    output           [63:0] m_axis_tdata,
    output           [7:0]  m_axis_tkeep,

    output                  coreclk_out,
    output           [3:0]  tcp_state_out
    );

    wire core_ready;

    (* mark_debug = "true" *)wire s_axi_aclk;
    (* mark_debug = "true" *)wire clk_250M;
    (* mark_debug = "true" *)wire clk_156_25M;
    wire reset;
    reg fifo_reset;

    (* mark_debug = "true" *)wire        tx_user_tvalid;
    (* mark_debug = "true" *)wire        tx_user_tready;
    (* mark_debug = "true" *)wire [63:0] tx_user_tdata;
    (* mark_debug = "true" *)wire [7:0]  tx_user_tkeep;

    (* mark_debug = "true" *)wire        rx_user_tvalid;
    (* mark_debug = "true" *)wire        rx_user_tready;
    (* mark_debug = "true" *)wire [63:0] rx_user_tdata;
    (* mark_debug = "true" *)wire [7:0]  rx_user_tkeep;

    (* mark_debug = "true" *)wire            user_checksum_rd_en;
    (* mark_debug = "true" *)wire    [15:0]  user_checksum_dout;
    (* mark_debug = "true" *)wire            user_checksum_empty;

    (* mark_debug = "true" *)reg    [63:0] rx_data_speed_test;
    (* mark_debug = "true" *)reg    [63:0] rx_clk_spped_test;
    (* mark_debug = "true" *)reg           rx_start;

    wire              tx_packet_loss_signal;
    wire              rx_packet_loss_signal;

    wire              tx_packet_start_signal;

    wire              vio_reset;

    vio_0 vio_signal (
      .clk(coreclk_out),                // input wire clk
      .probe_out0(tx_packet_loss_signal),  // output wire [0 : 0] probe_out0
      .probe_out1(rx_packet_loss_signal),
      .probe_out2(tx_packet_start_signal),
      .probe_out3(vio_reset)
   );

    reg         [15:0]      rstn_count;
    always @ (posedge coreclk_out) begin
        if(reset) begin
            rstn_count <= 16'b0;
        end
        else if(rstn_count < 16'd1000)begin
            rstn_count <= rstn_count + 1;
        end
        else if(rstn_count == 16'd1000) begin
            rstn_count <= rstn_count;
        end  
        else begin
            rstn_count <= 16'b0;
        end    
    end
                     
    always @ (posedge coreclk_out) begin   
        if(rstn_count == 16'd1000) begin
            fifo_reset <= 1'b0;
        end  
        else begin
            fifo_reset <= 1'b1;
        end    
    end

    always @ (posedge coreclk_out) begin
        if (rx_user_tkeep) begin
            rx_start    <=  1;
        end
        if (rx_start) begin
            rx_clk_spped_test   <= rx_clk_spped_test + 1;
        end
        if (rx_user_tvalid) begin
            case (rx_user_tkeep)
                8'b0000_0001 : begin
                    rx_data_speed_test  <=  rx_data_speed_test + 1;
                end
                8'b0000_0011 : begin
                    rx_data_speed_test  <=  rx_data_speed_test + 2;
                end
                8'b0000_0111 : begin
                    rx_data_speed_test  <=  rx_data_speed_test + 3;
                end
                8'b0000_1111 : begin
                    rx_data_speed_test  <=  rx_data_speed_test + 4;
                end
                8'b0001_1111 : begin
                    rx_data_speed_test  <=  rx_data_speed_test + 5;
                end
                8'b0011_1111 : begin
                    rx_data_speed_test  <=  rx_data_speed_test + 6;
                end
                8'b0111_1111 : begin
                    rx_data_speed_test  <=  rx_data_speed_test + 7;
                end
                8'b1111_1111 : begin
                    rx_data_speed_test  <=  rx_data_speed_test + 8;
                end
            endcase
        end
    end
    
    // 100 -> 50, 250
    clk_wiz_50M axi_lite_clocking_i (
        // Clock out ports
        .clk_out1(s_axi_aclk),     // output clk_out1
        .clk_out2(clk_250M),     // output clk_out1
        .clk_out3(clk_156_25M),  
        
        .reset(reset), // input reset

        // Clock in ports
        .clk_in1(clk)
    );

    axi_10g_ethernet_0_example_design #(
        .BOARD_MAC(BOARD_MAC),
        .BOARD_IP(BOARD_IP),
        .TCP_DATA_LENGTH(TCP_DATA_LENGTH),
        .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH)
    )
    dut (
        .s_axi_aclk(s_axi_aclk),
        .refclk_p(GT_DIFF_REFCLK1_0_clk_p),      // 156.25MHz
        .refclk_n(GT_DIFF_REFCLK1_0_clk_n),
        .core_ready(core_ready),
        .coreclk_out(coreclk_out),
        .reset(fifo_reset|vio_reset),

        .txp(ETH_TXP),
        .txn(ETH_TXN),
        .rxp(ETH_RXP),
        .rxn(ETH_RXN),

        .tx_user_tvalid(tx_user_tvalid),
        .tx_user_tready(tx_user_tready),
        .tx_user_tdata(tx_user_tdata),
        .tx_user_tkeep(tx_user_tkeep),

        .rx_user_tvalid(rx_user_tvalid),
        .rx_user_tready(rx_user_tready),
        .rx_user_tdata(rx_user_tdata),
        .rx_user_tkeep(rx_user_tkeep),
        
        .user_checksum_rd_en(user_checksum_rd_en),
        .user_checksum_dout(user_checksum_dout),
        .user_checksum_empty(user_checksum_empty),

        .tcp_state_out(tcp_state_out),

        .tx_packet_loss_signal(tx_packet_loss_signal),
        .rx_packet_loss_signal(rx_packet_loss_signal)
    );

        

    axi_10g_ethernet_0_user_data #(
        .TCP_DATA_LENGTH(TCP_DATA_LENGTH)
    )user_data 
    (
        .s_aclk(coreclk_out),          
        .s_areset(reset),    

        .s_axis_tvalid(s_axis_tvalid), 
        .s_axis_tready(s_axis_tready), 
        .s_axis_tdata(s_axis_tdata),   
        .s_axis_tkeep(s_axis_tkeep),   

        .tx_user_tvalid(tx_user_tvalid),  
        .tx_user_tready(tx_user_tready),  
        .tx_user_tdata(tx_user_tdata),    
        .tx_user_tkeep(tx_user_tkeep),

        .rx_user_tvalid(rx_user_tvalid),
        .rx_user_tready(rx_user_tready),
        .rx_user_tdata(rx_user_tdata),
        .rx_user_tkeep(rx_user_tkeep),   

        .m_axis_tvalid(m_axis_tvalid), 
        .m_axis_tready(m_axis_tready), 
        .m_axis_tdata(m_axis_tdata),   
        .m_axis_tkeep(m_axis_tkeep),  

        .rd_en(user_checksum_rd_en),
        .empty(user_checksum_empty),
        .dout(user_checksum_dout)
    );

endmodule
