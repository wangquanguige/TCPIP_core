`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/06/30 20:41:45
// Design Name: 
// Module Name: ddr4_demo
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


module ddr4_demo;

    // 参数定义
    parameter TCP_DATA_LENGTH = 1456;
    parameter DDR4_CLK_PERIOD = 8;  // 假设DDR4时钟为125MHz（8ns周期）
    parameter SIM_TIME = 100000;    // 仿真时间(ns)

    // 输入信号（reg类型）
    reg                     CLK_IN_D_0_clk_p;
    reg                     CLK_IN_D_0_clk_n;
    reg                     reset;

    // 输出信号（wire类型）
    wire                    c0_ddr4_act_n;
    wire        [16:0]      c0_ddr4_adr;
    wire        [1:0]       c0_ddr4_ba;
    wire        [0:0]       c0_ddr4_bg;
    wire        [0:0]       c0_ddr4_cke;
    wire        [0:0]       c0_ddr4_odt;
    wire        [0:0]       c0_ddr4_cs_n;
    wire        [0:0]       c0_ddr4_ck_t;
    wire        [0:0]       c0_ddr4_ck_c;
    wire                    c0_ddr4_reset_n;
    wire       [7:0]       c0_ddr4_dm_dbi_n;
    wire       [63:0]      c0_ddr4_dq;
    wire       [7:0]       c0_ddr4_dqs_t;
    wire       [7:0]       c0_ddr4_dqs_c;

    // 内部信号 - 连接Top模块的调试信号
    reg                     c0_ddr4_app_en;
    reg                     c0_ddr4_app_hi_pri;
    reg         [2:0]       c0_ddr4_app_cmd;
    wire                    c0_ddr4_app_rdy;
    reg         [28:0]      c0_ddr4_app_addr;

    reg                     c0_ddr4_app_wdf_end;
    reg                     c0_ddr4_app_wdf_wren;
    wire                    c0_ddr4_app_wdf_rdy;
    reg         [511:0]     c0_ddr4_app_wdf_data;
    reg         [63:0]      c0_ddr4_app_wdf_mask;

    wire                    c0_ddr4_app_rd_data_end;
    wire                    c0_ddr4_app_rd_data_valid;
    wire        [511:0]     c0_ddr4_app_rd_data;

    // 存储测试数据
    reg [511:0] write_data [0:15];  // 写数据缓冲区
    reg [511:0] read_data [0:15];   // 读数据验证缓冲区
    integer i;

    // 实例化Top模块
    Top #(
        .TCP_DATA_LENGTH      (TCP_DATA_LENGTH)
    ) u_top (
        .CLK_IN_D_0_clk_p     (CLK_IN_D_0_clk_p),
        .CLK_IN_D_0_clk_n     (CLK_IN_D_0_clk_n),
        .c0_ddr4_act_n        (c0_ddr4_act_n),
        .c0_ddr4_adr          (c0_ddr4_adr),
        .c0_ddr4_ba           (c0_ddr4_ba),
        .c0_ddr4_bg           (c0_ddr4_bg),
        .c0_ddr4_cke          (c0_ddr4_cke),
        .c0_ddr4_odt          (c0_ddr4_odt),
        .c0_ddr4_cs_n         (c0_ddr4_cs_n),
        .c0_ddr4_ck_t         (c0_ddr4_ck_t),
        .c0_ddr4_ck_c         (c0_ddr4_ck_c),
        .c0_ddr4_reset_n      (c0_ddr4_reset_n),
        .c0_ddr4_dm_dbi_n     (c0_ddr4_dm_dbi_n),
        .c0_ddr4_dq           (c0_ddr4_dq),
        .c0_ddr4_dqs_t        (c0_ddr4_dqs_t),
        .c0_ddr4_dqs_c        (c0_ddr4_dqs_c),
        .c0_ddr4_app_en       (c0_ddr4_app_en),
        .c0_ddr4_app_hi_pri   (c0_ddr4_app_hi_pri),
        .c0_ddr4_app_cmd      (c0_ddr4_app_cmd),
        .c0_ddr4_app_rdy      (c0_ddr4_app_rdy),
        .c0_ddr4_app_addr     (c0_ddr4_app_addr),
        .c0_ddr4_app_wdf_end  (c0_ddr4_app_wdf_end),
        .c0_ddr4_app_wdf_wren (c0_ddr4_app_wdf_wren),
        .c0_ddr4_app_wdf_rdy  (c0_ddr4_app_wdf_rdy),
        .c0_ddr4_app_wdf_data (c0_ddr4_app_wdf_data),
        .c0_ddr4_app_wdf_mask (c0_ddr4_app_wdf_mask),
        .c0_ddr4_app_rd_data_end  (c0_ddr4_app_rd_data_end),
        .c0_ddr4_app_rd_data_valid (c0_ddr4_app_rd_data_valid),
        .c0_ddr4_app_rd_data       (c0_ddr4_app_rd_data)
    );

    // 差分时钟生成
    always begin
        CLK_IN_D_0_clk_p = 1'b0;
        CLK_IN_D_0_clk_n = 1'b1;
        #(DDR4_CLK_PERIOD/2);
        CLK_IN_D_0_clk_p = 1'b1;
        CLK_IN_D_0_clk_n = 1'b0;
        #(DDR4_CLK_PERIOD/2);
    end

    // 复位信号生成
    initial begin
        reset = 1'b1;
        #100;
        reset = 1'b0;
    end

    // 初始化测试数据
    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            write_data[i] = {512'h0, i};  // 生成带索引的测试数据
            read_data[i] = 512'h0;
        end
    end

    // DDR4操作控制状态机
    localparam IDLE = 0,
               WAIT_CALIB = 1,
               WRITE_DATA = 2,
               READ_DATA = 3,
               CHECK_DATA = 4,
               DONE = 5;
    reg [2:0] state = IDLE;
    reg [3:0] write_addr = 0;
    reg [3:0] read_addr = 0;
    reg [15:0] calib_counter = 0;
    reg calib_complete = 0;

    // 状态机逻辑
    always @(posedge u_top.your_instance_name.c0_sys_clk_p or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            c0_ddr4_app_en <= 1'b0;
            c0_ddr4_app_cmd <= 3'b0;
            c0_ddr4_app_addr <= 29'b0;
            c0_ddr4_app_wdf_wren <= 1'b0;
            c0_ddr4_app_wdf_data <= 512'b0;
            c0_ddr4_app_wdf_end <= 1'b0;
            c0_ddr4_app_hi_pri <= 1'b0;
            calib_complete <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    // 等待校准完成（假设从ddr4_0模块获取）
                    if (u_top.your_instance_name.c0_init_calib_complete) begin
                        calib_complete <= 1'b1;
                        state <= WAIT_CALIB;
                    end
                end
                
                WAIT_CALIB: begin
                    // 等待校准稳定
                    if (calib_counter >= 16'h100) begin
                        state <= WRITE_DATA;
                        calib_counter <= 16'h0;
                    end else begin
                        calib_counter <= calib_counter + 1'b1;
                    end
                end
                
                WRITE_DATA: begin
                    // 写数据到DDR4
                    if (write_addr < 16) begin
                        // 等待命令通道就绪
                        if (c0_ddr4_app_rdy && c0_ddr4_app_wdf_rdy) begin
                            c0_ddr4_app_en <= 1'b1;
                            c0_ddr4_app_cmd <= 3'b000;  // 写命令
                            c0_ddr4_app_addr <= {29'h0, write_addr[3:0]};  // 地址 = 0 + 写地址
                            
                            c0_ddr4_app_wdf_wren <= 1'b1;
                            c0_ddr4_app_wdf_data <= write_data[write_addr];
                            
                            if (write_addr == 15) begin
                                c0_ddr4_app_wdf_end <= 1'b1;
                            end else begin
                                c0_ddr4_app_wdf_end <= 1'b0;
                            end
                            
                            write_addr <= write_addr + 1'b1;
                        end else begin
                            c0_ddr4_app_en <= 1'b0;
                            c0_ddr4_app_wdf_wren <= 1'b0;
                            c0_ddr4_app_wdf_end <= 1'b0;
                        end
                    end else begin
                        // 写完所有数据，准备读操作
                        write_addr <= 4'h0;
                        state <= READ_DATA;
                    end
                end
                
                READ_DATA: begin
                    // 从DDR4读数据
                    if (read_addr < 16) begin
                        // 等待命令通道就绪
                        if (c0_ddr4_app_rdy) begin
                            c0_ddr4_app_en <= 1'b1;
                            c0_ddr4_app_cmd <= 3'b001;  // 读命令
                            c0_ddr4_app_addr <= {29'h0, read_addr[3:0]};  // 读取之前写入的地址
                        end else begin
                            c0_ddr4_app_en <= 1'b0;
                        end
                        
                        // 捕获读数据
                        if (c0_ddr4_app_rd_data_valid) begin
                            read_data[read_addr] <= c0_ddr4_app_rd_data;
                            read_addr <= read_addr + 1'b1;
                        end
                    end else begin
                        // 读完所有数据，准备验证
                        read_addr <= 4'h0;
                        state <= CHECK_DATA;
                    end
                end
                
                CHECK_DATA: begin
                    // 验证读写数据一致性
                    if (read_addr < 16) begin
                        if (read_data[read_addr] == write_data[read_addr]) begin
                            $display("数据验证通过 - 地址 %h: 写入 %h, 读取 %h", 
                                     read_addr, write_data[read_addr], read_data[read_addr]);
                        end else begin
                            $error("数据验证失败 - 地址 %h: 写入 %h, 读取 %h", 
                                   read_addr, write_data[read_addr], read_data[read_addr]);
                        end
                        read_addr <= read_addr + 1'b1;
                    end else begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    // 仿真结束
                    $display("DDR4读写测试完成");
                    $finish;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // 三态控制（处理inout信号）
    assign c0_ddr4_dm_dbi_n = (c0_ddr4_app_wdf_wren && c0_ddr4_app_wdf_rdy) ? 8'b0 : 8'bz;
    assign c0_ddr4_dq = (c0_ddr4_app_wdf_wren && c0_ddr4_app_wdf_rdy) ? c0_ddr4_app_wdf_data[63:0] : 64'bz;
    assign c0_ddr4_dqs_t = (c0_ddr4_app_wdf_wren && c0_ddr4_app_wdf_rdy) ? 8'b0 : 8'bz;
    assign c0_ddr4_dqs_c = (c0_ddr4_app_wdf_wren && c0_ddr4_app_wdf_rdy) ? 8'b0 : 8'bz;

endmodule
