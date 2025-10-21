#set_property PACKAGE_PIN AH18 [get_ports CLK_IN_D_0_clk_p]
#set_property IOSTANDARD DIFF_POD12_DCI [get_ports CLK_IN_D_0_clk_p]
#
#set_property PACKAGE_PIN V6 [get_ports GT_DIFF_REFCLK1_0_clk_p]
#
#set_property PACKAGE_PIN P2 [get_ports ETH_RXP]
#set_property PACKAGE_PIN R4 [get_ports ETH_TXP]
#set_property -dict {PACKAGE_PIN AF13 IOSTANDARD LVCMOS33} [get_ports sfp_diasble]
#set_property OFFCHIP_TERM NONE [get_ports sfp_diasble]

#create_clock -period 10.000 -name GT_DIFF_REFCLK1_0_clk_p -waveform {0.000 5.000} [get_ports GT_DIFF_REFCLK1_0_clk_p]
#create_generated_clock -name clk_1M -source [get_pins clk_wiz_i0/inst/mmcme3_adv_inst/CLKOUT0] -divide_by 10 [get_pins clk_1M_reg/Q]


set_property PACKAGE_PIN AB30 [get_ports CLK_IN_D_0_clk_p]
set_property IOSTANDARD LVDS [get_ports CLK_IN_D_0_clk_p]
set_property DIFF_TERM_ADV TERM_100 [get_ports CLK_IN_D_0_clk_p]

set_property PACKAGE_PIN L29 [get_ports GT_DIFF_REFCLK1_0_clk_p]
set_property PACKAGE_PIN J33 [get_ports ETH_RXP]
set_property PACKAGE_PIN K31 [get_ports ETH_TXP]
#set_property PACKAGE_PIN G33 [get_ports ETH_RXP]
#set_property PACKAGE_PIN H31 [get_ports ETH_TXP]


#spi x4 烧写配置
#set_property CONFIG_MODE SPIx4 [current_design]
#set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
#set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
#
#set_property BITSTREAM.CONFIG.UNUSEDPIN Pulldown [current_design]
#

