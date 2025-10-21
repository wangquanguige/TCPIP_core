`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/06/17 16:52:42
// Design Name: 
// Module Name: axi_10g_ethernet_0_user_data
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


module axi_10g_ethernet_0_user_data #(
    parameter             TCP_DATA_LENGTH    =          1456                              
    )
    (
        input                    s_aclk,                // input wire s_aclk
        input                    s_areset,              // input wire s_areset
     
        input                    s_axis_tvalid,  
        output                   s_axis_tready,  
        input       [63:0]       s_axis_tdata,  
        input       [7:0]        s_axis_tkeep,

        output                   tx_user_tvalid, 
        input                    tx_user_tready, 
        output      [63:0]       tx_user_tdata,  
        output      [7:0]        tx_user_tkeep,

        input                    rx_user_tvalid,
        output                   rx_user_tready,
        input       [63:0]       rx_user_tdata,
        input       [7:0]        rx_user_tkeep,

        output                   m_axis_tvalid, 
        input                    m_axis_tready, 
        output      [63:0]       m_axis_tdata,  
        output      [7:0]        m_axis_tkeep,

        input                    rd_en,
        output                   empty,
        output      [15:0]       dout
    );

    (* mark_debug = "true" *)wire [15:0] din;
    (* mark_debug = "true" *)wire        wr_en;
    (* mark_debug = "true" *)wire        full;

    (* mark_debug = "true" *)wire        s_data_axis_tready;

    assign s_axis_tready = s_data_axis_tready & (~full);

    (* mark_debug = "true" *)wire        s_axis_tvalid_reg;
    (* mark_debug = "true" *)wire [63:0] s_axis_tdata_reg;
    (* mark_debug = "true" *)wire [7:0]  s_axis_tkeep_reg;

    assign  s_axis_tvalid_reg = ((s_data_axis_tready & (~full)) == 1) ? s_axis_tvalid : 0;
    assign  s_axis_tdata_reg = ((s_data_axis_tready & (~full)) == 1) ? s_axis_tdata : 0;
    assign  s_axis_tkeep_reg = ((s_data_axis_tready & (~full)) == 1) ? s_axis_tkeep : 0;

    fifo_generator_0 rx_user_fifo_generator (
        .s_aclk(s_aclk),                // input wire s_aclk
        .s_aresetn(~s_areset),          // input wire s_aresetn

        .s_axis_tvalid(rx_user_tvalid),  // input wire s_axis_tvalid
        .s_axis_tready(rx_user_tready),  // output wire s_axis_tready
        .s_axis_tdata(rx_user_tdata),    // input wire [63 : 0] s_axis_tdata
        .s_axis_tkeep(rx_user_tkeep),    // input wire [7 : 0] s_axis_tkeep

        .m_axis_tvalid(m_axis_tvalid),  // output wire m_axis_tvalid
        .m_axis_tready(m_axis_tready),  // input wire m_axis_tready
        .m_axis_tdata(m_axis_tdata),    // output wire [63 : 0] m_axis_tdata
        .m_axis_tkeep(m_axis_tkeep)    // output wire [7 : 0] m_axis_tkeep
    );

    fifo_generator_0 tx_user_fifo_generator (
        .s_aclk(s_aclk),                // input wire s_aclk
        .s_aresetn(~s_areset),          // input wire s_aresetn

        .s_axis_tvalid(s_axis_tvalid_reg),  // input wire s_axis_tvalid
        .s_axis_tready(s_data_axis_tready),  // output wire s_axis_tready
        .s_axis_tdata(s_axis_tdata_reg),    // input wire [63 : 0] s_axis_tdata
        .s_axis_tkeep(s_axis_tkeep_reg),    // input wire [7 : 0] s_axis_tkeep

        .m_axis_tvalid(tx_user_tvalid),  // output wire m_axis_tvalid
        .m_axis_tready(tx_user_tready),  // input wire m_axis_tready
        .m_axis_tdata(tx_user_tdata),    // output wire [63 : 0] m_axis_tdata
        .m_axis_tkeep(tx_user_tkeep)    // output wire [7 : 0] m_axis_tkeep
    );

    axi_10g_ethernet_0_checksum #(
        .TCP_DATA_LENGTH(TCP_DATA_LENGTH)
    )checksum
    (
        .s_aclk(s_aclk),                // input wire s_aclk
        .s_areset(s_areset),          // input wire s_aresetn
        .s_axis_tvalid(s_axis_tvalid_reg),  // input wire s_axis_tvalid
        .s_axis_tready(s_data_axis_tready & (~full)),    // input wire [63 : 0] s_axis_tdata
        .s_axis_tdata(s_axis_tdata_reg),    // input wire [63 : 0] s_axis_tdata
        .s_axis_tkeep(s_axis_tkeep_reg),    // input wire [7 : 0] s_axis_tkeep

        .din(din),                  // input wire [15 : 0] din
        .wr_en(wr_en),
        .full(full)
    );

    fifo_generator_1 checksum_fifo (
      .clk(s_aclk),                  // input wire clk
      .srst(s_areset),                // input wire srst

      .din(din),                  // input wire [15 : 0] din
      .wr_en(wr_en),              // input wire wr_en
      .rd_en(rd_en),              // input wire rd_en
      .dout(dout),                // output wire [15 : 0] dout
      .full(full),                // output wire full
      .empty(empty)              // output wire empty
    );
endmodule
