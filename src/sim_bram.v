`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/09/26 15:09:14
// Design Name: 
// Module Name: sim_bram
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

module sim_bram();
reg clk;//时钟输入
reg wea;//写使能
reg[13:0] addra;//地址输入
reg[13:0] addrb;//地址输入
reg[63:0] dina;//数据输入
wire[63:0] douta;//数据输出
reg[13:0] cnt1,cnt2;
initial begin
    clk=0;
    wea=0;
    cnt1=0;
    cnt2=0;
end
BRAM_test uut(//调用被仿真的模块完成内存读写
.clk(clk),
.ena(1),
.wea(wea),
.addra(addra),
.addrb(addrb),
.dina(dina),
.douta(douta)
);
always #10 clk=~clk;//周期20ns，模拟50M时钟
always@(posedge clk)
begin
    if(cnt1==8)
    begin
        cnt1=0;
        cnt2=cnt2+1;//cnt2低位每9个周期翻转一次
    end
    else
        cnt1=cnt1+1;
end
//负边沿写地址，写数据输入，写使能信号，保证时钟上升沿时这些值是稳定的
always@(negedge clk)
begin
    dina=cnt1;//数据输入总线是哪个的值是计数值cnt1
    addra=cnt1;
    addrb=cnt1;
    if(cnt2[0]==0) wea=0;//每9个周期写使能翻转
    else wea=1;
end
endmodule
