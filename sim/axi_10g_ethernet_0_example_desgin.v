`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/12 20:24:59
// Design Name: 
// Module Name: axi_10g_ethernet_0_example_desgin
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


(* DowngradeIPIdentifiedWarnings = "yes" *)
module axi_10g_ethernet_0_example_design #(
        parameter           BOARD_MAC          =          48'h02_00_c0_a8_0a_0a           ,
        parameter           BOARD_IP           =          {8'd192,8'd168,8'd2,8'd20}      ,
        parameter           TCP_DATA_LENGTH    =        1456     ,
        parameter           RAM_ADDR_WIDTH     =        14
   )
  (
   // Clock inputs
   //input             clk_in_p,       // Freerunning clock source
   //input             clk_in_n,
   input             s_axi_aclk,
   input             refclk_p,       // Transceiver reference clock source
   input             refclk_n,
   output            coreclk_out,

   // Example design control inputs
   input             pcs_loopback,
   input             reset,
   input             reset_error,
   input             insert_error,
   input             enable_pat_gen,
   input             enable_pat_check,
   output            serialized_stats,
   input             sim_speedup_control,
   input             enable_custom_preamble,

   // Example design status outputs
   output            frame_error,
   output            gen_active_flash,
   output            check_active_flash,
   output            core_ready,
   output            qplllock_out,

   // Serial I/O from/to transceiver
   output            txp,
   output            txn,
   input             rxp,
   input             rxn,

   input             tx_user_tvalid,
   output            tx_user_tready,
   input    [63:0]   tx_user_tdata,
   input    [7:0]    tx_user_tkeep,

   output            rx_user_tvalid,
   input             rx_user_tready,
   output   [63:0]   rx_user_tdata,
   output   [7:0]    rx_user_tkeep,

   output            user_checksum_rd_en,
   input    [15:0]   user_checksum_dout,
   input             user_checksum_empty,

   output   [3:0]    tcp_state_out,

   input             tx_packet_loss_signal,
   input             rx_packet_loss_signal
   );
/*-------------------------------------------------------------------------*/


   // Set FIFO memory size
   localparam        FIFO_SIZE  = 1024;


   // Signal declarations
   wire              enable_vlan;
   wire              reset_error_sync;

   wire              coreclk;
   wire              block_lock;
   wire              rxrecclk;

   wire              tx_dcm_locked;
   wire              no_remote_and_local_faults;
   wire    [79 : 0]  mac_tx_configuration_vector;
   wire    [79 : 0]  mac_rx_configuration_vector;
   wire   [2 : 0]    mac_status_vector;
   wire   [535 : 0]  pcs_pma_configuration_vector;
   wire   [447 : 0]  pcs_pma_status_vector;

   wire              tx_statistics_vector;
   wire              rx_statistics_vector;
   wire     [25:0]   tx_statistics_vector_int;
   wire              tx_statistics_valid_int;
   reg               tx_statistics_valid;
   reg      [27:0]   tx_statistics_shift = 0;
   wire     [29:0]   rx_statistics_vector_int;
   wire              rx_statistics_valid_int;
   reg               rx_statistics_valid;
   reg      [31:0]   rx_statistics_shift = 0;

   wire     [63:0]   tx_axis_tdata;
   wire     [7:0]    tx_axis_tkeep;
   wire              tx_axis_tvalid;
   wire              tx_axis_tlast;
   wire              tx_axis_tready;
   (* mark_debug = "true" *)wire     [63:0]   rx_axis_tdata;
   (* mark_debug = "true" *)wire     [7:0]    rx_axis_tkeep;
   (* mark_debug = "true" *)wire              rx_axis_tvalid;
   (* mark_debug = "true" *)wire              rx_axis_tlast;
   (* mark_debug = "true" *)wire              rx_axis_tready;

   (* mark_debug = "true" *)wire     [63:0]   rx_axis_tdata_reg;
   (* mark_debug = "true" *)wire     [7:0]    rx_axis_tkeep_reg;
   (* mark_debug = "true" *)wire              rx_axis_tvalid_reg;
   (* mark_debug = "true" *)wire              rx_axis_tlast_reg;
   (* mark_debug = "true" *)wire              rx_axis_tready_reg;

   assign rx_axis_tdata = (rx_packet_loss_signal) ? 0 : rx_axis_tdata_reg;
   assign rx_axis_tkeep = (rx_packet_loss_signal) ? 0 : rx_axis_tkeep_reg;
   assign rx_axis_tvalid = (rx_packet_loss_signal) ? 0 : rx_axis_tvalid_reg;
   assign rx_axis_tlast = (rx_packet_loss_signal) ? 0 : rx_axis_tlast_reg;
   assign rx_axis_tready_reg = rx_axis_tready;

   wire              tx_reset;
   wire              rx_reset;

   wire              tx_axis_aresetn;
   wire              rx_axis_aresetn;

   wire              pat_gen_start;

   wire              resetdone_out;
   wire              resetdone_out_rising_edge;
   reg               resetdone_out_reg;
   reg       [1:0]   resetdone_out_count = 2'b0;
   wire      [7:0]   pcspma_status;

   wire              pcs_loopback_sync;
   wire              enable_custom_preamble_coreclk_sync;
   wire              insert_error_sync;


   assign coreclk_out = coreclk;

   // Enable or disable VLAN mode
   assign enable_vlan = 0;

   // Synchronise example design inputs into the applicable clock domain
   axi_10g_ethernet_1_sync_block sync_insert_error (
      .data_in                         (insert_error),
      .clk                             (coreclk),
      .data_out                        (insert_error_sync)
   );

   axi_10g_ethernet_1_sync_block sync_coreclk_enable_custom_preamble (
      .data_in                         (enable_custom_preamble),
      .clk                             (coreclk),
      .data_out                        (enable_custom_preamble_coreclk_sync)
   );


   axi_10g_ethernet_1_sync_block sync_pcs_loopback (
      .data_in                         (pcs_loopback),
      .clk                             (coreclk),
      .data_out                        (pcs_loopback_sync)
   );

   // Assign the configuration settings to the configuration vectors
   assign mac_rx_configuration_vector = {72'd0,enable_custom_preamble_coreclk_sync,4'd0,enable_vlan,2'b10};
   assign mac_tx_configuration_vector = {72'd0,enable_custom_preamble_coreclk_sync,4'd0,enable_vlan,2'b10};

   assign pcs_pma_configuration_vector = {425'd0,pcs_loopback_sync,110'd0};
   assign block_lock = pcspma_status[0];
   assign no_remote_and_local_faults = !mac_status_vector[0] && !mac_status_vector[1] ;
   assign core_ready = block_lock && no_remote_and_local_faults && resetdone_out_count[1];
   
   assign resetdone_out_rising_edge  = resetdone_out & !resetdone_out_reg;

   always @(posedge coreclk)
   begin
     resetdone_out_reg <= resetdone_out;
   end

   always @(posedge coreclk)
   begin
      if (reset) begin
         resetdone_out_count <= 0;
      end
      else if (resetdone_out_rising_edge) begin
         resetdone_out_count <= resetdone_out_count + 1;
      end
   end
   // assign core_ready = block_lock && no_remote_and_local_faults;

   // Combine reset sources
   assign tx_axis_aresetn  = ~reset;
   assign rx_axis_aresetn  = ~reset;

   assign pat_gen_start = enable_pat_gen && no_remote_and_local_faults && (pcs_loopback_sync || (block_lock && !pcs_loopback_sync));

   // The serialized statistics vector output is intended to only prevent logic stripping
   assign serialized_stats = tx_statistics_vector || rx_statistics_vector;

   assign tx_reset  = reset;
   assign rx_reset  = reset;



    //--------------------------------------------------------------------------
    // Instantiate a module containing the Ethernet core and an example FIFO
    //--------------------------------------------------------------------------
    axi_10g_ethernet_1_fifo_block #(
      .FIFO_SIZE                       (FIFO_SIZE)
    ) fifo_block_i (
      .refclk_p                        (refclk_p),
      .refclk_n                        (refclk_n),
      .coreclk_out                     (coreclk),
      .rxrecclk_out                    (rxrecclk),
      .dclk                            (s_axi_aclk),

      .reset                           (reset),

      .tx_ifg_delay                    (8'd0),

      .tx_statistics_vector            (tx_statistics_vector_int),
      .tx_statistics_valid             (tx_statistics_valid_int),
      .rx_statistics_vector            (rx_statistics_vector_int),
      .rx_statistics_valid             (rx_statistics_valid_int),

      .pause_val                       (16'b0),
      .pause_req                       (1'b0),

      .rx_axis_fifo_aresetn            (rx_axis_aresetn),
      .rx_axis_mac_aresetn             (rx_axis_aresetn),

      .rx_axis_fifo_tdata              (rx_axis_tdata_reg),
      .rx_axis_fifo_tkeep              (rx_axis_tkeep_reg),
      .rx_axis_fifo_tvalid             (rx_axis_tvalid_reg),
      .rx_axis_fifo_tlast              (rx_axis_tlast_reg),
      .rx_axis_fifo_tready             (rx_axis_tready_reg),

      .tx_axis_mac_aresetn             (tx_axis_aresetn),
      .tx_axis_fifo_aresetn            (tx_axis_aresetn),
      .tx_axis_fifo_tdata              (tx_axis_tdata),
      .tx_axis_fifo_tkeep              (tx_axis_tkeep),
      .tx_axis_fifo_tvalid             (tx_axis_tvalid),
      .tx_axis_fifo_tlast              (tx_axis_tlast),
      .tx_axis_fifo_tready             (tx_axis_tready),

      .mac_tx_configuration_vector     (mac_tx_configuration_vector),
      .mac_rx_configuration_vector     (mac_rx_configuration_vector),
      .mac_status_vector               (mac_status_vector),
      .pcs_pma_configuration_vector    (pcs_pma_configuration_vector),
      .pcs_pma_status_vector           (pcs_pma_status_vector),

      .txp                             (txp),
      .txn                             (txn),
      .rxp                             (rxp),
      .rxn                             (rxn),

      .signal_detect                   (1'b1),
      .tx_fault                        (1'b0),
      .sim_speedup_control             (sim_speedup_control),
      .pcspma_status                   (pcspma_status),
      .resetdone_out                   (resetdone_out),
      .qplllock_out                    (qplllock_out)
      );


    //--------------------------------------------------------------------------
    // Instantiate the AXI-LITE/DRPCLK Clock source module
    //--------------------------------------------------------------------------
/*
    axi_10g_ethernet_1_clocking axi_lite_clocking_i (
      .clk_in_p                        (clk_in_p),
      .clk_in_n                        (clk_in_n),
      .s_axi_aclk                      (s_axi_aclk),
      .tx_mmcm_reset                   (tx_reset),
      .tx_mmcm_locked                  (tx_dcm_locked)
    );*/

    axi_10g_ethernet_1_sync_block reset_error_sync_reg (
      .clk                             (coreclk),
      .data_in                         (reset_error),
      .data_out                        (reset_error_sync)
      );

    //--------------------------------------------------------------------------
    // Instantiate the pattern generator / pattern checker and loopback module
    //--------------------------------------------------------------------------

    /*axi_10g_ethernet_1_gen_check_wrapper pattern_generator (
      .dest_addr                       (48'hda0102030405),
      .src_addr                        (48'h5a0102030405),
      .max_size                        (15'd300),
      .min_size                        (15'd066),
      .enable_vlan                     (enable_vlan),
      .vlan_id                         (12'h002),
      .vlan_priority                   (3'b010),
      .preamble_data                   (56'hD55555567555FB),
      .enable_custom_preamble          (enable_custom_preamble_coreclk_sync),

      .aclk                            (coreclk),

      .aresetn                         (tx_axis_aresetn),
      .enable_pat_gen                  (pat_gen_start),
      .reset_error                     (reset_error_sync),
      .insert_error                    (insert_error_sync),
      .enable_pat_check                (enable_pat_check),
      .enable_loopback                 (!pat_gen_start),
      .frame_error                     (frame_error),
      .gen_active_flash                (gen_active_flash),
      .check_active_flash              (check_active_flash),

      .tx_axis_tdata                   (tx_axis_tdata),
      .tx_axis_tkeep                   (tx_axis_tkeep),
      .tx_axis_tvalid                  (tx_axis_tvalid),
      .tx_axis_tlast                   (tx_axis_tlast),
      .tx_axis_tready                  (tx_axis_tready),
      .rx_axis_tdata                   (rx_axis_tdata),
      .rx_axis_tkeep                   (rx_axis_tkeep),
      .rx_axis_tvalid                  (rx_axis_tvalid),
      .rx_axis_tlast                   (rx_axis_tlast),
      .rx_axis_tready                  (rx_axis_tready)
   );*/

   wire     [63:0]   arp_reply_tdata;
   wire     [7:0]    arp_reply_tkeep;
   wire              arp_reply_tvalid;
   wire              arp_reply_tlast;
   wire              arp_reply_tready;
   wire              arp_reply_en;
   wire              arp_reply_done;

   wire     [63:0]   arp_request_tdata;
   wire     [7:0]    arp_request_tkeep;
   wire              arp_request_tvalid;
   wire              arp_request_tlast;
   wire              arp_request_tready;
   wire              arp_request_en;
   wire              arp_request_done;

   wire     [63:0]   icmp_reply_tdata;
   wire     [7:0]    icmp_reply_tkeep;
   wire              icmp_reply_tvalid;
   wire              icmp_reply_tlast;
   wire              icmp_reply_tready;
   wire              icmp_reply_en;
   wire              icmp_reply_done;

   wire     [63:0]   tcp_link_tdata;
   wire     [7:0]    tcp_link_tkeep;
   wire              tcp_link_tvalid;
   wire              tcp_link_tlast;
   wire              tcp_link_tready;
   wire              tcp_link_en;
   wire              tcp_link_done;

   (* mark_debug = "true" *)wire     [63:0]   tcp_user_tdata;
   (* mark_debug = "true" *)wire     [7:0]    tcp_user_tkeep;
   (* mark_debug = "true" *)wire              tcp_user_tvalid;
   (* mark_debug = "true" *)wire              tcp_user_tlast;
   (* mark_debug = "true" *)wire              tcp_user_tready;
   (* mark_debug = "true" *)wire              tcp_user_en;
   (* mark_debug = "true" *)wire              tcp_user_done;

   wire              areset;
   (* mark_debug = "true" *)wire              state_reset;

   assign            areset   =  reset | state_reset;

   axi_10g_ethernet_0_arp_block #(
      .BOARD_MAC                       (BOARD_MAC),
      .BOARD_IP                        (BOARD_IP),
      .show_output_block               (1)                     ,
      .show_message_type               (1)
   )
   arp_block (
      .aclk                            (coreclk)               ,
      .areset                          (reset)                ,

      .rx_axis_tdata                   (rx_axis_tdata)         ,
      .rx_axis_tkeep                   (rx_axis_tkeep)         ,
      .rx_axis_tvalid                  (rx_axis_tvalid)        ,
      .rx_axis_tlast                   (rx_axis_tlast)         ,
      .rx_axis_tready                  (rx_axis_tready)        ,

      .arp_reply_tdata                 (arp_reply_tdata)       ,
      .arp_reply_tkeep                 (arp_reply_tkeep)       ,
      .arp_reply_tvalid                (arp_reply_tvalid)      ,
      .arp_reply_tlast                 (arp_reply_tlast)       ,
      .arp_reply_tready                (arp_reply_tready)      ,
      .arp_reply_en                    (arp_reply_en)          ,
      .arp_reply_done                  (arp_reply_done)        ,

      .arp_request_tdata               (arp_request_tdata)     ,
      .arp_request_tkeep               (arp_request_tkeep)     ,
      .arp_request_tvalid              (arp_request_tvalid)    ,
      .arp_request_tlast               (arp_request_tlast)     ,
      .arp_request_tready              (arp_request_tready)    ,
      .arp_request_en                  (arp_request_en)        ,
      .arp_request_done                (arp_request_done)  
   );

   axi_10g_ethernet_0_icmp_block #(
      .BOARD_MAC                       (BOARD_MAC),
      .BOARD_IP                        (BOARD_IP)
   )
   icmp_block
    (
        .aclk                           (coreclk)              ,
        .areset                         (reset)                ,

        .rx_axis_tdata                  (rx_axis_tdata)        ,
        .rx_axis_tkeep                  (rx_axis_tkeep)        ,
        .rx_axis_tvalid                 (rx_axis_tvalid)       ,
        .rx_axis_tlast                  (rx_axis_tlast)        ,
        .rx_axis_tready                 (rx_axis_tready)       ,

        .icmp_reply_tdata               (icmp_reply_tdata)     ,
        .icmp_reply_tkeep               (icmp_reply_tkeep)     ,
        .icmp_reply_tvalid              (icmp_reply_tvalid)    ,
        .icmp_reply_tlast               (icmp_reply_tlast)     ,

        .icmp_reply_tready              (icmp_reply_tready)    ,
        .icmp_reply_en                  (icmp_reply_en)        ,
        .icmp_reply_done                (icmp_reply_done)
    );

    axi_10g_ethernet_0_tcp_block #(
        .BOARD_MAC(BOARD_MAC),
        .BOARD_IP(BOARD_IP),
        .TCP_DATA_LENGTH(TCP_DATA_LENGTH),
        .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH)
    )
    tcp_block
    (
        .aclk                           (coreclk)              ,
        .areset                         (reset)                ,

        .rx_axis_tdata                  (rx_axis_tdata)        ,
        .rx_axis_tkeep                  (rx_axis_tkeep)        ,
        .rx_axis_tvalid                 (rx_axis_tvalid)       ,
        .rx_axis_tlast                  (rx_axis_tlast)        ,
        .rx_axis_tready                 (rx_axis_tready)       ,

        .tcp_link_tdata                 (tcp_link_tdata)       ,
        .tcp_link_tkeep                 (tcp_link_tkeep)       ,
        .tcp_link_tvalid                (tcp_link_tvalid)      ,
        .tcp_link_tlast                 (tcp_link_tlast)       ,
        .tcp_link_tready                (tcp_link_tready)      ,
        .tcp_link_en                    (tcp_link_en)          ,
        .tcp_link_done                  (tcp_link_done)        ,

        .tcp_user_tdata                 (tcp_user_tdata)       ,
        .tcp_user_tkeep                 (tcp_user_tkeep)       ,
        .tcp_user_tvalid                (tcp_user_tvalid)      ,
        .tcp_user_tlast                 (tcp_user_tlast)       ,
        .tcp_user_tready                (tcp_user_tready)      ,
        .tcp_user_en                    (tcp_user_en)          ,
        .tcp_user_done                  (tcp_user_done)        ,

        .tx_user_tvalid                 (tx_user_tvalid)       ,
        .tx_user_tready                 (tx_user_tready)       ,
        .tx_user_tdata                  (tx_user_tdata)        ,
        .tx_user_tkeep                  (tx_user_tkeep)        ,

        .rx_user_tvalid                 (rx_user_tvalid)       ,
        .rx_user_tready                 (rx_user_tready)       ,
        .rx_user_tdata                  (rx_user_tdata)        ,
        .rx_user_tkeep                  (rx_user_tkeep)        ,

        .user_checksum_rd_en            (user_checksum_rd_en)  ,
        .user_checksum_dout             (user_checksum_dout)   ,
        .user_checksum_empty            (user_checksum_empty)  ,

        .tcp_state_out                  (tcp_state_out)        ,

        .state_reset                    (state_reset)
    );

   axi_10G_tx_control #(
    .show_output_block               (1)                           
   ) tx_control
    (
    .aclk                            (coreclk)               ,
    .areset                          (reset)                ,

    .arp_reply_tdata                 (arp_reply_tdata)       ,
    .arp_reply_tkeep                 (arp_reply_tkeep)       ,
    .arp_reply_tvalid                (arp_reply_tvalid)      ,
    .arp_reply_tlast                 (arp_reply_tlast)       ,
    .arp_reply_tready                (arp_reply_tready)      ,
    .arp_reply_en                    (arp_reply_en)          ,
    .arp_reply_done                  (arp_reply_done)        ,

    .arp_request_tdata               (arp_request_tdata)     ,
    .arp_request_tkeep               (arp_request_tkeep)     ,
    .arp_request_tvalid              (arp_request_tvalid)    ,
    .arp_request_tlast               (arp_request_tlast)     ,
    .arp_request_tready              (arp_request_tready)    ,
    .arp_request_en                  (arp_request_en)        ,
    .arp_request_done                (arp_request_done)      ,

    .icmp_reply_tdata                (icmp_reply_tdata)      ,
    .icmp_reply_tkeep                (icmp_reply_tkeep)      ,
    .icmp_reply_tvalid               (icmp_reply_tvalid)     ,
    .icmp_reply_tlast                (icmp_reply_tlast)      ,
    .icmp_reply_tready               (icmp_reply_tready)     ,
    .icmp_reply_en                   (icmp_reply_en)         ,
    .icmp_reply_done                 (icmp_reply_done)       ,

    .tcp_link_tdata                  (tcp_link_tdata)        ,
    .tcp_link_tkeep                  (tcp_link_tkeep)        ,
    .tcp_link_tvalid                 (tcp_link_tvalid)       ,
    .tcp_link_tlast                  (tcp_link_tlast)        ,
    .tcp_link_tready                 (tcp_link_tready)       ,
    .tcp_link_en                     (tcp_link_en)           ,
    .tcp_link_done                   (tcp_link_done)         ,

    .tcp_user_tdata                  (tcp_user_tdata)        ,
    .tcp_user_tkeep                  (tcp_user_tkeep)        ,
    .tcp_user_tvalid                 (tcp_user_tvalid)       ,
    .tcp_user_tlast                  (tcp_user_tlast)        ,
    .tcp_user_tready                 (tcp_user_tready)       ,
    .tcp_user_en                     (tcp_user_en)           ,
    .tcp_user_done                   (tcp_user_done)         ,

    // 经control模块控制后的实际传输数据
    .tx_axis_tdata                   (tx_axis_tdata)         ,
    .tx_axis_tkeep                   (tx_axis_tkeep)         ,
    .tx_axis_tvalid                  (tx_axis_tvalid)        ,
    .tx_axis_tlast                   (tx_axis_tlast)         ,
    .tx_axis_tready                  (tx_axis_tready)        ,

    .tx_packet_loss_signal           (tx_packet_loss_signal)
);


   //--------------------------------------------------------------------------
   // serialise the stats vector output to ensure logic isn't stripped during
   // synthesis and to reduce the IO required by the example design
   //--------------------------------------------------------------------------
   always @(posedge coreclk)
   begin
     tx_statistics_valid               <= tx_statistics_valid_int;
     if (tx_statistics_valid_int & !tx_statistics_valid) begin
        tx_statistics_shift            <= {2'b01,tx_statistics_vector_int};
     end
     else begin
        tx_statistics_shift            <= {tx_statistics_shift[26:0], 1'b0};
     end
   end

   assign tx_statistics_vector         = tx_statistics_shift[27];

   always @(posedge coreclk)
   begin
     rx_statistics_valid               <= rx_statistics_valid_int;
     if (rx_statistics_valid_int & !rx_statistics_valid) begin
        rx_statistics_shift            <= {2'b01, rx_statistics_vector_int};
     end
     else begin
        rx_statistics_shift            <= {rx_statistics_shift[30:0], 1'b0};
     end
   end

   assign rx_statistics_vector         = rx_statistics_shift[31];


endmodule
