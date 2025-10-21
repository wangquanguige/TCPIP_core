`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/06/26 12:59:29
// Design Name: 
// Module Name: tb_Top
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


`timescale 1ns/1ps

module tb_Top;

    // 参数定义
    parameter TCP_DATA_LENGTH = 40;
    parameter CLOCK_PERIOD = 6.4;  // 156.25MHz时钟周期 (1/156.25MHz ≈ 6.4ns)

    // 信号声明
    reg CLK_IN_D_0_clk_p;
    reg CLK_IN_D_0_clk_n;
    reg GT_DIFF_REFCLK1_0_clk_p;
    reg GT_DIFF_REFCLK1_0_clk_n;
    wire ETH_TXP;
    wire ETH_TXN;
    wire ETH_RXP;
    wire ETH_RXN;
    
    // 内部信号监控
    wire core_ready;
    wire s_axi_aclk;
    wire clk_250M;
    wire clk_156_25M;
    wire reset;
    wire fifo_reset;
    wire coreclk_out;
    wire [3:0] tcp_state_out;
    
    wire s_axis_tvalid;
    wire s_axis_tready;
    wire [63:0] s_axis_tdata;
    wire [7:0] s_axis_tkeep;
    wire m_axis_tvalid;
    wire m_axis_tready;
    wire [63:0] m_axis_tdata;
    wire [7:0] m_axis_tkeep;
    
    wire user_checksum_rd_en;
    wire [15:0] user_checksum_dout;
    wire user_checksum_empty;
    
    wire packet_loss_signal;

    // 实例化被测模块
    Top #(
        .TCP_DATA_LENGTH(TCP_DATA_LENGTH)
    )
    uut (
        .CLK_IN_D_0_clk_p(CLK_IN_D_0_clk_p),
        .CLK_IN_D_0_clk_n(CLK_IN_D_0_clk_n),
        .GT_DIFF_REFCLK1_0_clk_p(GT_DIFF_REFCLK1_0_clk_p),
        .GT_DIFF_REFCLK1_0_clk_n(GT_DIFF_REFCLK1_0_clk_n),
        .ETH_TXP(ETH_TXP),
        .ETH_TXN(ETH_TXN),
        .ETH_RXP(ETH_RXP),
        .ETH_RXN(ETH_RXN)
    );

    // 时钟生成器
    initial begin
        // 初始化时钟信号
        CLK_IN_D_0_clk_p = 0;
        CLK_IN_D_0_clk_n = 1;
        GT_DIFF_REFCLK1_0_clk_p = 0;
        GT_DIFF_REFCLK1_0_clk_n = 1;
        
        // 生成时钟
        forever begin
            #(CLOCK_PERIOD/2) CLK_IN_D_0_clk_p = ~CLK_IN_D_0_clk_p;
            #(CLOCK_PERIOD/2) CLK_IN_D_0_clk_n = ~CLK_IN_D_0_clk_n;
        end
    end
    
    // 参考时钟生成器 (156.25MHz)
    initial begin
        forever begin
            #(CLOCK_PERIOD/2) GT_DIFF_REFCLK1_0_clk_p = ~GT_DIFF_REFCLK1_0_clk_p;
            #(CLOCK_PERIOD/2) GT_DIFF_REFCLK1_0_clk_n = ~GT_DIFF_REFCLK1_0_clk_n;
        end
    end

    // 复位控制
    reg tb_reset;
    initial begin
        tb_reset = 1;  // 初始复位
        #100;          // 保持复位100ns
        tb_reset = 0;  // 释放复位
        #10000;        // 运行仿真一段时间
        $finish;       // 结束仿真
    end
    
    // 连接测试平台复位到被测模块
    assign reset = tb_reset;

    // 以太网接收信号模拟
    reg eth_rx_valid;
    reg [63:0] eth_rx_data;
    reg [7:0] eth_rx_keep;
    
    // 模拟以太网接收数据
    initial begin
        eth_rx_valid = 0;
        eth_rx_data = 0;
        eth_rx_keep = 0;
        
        // 等待系统复位完成
        @(negedge tb_reset);
        #200;  // 额外延迟，确保系统稳定
        
        // 模拟数据包传输
        repeat (5) begin
            // 等待接收就绪
            @(posedge coreclk_out);
            while (!m_axis_tready) @(posedge coreclk_out);
            
            // 发送数据包
            eth_rx_valid = 1;
            eth_rx_data = $random;  // 随机数据
            eth_rx_keep = 8'hFF;   // 全部有效字节
            @(posedge coreclk_out);
            eth_rx_valid = 0;
            
            // 数据包之间的间隔
            #(CLOCK_PERIOD * 10);
        end
    end
    
    // 连接模拟的以太网接收信号到被测模块
    assign ETH_RXP = eth_rx_valid;
    assign ETH_RXN = ~eth_rx_valid;

    // 监控关键信号
    initial begin
        /*$monitor("Time: %0t, Core Ready: %b, TCP State: %h, Packet Loss: %b",
                 $time, core_ready, tcp_state_out, packet_loss_signal);
        
        // 记录波形
        $dumpfile("tb_Top.vcd");
        $dumpvars(0, tb_Top);*/

        
    end

endmodule
