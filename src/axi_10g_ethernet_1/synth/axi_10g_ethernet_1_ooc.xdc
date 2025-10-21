# This constraints file contains default clock frequencies to be used during creation of a
# Synthesis Design Checkpoint (DCP).
# This constraints file is not used in top-down/global synthesis (not the default flow of Vivado).

create_clock -period 20.000 [get_ports {dclk}]
set_property HD.CLK_SRC BUFGCTRL_X0Y0 [get_ports dclk]
create_clock -period 6.400 [get_ports {qpll0outrefclk}]
create_clock -period 0.193 [get_ports {qpll0outclk}]
create_clock -period 6.400 [get_ports {coreclk}]
create_clock -period 3.200 [get_ports {txusrclk}]
set_property HD.CLK_SRC BUFGCTRL_X0Y3 [get_ports txusrclk]
create_clock -period 6.400 [get_ports {txusrclk2}]
set_property HD.CLK_SRC BUFGCTRL_X0Y2 [get_ports txusrclk2]

