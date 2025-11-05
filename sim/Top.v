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


module Top #(
        parameter           BOARD_MAC          =          48'h02_00_c0_a8_0a_0a           ,
        parameter           BOARD_IP           =          {8'd192,8'd168,8'd10,8'd16}      ,
        parameter           TCP_DATA_LENGTH    =       1456,//40
        parameter           RAM_ADDR_WIDTH     =       15 
    )
    (
    input                   CLK_IN_D_0_clk_p,
    input                   CLK_IN_D_0_clk_n,
    input                   GT_DIFF_REFCLK1_0_clk_n,
    input                   GT_DIFF_REFCLK1_0_clk_p,

    // SiTCP Tx Rx
    output                  ETH_TXP, 
    output                  ETH_TXN, 
    input                   ETH_RXP, 
    input                   ETH_RXN

    //input                   c0_sys_clk_p,
    //input                   c0_sys_clk_n,
    /*output                  c0_ddr4_act_n,
    output      [16:0]      c0_ddr4_adr,
    output      [1:0]       c0_ddr4_ba,
    output      [0:0]       c0_ddr4_bg,
    output      [0:0]       c0_ddr4_cke,
    output      [0:0]       c0_ddr4_odt,
    output      [0:0]       c0_ddr4_cs_n,
    output      [0:0]       c0_ddr4_ck_t,
    output      [0:0]       c0_ddr4_ck_c,
    output                  c0_ddr4_reset_n,
    inout       [7:0]       c0_ddr4_dm_dbi_n,
    inout       [63:0]      c0_ddr4_dq,
    inout       [7:0]       c0_ddr4_dqs_t,
    inout       [7:0]       c0_ddr4_dqs_c*/
    );

    wire core_ready;

    (* mark_debug = "true" *)wire s_axi_aclk;
    (* mark_debug = "true" *)wire clk_250M;
    (* mark_debug = "true" *)wire clk_156_25M;
    wire reset;
    reg fifo_reset;
    wire coreclk_out;
    wire [3:0] tcp_state_out;

    wire        s_axis_tvalid;
    wire        s_axis_tready;
    wire [63:0] s_axis_tdata;
    wire [7:0]  s_axis_tkeep;

    wire        m_axis_tvalid;
    wire        m_axis_tready;
    wire [63:0] m_axis_tdata;
    wire [7:0]  m_axis_tkeep;

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

    assign  m_axis_tready   =   1;

    wire clk_100M;

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
        .clk_in1(clk_100M)
    );

    clk_wiz_0 clk_wiz_0_inst
   (
    // Clock out ports
    .clk_out1(clk_100M),     // output clk_out1
    // Status and control signals
    .reset(reset), // input reset
   // Clock in ports
    .clk_in1_p(CLK_IN_D_0_clk_p),    // input clk_in1_p
    .clk_in1_n(CLK_IN_D_0_clk_n)     // input clk_in1_n
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

    axi_10g_ethernet_0_user_generator user_generator (
        .s_aclk(coreclk_out),                // input wire s_aclk
        .s_areset(fifo_reset|vio_reset),          // input wire s_aresetn

        .s_axis_tvalid(s_axis_tvalid),  // input wire s_axis_tvalid
        .s_axis_tready(s_axis_tready),  // output wire s_axis_tready
        .s_axis_tdata(s_axis_tdata),    // input wire [63 : 0] s_axis_tdata
        .s_axis_tkeep(s_axis_tkeep),
        //.s_axis_tvalid(0),
        //.s_axis_tdata(0),  
        //.s_axis_tkeep(0),

        .tx_packet_start_signal(tx_packet_start_signal),
        .tcp_state_out(tcp_state_out)
    );
/*
(* mark_debug = "true" *)reg c0_ddr4_app_en;
(* mark_debug = "true" *)reg c0_ddr4_app_hi_pri;
(* mark_debug = "true" *)reg [2:0] c0_ddr4_app_cmd;
(* mark_debug = "true" *)wire c0_ddr4_app_rdy;
(* mark_debug = "true" *)reg [28:0] c0_ddr4_app_addr;

(* mark_debug = "true" *)reg c0_ddr4_app_wdf_end;
(* mark_debug = "true" *)reg c0_ddr4_app_wdf_wren;
(* mark_debug = "true" *)wire c0_ddr4_app_wdf_rdy;
(* mark_debug = "true" *)reg [511:0] c0_ddr4_app_wdf_data;
(* mark_debug = "true" *)reg [63:0] c0_ddr4_app_wdf_mask;

(* mark_debug = "true" *)wire c0_ddr4_app_rd_data_end;
(* mark_debug = "true" *)wire c0_ddr4_app_rd_data_valid;
(* mark_debug = "true" *)wire [511:0] c0_ddr4_app_rd_data;

    ddr4_0 your_instance_name (
        .c0_init_calib_complete(),              // output wire c0_init_calib_complete
        .dbg_clk(),                                            // output wire dbg_clk
        .dbg_bus(),                                            // output wire [511 : 0] dbg_bus

        .c0_sys_clk_p(CLK_IN_D_0_clk_p),                                  // input wire c0_sys_clk_p
        .c0_sys_clk_n(CLK_IN_D_0_clk_n),                                  // input wire c0_sys_clk_n
        
        .c0_ddr4_adr(c0_ddr4_adr),                                    // output wire [16 : 0] c0_ddr4_adr
        .c0_ddr4_ba(c0_ddr4_ba),                                      // output wire [1 : 0] c0_ddr4_ba
        .c0_ddr4_cke(c0_ddr4_cke),                                    // output wire [0 : 0] c0_ddr4_cke
        .c0_ddr4_cs_n(c0_ddr4_cs_n),                                  // output wire [0 : 0] c0_ddr4_cs_n
        .c0_ddr4_dm_dbi_n(c0_ddr4_dm_dbi_n),                          // inout wire [7 : 0] c0_ddr4_dm_dbi_n
        .c0_ddr4_dq(c0_ddr4_dq),                                      // inout wire [63 : 0] c0_ddr4_dq
        .c0_ddr4_dqs_c(c0_ddr4_dqs_c),                                // inout wire [7 : 0] c0_ddr4_dqs_c
        .c0_ddr4_dqs_t(c0_ddr4_dqs_t),                                // inout wire [7 : 0] c0_ddr4_dqs_t
        .c0_ddr4_odt(c0_ddr4_odt),                                    // output wire [0 : 0] c0_ddr4_odt
        .c0_ddr4_bg(c0_ddr4_bg),                                      // output wire [0 : 0] c0_ddr4_bg
        .c0_ddr4_reset_n(c0_ddr4_reset_n),                            // output wire c0_ddr4_reset_n
        .c0_ddr4_act_n(c0_ddr4_act_n),                                // output wire c0_ddr4_act_n
        .c0_ddr4_ck_c(c0_ddr4_ck_c),                                  // output wire [0 : 0] c0_ddr4_ck_c
        .c0_ddr4_ck_t(c0_ddr4_ck_t),                                  // output wire [0 : 0] c0_ddr4_ck_t
        .c0_ddr4_ui_clk(),                              // output wire c0_ddr4_ui_clk
        .c0_ddr4_ui_clk_sync_rst(),            // output wire c0_ddr4_ui_clk_sync_rst

        // 命令通道
        .c0_ddr4_app_en(c0_ddr4_app_en),                              // input wire c0_ddr4_app_en
        .c0_ddr4_app_hi_pri(0),                      // input wire c0_ddr4_app_hi_pri
        .c0_ddr4_app_cmd(c0_ddr4_app_cmd),                            // input wire [2 : 0] c0_ddr4_app_cmd 000：写 001：读 011：wr_bytes
        .c0_ddr4_app_rdy(c0_ddr4_app_rdy),                            // output wire c0_ddr4_app_rdy
        .c0_ddr4_app_addr(c0_ddr4_app_addr),                          // input wire [28 : 0] c0_ddr4_app_addr

        // 写数据通道
        .c0_ddr4_app_wdf_end(c0_ddr4_app_wdf_end),                    // input wire c0_ddr4_app_wdf_end
        .c0_ddr4_app_wdf_wren(c0_ddr4_app_wdf_wren),                  // input wire c0_ddr4_app_wdf_wren
        .c0_ddr4_app_wdf_rdy(c0_ddr4_app_wdf_rdy),                    // output wire c0_ddr4_app_wdf_rdy
        .c0_ddr4_app_wdf_data(c0_ddr4_app_wdf_data),                  // input wire [511 : 0] c0_ddr4_app_wdf_data
        .c0_ddr4_app_wdf_mask(c0_ddr4_app_wdf_mask),                  // input wire [63 : 0] c0_ddr4_app_wdf_mask

        // 读数据通道
        .c0_ddr4_app_rd_data_end(c0_ddr4_app_rd_data_end),            // output wire c0_ddr4_app_rd_data_end
        .c0_ddr4_app_rd_data_valid(c0_ddr4_app_rd_data_valid),        // output wire c0_ddr4_app_rd_data_valid
        .c0_ddr4_app_rd_data(c0_ddr4_app_rd_data),                    // output wire [511 : 0] c0_ddr4_app_rd_data


        .c0_ddr4_app_sref_req(c0_ddr4_app_sref_req),                  // input wire c0_ddr4_app_sref_req
        .c0_ddr4_app_sref_ack(c0_ddr4_app_sref_ack),                  // output wire c0_ddr4_app_sref_ack
        .c0_ddr4_app_restore_en(c0_ddr4_app_restore_en),              // input wire c0_ddr4_app_restore_en
        .c0_ddr4_app_restore_complete(c0_ddr4_app_restore_complete),  // input wire c0_ddr4_app_restore_complete
        .c0_ddr4_app_mem_init_skip(c0_ddr4_app_mem_init_skip),        // input wire c0_ddr4_app_mem_init_skip
        .c0_ddr4_app_xsdb_select(c0_ddr4_app_xsdb_select),            // input wire c0_ddr4_app_xsdb_select
        .c0_ddr4_app_xsdb_rd_en(c0_ddr4_app_xsdb_rd_en),              // input wire c0_ddr4_app_xsdb_rd_en
        .c0_ddr4_app_xsdb_wr_en(c0_ddr4_app_xsdb_wr_en),              // input wire c0_ddr4_app_xsdb_wr_en
        .c0_ddr4_app_xsdb_addr(c0_ddr4_app_xsdb_addr),                // input wire [15 : 0] c0_ddr4_app_xsdb_addr
        .c0_ddr4_app_xsdb_wr_data(c0_ddr4_app_xsdb_wr_data),          // input wire [8 : 0] c0_ddr4_app_xsdb_wr_data
        .c0_ddr4_app_xsdb_rd_data(c0_ddr4_app_xsdb_rd_data),          // output wire [8 : 0] c0_ddr4_app_xsdb_rd_data
        .c0_ddr4_app_xsdb_rdy(c0_ddr4_app_xsdb_rdy),                  // output wire c0_ddr4_app_xsdb_rdy
        .c0_ddr4_app_dbg_out(c0_ddr4_app_dbg_out),                    // output wire [31 : 0] c0_ddr4_app_dbg_out
        .sys_rst(reset)                                            // input wire sys_rst
);*/


endmodule
