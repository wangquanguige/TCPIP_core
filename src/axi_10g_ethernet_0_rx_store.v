`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/08/21 11:58:06
// Design Name: 
// Module Name: axi_10g_ethernet_0_rx_store
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


module axi_10g_ethernet_0_rx_store #(
        parameter           RAM_ADDR_WIDTH     =          14                              
    )
    (
        input                       aclk               ,
        input                       areset             ,

        input     [31:0]            rd_addr_start      ,
        input                       established_moment ,

        input     [31:0]            seq_number_store_resize   ,        // 大端序

        input                       rx_not_stored_user_tvalid_resize     ,
        output                      rx_not_stored_user_tready_resize     ,
        input     [63:0]            rx_not_stored_user_tdata_resize      ,
        input     [7:0]             rx_not_stored_user_tkeep_resize      ,

        input     [31:0]            link_clk_cnt       ,

        output  reg                 rx_user_tvalid     ,
        input                       rx_user_tready     ,
        output  reg   [63:0]        rx_user_tdata      ,
        output  reg   [7:0]         rx_user_tkeep      ,

        output        [15:0]        rx_window_size     ,

        input         [31:0]        ack_number_local   ,

        output  reg   [31:0]        rx_store_ack_number_local,     // 大端序
        output  reg                 rx_store_signal
    );

    (* mark_debug = "true" *)reg             clk_en_a                       ;
    (* mark_debug = "true" *)reg  [RAM_ADDR_WIDTH-1:0]      wr_addr                        ;
    (* mark_debug = "true" *)reg  [63:0]     dina_data                           ;
    (* mark_debug = "true" *)reg  [63:0]     dina_seq                           ;

    (* mark_debug = "true" *)reg             clk_en_b                       ;
    (* mark_debug = "true" *)reg  [RAM_ADDR_WIDTH-1:0]      rd_addr                        ;
    (* mark_debug = "true" *)reg  [RAM_ADDR_WIDTH-1:0]      rd_addr_reg                        ;
    //(* mark_debug = "true" *)reg              start                        ;
    (* mark_debug = "true" *)wire  [63:0]     doutb_data                          ;
    (* mark_debug = "true" *)wire  [63:0]     doutb_seq                         ;

    reg [4:0]  store_ack;

    reg       seq_number_start;

    // 全部大端
    function check_ack_number(input reg [31:0] ack_number_loacl, input reg [31:0] next_ack_number);
        /*if (acked_opposite >= start_seq) begin
            if (send_seq >= start_seq & send_seq <= acked_opposite) begin
                check_ack_number = 1'b1;
            end
            else begin
                check_ack_number = 1'b0;
            end
        end
        else begin
            if (send_seq > acked_opposite & send_seq < start_seq) begin
                check_ack_number = 1'b0;
            end
            else begin
                check_ack_number = 1'b1;
            end
        end*/
        /*if(ack_number_loacl == next_ack_number) begin
            check_ack_number = 1'b1;
        end
        else */if(ack_number_loacl + 1== next_ack_number) begin
            check_ack_number = 1'b1;
        end
        else if(ack_number_loacl + 2== next_ack_number) begin
            check_ack_number = 1'b1;
        end
        else if(ack_number_loacl + 3== next_ack_number) begin
            check_ack_number = 1'b1;
        end
        else if(ack_number_loacl + 4== next_ack_number) begin
            check_ack_number = 1'b1;
        end
        else if(ack_number_loacl + 5== next_ack_number) begin
            check_ack_number = 1'b1;
        end
        else if(ack_number_loacl + 6== next_ack_number) begin
            check_ack_number = 1'b1;
        end
        else if(ack_number_loacl + 7== next_ack_number) begin
            check_ack_number = 1'b1;
        end
        else if(ack_number_loacl + 8== next_ack_number) begin
            check_ack_number = 1'b1;
        end
        else begin
            check_ack_number = 1'b0;
        end
    endfunction


        //rx_window_size          =           2**RAM_ADDR_WIDTH - 1;
    assign    rx_window_size          =           2**RAM_ADDR_WIDTH - 1460 - (wr_addr - rd_addr );  
    assign    rx_not_stored_user_tready     =       1;

    /*always @(posedge aclk) begin
        if (rx_not_stored_user_tvalid == 1) begin
            clk_en_a        =       1;
            wr_addr         =       seq_number_store[RAM_ADDR_WIDTH+2:3];

            case(rx_not_stored_user_tkeep)
                8'b0000_0001 : begin
                    store_ack   =   5'h1;
                end
                8'b0000_0011 : begin
                    store_ack   =   5'h2;
                end
                8'b0000_0111 : begin
                    store_ack   =   5'h3;
                end
                8'b0000_1111 : begin
                    store_ack   =   5'h4;
                end
                8'b0001_1111 : begin
                    store_ack   =   5'h5;
                end
                8'b0011_1111 : begin
                    store_ack   =   5'h6;
                end
                8'b0111_1111 : begin
                    store_ack   =   5'h7;
                end
                8'b1111_1111 : begin
                    store_ack   =   5'h8;
                end
            endcase
            dina            =       {rx_not_stored_user_tvalid, rx_not_stored_user_tkeep, rx_not_stored_user_tdata, seq_number_store + store_ack};
        end
        else begin
            clk_en_a        =       0;
        end
    end*/
    always @(rx_not_stored_user_tkeep_resize) begin
        case(rx_not_stored_user_tkeep_resize)
            8'b0000_0001 : begin
                store_ack   =   5'h1;
            end
            8'b0000_0011 : begin
                store_ack   =   5'h2;
            end
            8'b0000_0111 : begin
                store_ack   =   5'h3;
            end
            8'b0000_1111 : begin
                store_ack   =   5'h4;
            end
            8'b0001_1111 : begin
                store_ack   =   5'h5;
            end
            8'b0011_1111 : begin
                store_ack   =   5'h6;
            end
            8'b0111_1111 : begin
                store_ack   =   5'h7;
            end
            8'b1111_1111 : begin
                store_ack   =   5'h8;
            end
        endcase
    end

    always @(negedge aclk) begin
        if (rx_not_stored_user_tvalid_resize == 1) begin
            clk_en_a        <=       1;
            wr_addr         <=       seq_number_store_resize[RAM_ADDR_WIDTH+2:3];

           /* case(rx_not_stored_user_tkeep)
                8'b0000_0001 : begin
                    //store_ack   =   5'h1;
                    dina_data            <=       {rx_not_stored_user_tdata};
                    dina_seq             <=       {rx_not_stored_user_tvalid, rx_not_stored_user_tkeep, seq_number_store + 1};
                end
                8'b0000_0011 : begin
                    //store_ack   =   5'h2;
                    dina_data            <=       {rx_not_stored_user_tdata};
                    dina_seq             <=       {rx_not_stored_user_tvalid, rx_not_stored_user_tkeep, seq_number_store + 2};
                end
                8'b0000_0111 : begin
                    //store_ack   =   5'h3;
                    dina_data            <=       {rx_not_stored_user_tdata};
                    dina_seq             <=       {rx_not_stored_user_tvalid, rx_not_stored_user_tkeep, seq_number_store + 3};
                end
                8'b0000_1111 : begin
                    //store_ack   =   5'h4;
                    dina_data            <=       {rx_not_stored_user_tdata};
                    dina_seq             <=       {rx_not_stored_user_tvalid, rx_not_stored_user_tkeep, seq_number_store + 4};
                end
                8'b0001_1111 : begin
                    //store_ack   =   5'h5;
                    dina_data            <=       {rx_not_stored_user_tdata};
                    dina_seq             <=       {rx_not_stored_user_tvalid, rx_not_stored_user_tkeep, seq_number_store + 5};
                end
                8'b0011_1111 : begin
                    //store_ack   =   5'h6;
                    dina_data            <=       {rx_not_stored_user_tdata};
                    dina_seq             <=       {rx_not_stored_user_tvalid, rx_not_stored_user_tkeep, seq_number_store + 6};
                end
                8'b0111_1111 : begin
                    //store_ack   =   5'h7;
                    dina_data            <=       {rx_not_stored_user_tdata};
                    dina_seq             <=       {rx_not_stored_user_tvalid, rx_not_stored_user_tkeep, seq_number_store + 7};
                end
                8'b1111_1111 : begin
                    //store_ack   =   5'h8;
                    dina_data            <=       {rx_not_stored_user_tdata};
                    dina_seq             <=       {rx_not_stored_user_tvalid, rx_not_stored_user_tkeep, seq_number_store + 8};
                end
            endcase*/
            dina_data            <=       {rx_not_stored_user_tdata_resize};
            dina_seq             <=       {rx_not_stored_user_tvalid_resize, rx_not_stored_user_tkeep_resize, seq_number_store_resize};
        end
        else begin
            clk_en_a        <=       0;
        end
    end

    always @(posedge aclk) begin
        rd_addr_reg <=  rd_addr;
    end

    always @(posedge aclk) begin
        if (established_moment) begin 
            rd_addr    <=   rd_addr_start[RAM_ADDR_WIDTH+2:3];
            rx_store_ack_number_local <= rd_addr_start;
            rx_store_signal <=  0;
        end
        else if (rx_user_tready == 1 && doutb_seq[40] == 1 && check_ack_number({ack_number_local[7:0], ack_number_local[15:8], ack_number_local[23:16], ack_number_local[31:24]}
                                                            , doutb_seq[31:0])) begin
            rx_user_tvalid <= doutb_seq[40];
            rx_user_tdata  <= doutb_data[63:0];
            rx_user_tkeep  <= doutb_seq[39:32];

            rx_store_ack_number_local    <=  doutb_seq[31:0];
            rx_store_signal <=  1;
            if (doutb_seq[2:0]==0) begin
                rd_addr     <=  rd_addr + 1;
            end
        end
        else begin
            rx_store_ack_number_local    <=  {ack_number_local[7:0], ack_number_local[15:8], ack_number_local[23:16], ack_number_local[31:24]};
            rx_store_signal <=  0;
        end
    end
/*
    dist_mem_gen_0 TCP_RX_DATA_RAM (
      .a(wr_addr),        // input wire [13 : 0] a
      .d(dina_data),        // input wire [63 : 0] d
      .dpra(rd_addr),  // input wire [13 : 0] dpra
      .clk(aclk),    // input wire clk
      .we(clk_en_a),      // input wire we
      .dpo(doutb_data)    // output wire [63 : 0] dpo
    );

    dist_mem_gen_0 TCP_RX_SEQ_RAM (
      .a(wr_addr),        // input wire [13 : 0] a
      .d(dina_seq),        // input wire [63 : 0] d
      .dpra(rd_addr),  // input wire [13 : 0] dpra
      .clk(aclk),    // input wire clk
      .we(clk_en_a),      // input wire we
      .dpo(doutb_seq)    // output wire [63 : 0] dpo
    );
*/
    blk_mem_gen_1 TCP_RX_DATA_RAM (
        .clka(aclk),    // input wire clka
        .ena(1),      // input wire ena
        .wea(clk_en_a),      // input wire [0 : 0] wea
        .addra(wr_addr),  // input wire [13 : 0] addra
        .dina(dina_data),    // input wire [104 : 0] dina

        .clkb(aclk),    // input wire clkb
        .enb(1),      // input wire enb
        .addrb(rd_addr_reg),  // input wire [13 : 0] addrb
        .doutb(doutb_data)  // output wire [104 : 0] doutb
    );

    blk_mem_gen_1 TCP_RX_SEQ_RAM (
        .clka(aclk),    // input wire clka
        .ena(1),      // input wire ena
        .wea(clk_en_a),      // input wire [0 : 0] wea
        .addra(wr_addr),  // input wire [13 : 0] addra
        .dina(dina_seq),    // input wire [104 : 0] dina

        .clkb(aclk),    // input wire clkb
        .enb(1),      // input wire enb
        .addrb(rd_addr_reg),  // input wire [13 : 0] addrb
        .doutb(doutb_seq)  // output wire [104 : 0] doutb
    );

endmodule
