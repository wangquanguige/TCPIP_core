`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/09/21 20:10:16
// Design Name: 
// Module Name: axi_10g_ethernet_0_rx_data_resize
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


module axi_10g_ethernet_0_rx_data_resize(
        input            aclk               ,
        input            areset             ,

        input    [31:0]  seq_number_store              ,
        input            rx_not_stored_user_tvalid     ,
        output           rx_not_stored_user_tready     ,
        input    [63:0]  rx_not_stored_user_tdata      ,
        input    [7:0]   rx_not_stored_user_tkeep      ,

        output reg  [31:0]  seq_number_store_resize              ,
        output reg          rx_not_stored_user_tvalid_resize     ,
        input               rx_not_stored_user_tready_resize     ,
        output reg  [63:0]  rx_not_stored_user_tdata_resize      ,
        output reg  [7:0]   rx_not_stored_user_tkeep_resize      
    );
    assign rx_not_stored_user_tready = 1;

    (* mark_debug = "true" *)reg [127:0] rx_data_reg;
    (* mark_debug = "true" *)reg [7:0]   rx_num_reg;
    (* mark_debug = "true" *)reg [31:0]  seq_number_reg;
    (* mark_debug = "true" *)reg [31:0]  seq_number_tmp;
    (* mark_debug = "true" *)reg [3:0]   rx_num;

    (* mark_debug = "true" *)wire [3:0]   rx_need;

    assign rx_need = 3'b111 - seq_number_reg[2:0] + 1;

    always @(rx_not_stored_user_tkeep) begin
        case (rx_not_stored_user_tkeep) 
            8'b0000_0001 : begin
                rx_num = 1;
            end
            8'b0000_0011 : begin
                rx_num = 2;
            end
            8'b0000_0111 : begin
                rx_num = 3;
            end
            8'b0000_1111 : begin
                rx_num = 4;
            end
            8'b0001_1111 : begin
                rx_num = 5;
            end
            8'b0011_1111 : begin
                rx_num = 6;
            end
            8'b0111_1111 : begin
                rx_num = 7;
            end
            8'b1111_1111 : begin
                rx_num = 8;
            end
        endcase
    end

    /*always @(seq_number_reg or rx_num_reg or rx_num) begin
        seq_number_tmp <= (seq_number_reg==0? seq_number_store : seq_number_reg) + rx_num_reg;
    end*/

    always @(posedge aclk) begin
        if(areset) begin
            rx_data_reg         <=      0       ;
            rx_num_reg          <=      0       ;
            seq_number_reg      <=      0       ;
        end
        else begin
            //seq_number_store_resize                 =       0;
            //rx_not_stored_user_tvalid_resize        =       0;
            //rx_not_stored_user_tdata_resize         =       0;
            //rx_not_stored_user_tkeep_resize         =       0;

            if (rx_not_stored_user_tvalid) begin
                if (seq_number_reg == 0) begin
                    seq_number_reg = seq_number_store;
                end

                case(rx_num_reg) 
                    0 : begin
                        rx_data_reg = {64'b0, rx_not_stored_user_tdata};
                    end
                    1 : begin
                        rx_data_reg = {56'b0, rx_not_stored_user_tdata, rx_data_reg[7:0]};
                    end
                    2 : begin
                        rx_data_reg = {48'b0, rx_not_stored_user_tdata, rx_data_reg[15:0]};
                    end
                    3 : begin
                        rx_data_reg = {40'b0, rx_not_stored_user_tdata, rx_data_reg[23:0]};
                    end
                    4 : begin
                        rx_data_reg = {32'b0, rx_not_stored_user_tdata, rx_data_reg[31:0]};
                    end
                    5 : begin
                        rx_data_reg = {24'b0, rx_not_stored_user_tdata, rx_data_reg[39:0]};
                    end
                    6 : begin
                        rx_data_reg = {16'b0, rx_not_stored_user_tdata, rx_data_reg[47:0]};
                    end
                    7 : begin
                        rx_data_reg = {8'b0, rx_not_stored_user_tdata, rx_data_reg[55:0]};
                    end
                    8 : begin
                        rx_data_reg = {rx_not_stored_user_tdata, rx_data_reg[63:0]};
                    end
                endcase
                rx_num_reg  = rx_num_reg + rx_num;
                seq_number_tmp = seq_number_reg + rx_num_reg;
            end

            //seq_number_tmp = seq_number_reg + rx_num_reg;
            if(seq_number_reg && seq_number_tmp[31:3] != seq_number_reg[31:3]) begin
                if (seq_number_reg[2:0] == 0) begin
                    seq_number_store_resize                 <=      seq_number_reg;
                    rx_not_stored_user_tvalid_resize        <=      1;
                    rx_not_stored_user_tdata_resize         <=      rx_data_reg[63:0];
                    rx_not_stored_user_tkeep_resize         <=      8'b1111_1111;
                    seq_number_reg                          <=      seq_number_reg + 8;

                    rx_data_reg                             <=      {64'b0, rx_data_reg[127:64]};
                    rx_num_reg                              <=      rx_num_reg - 8;
                end
                else begin
                    seq_number_store_resize                 <=      seq_number_reg;
                    rx_not_stored_user_tvalid_resize        <=      1;

                    case (rx_need)
                        1 : begin
                            rx_not_stored_user_tdata_resize         <=      rx_data_reg[7:0];
                            rx_not_stored_user_tkeep_resize         <=      8'b0000_0001;
                            seq_number_reg                          <=      seq_number_reg + 1;

                            rx_data_reg                             <=      {8'b0, rx_data_reg[127:8]};
                            rx_num_reg                              <=      rx_num_reg - 1;
                        end
                        2 : begin
                            rx_not_stored_user_tdata_resize         <=      rx_data_reg[15:0];
                            rx_not_stored_user_tkeep_resize         <=      8'b0000_0011;
                            seq_number_reg                          <=      seq_number_reg + 2;

                            rx_data_reg                             <=      {16'b0, rx_data_reg[127:16]};
                            rx_num_reg                              <=      rx_num_reg - 2;
                        end
                        3 : begin
                            rx_not_stored_user_tdata_resize         <=      rx_data_reg[23:0];
                            rx_not_stored_user_tkeep_resize         <=      8'b0000_0111;
                            seq_number_reg                          <=      seq_number_reg + 3;

                            rx_data_reg                             <=      {24'b0, rx_data_reg[127:24]};
                            rx_num_reg                              <=      rx_num_reg - 3;
                        end
                        4 : begin
                            rx_not_stored_user_tdata_resize         <=      rx_data_reg[31:0];
                            rx_not_stored_user_tkeep_resize         <=      8'b0000_1111;
                            seq_number_reg                          <=      seq_number_reg + 4;

                            rx_data_reg                             <=      {32'b0, rx_data_reg[127:32]};
                            rx_num_reg                              <=      rx_num_reg - 4;
                        end
                        5 : begin
                            rx_not_stored_user_tdata_resize         <=      rx_data_reg[39:0];
                            rx_not_stored_user_tkeep_resize         <=      8'b0001_1111;
                            seq_number_reg                          <=      seq_number_reg + 5;

                            rx_data_reg                             <=      {40'b0, rx_data_reg[127:40]};
                            rx_num_reg                              <=      rx_num_reg - 5;
                        end
                        6 : begin
                            rx_not_stored_user_tdata_resize         <=      rx_data_reg[47:0];
                            rx_not_stored_user_tkeep_resize         <=      8'b0011_1111;
                            seq_number_reg                          <=      seq_number_reg + 6;

                            rx_data_reg                             <=      {48'b0, rx_data_reg[127:48]};
                            rx_num_reg                              <=      rx_num_reg - 6;
                        end
                        7 : begin
                            rx_not_stored_user_tdata_resize         <=      rx_data_reg[55:0];
                            rx_not_stored_user_tkeep_resize         <=      8'b0111_1111;
                            seq_number_reg                          <=      seq_number_reg + 7;

                            rx_data_reg                             <=      {56'b0, rx_data_reg[127:56]};
                            rx_num_reg                              <=      rx_num_reg - 7;
                        end
                        8 : begin
                            rx_not_stored_user_tdata_resize         <=      rx_data_reg[63:0];
                            rx_not_stored_user_tkeep_resize         <=      8'b1111_1111;
                            seq_number_reg                          <=      seq_number_reg + 8;

                            rx_data_reg                             <=      {64'b0, rx_data_reg[127:64]};
                            rx_num_reg                              <=      rx_num_reg - 8;
                        end
                    endcase
                end
            end
            else if (rx_not_stored_user_tvalid==0 && rx_num_reg) begin
                seq_number_store_resize                 <=      seq_number_reg;
                rx_not_stored_user_tvalid_resize        <=      1;
                case (rx_num_reg)
                    1 : begin
                        rx_not_stored_user_tdata_resize         <=      rx_data_reg[7:0];
                        rx_not_stored_user_tkeep_resize         <=      8'b0000_0001;
                    end
                    2 : begin
                        rx_not_stored_user_tdata_resize         <=      rx_data_reg[15:0];
                        rx_not_stored_user_tkeep_resize         <=      8'b0000_0011;
                    end
                    3 : begin
                        rx_not_stored_user_tdata_resize         <=      rx_data_reg[23:0];
                        rx_not_stored_user_tkeep_resize         <=      8'b0000_0111;
                    end
                    4 : begin
                        rx_not_stored_user_tdata_resize         <=      rx_data_reg[31:0];
                        rx_not_stored_user_tkeep_resize         <=      8'b0000_1111;
                    end
                    5 : begin
                        rx_not_stored_user_tdata_resize         <=      rx_data_reg[39:0];
                        rx_not_stored_user_tkeep_resize         <=      8'b0001_1111;
                    end
                    6 : begin
                        rx_not_stored_user_tdata_resize         <=      rx_data_reg[47:0];
                        rx_not_stored_user_tkeep_resize         <=      8'b0011_1111;
                    end
                    7 : begin
                        rx_not_stored_user_tdata_resize         <=      rx_data_reg[55:0];
                        rx_not_stored_user_tkeep_resize         <=      8'b0111_1111;
                    end
                    8 : begin
                        rx_not_stored_user_tdata_resize         <=      rx_data_reg[63:0];
                        rx_not_stored_user_tkeep_resize         <=      8'b1111_1111;
                    end
                endcase
                seq_number_reg                          <=      0;
                rx_data_reg                             <=      0;
                rx_num_reg                              <=      0;
            end
            else begin
                seq_number_store_resize                 <=       0;
                rx_not_stored_user_tvalid_resize        <=       0;
                rx_not_stored_user_tdata_resize         <=       0;
                rx_not_stored_user_tkeep_resize         <=       0;
            end
        end
    end

endmodule
