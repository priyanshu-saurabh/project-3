set_property -dict { PACKAGE_PIN F6    IOSTANDARD LVCMOS33 } [get_ports { green_led }]; #IO_L19N_T3_VREF_35 Sch=led0_g
set_property -dict { PACKAGE_PIN G3    IOSTANDARD LVCMOS33 } [get_ports { red_led }]; #IO_L20N_T3_35 Sch=led1_r
set_property -dict { PACKAGE_PIN A8    IOSTANDARD LVCMOS33 } [get_ports { sw0 }]; #IO_L12N_T1_MRCC_16 Sch=sw[0]

set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk }]; #IO_L12P_T1_MRCC_35 Sch=gclk[100]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];
set_property -dict { PACKAGE_PIN D9  IOSTANDARD LVCMOS33 } [get_ports rst]

set_property -dict { PACKAGE_PIN D10   IOSTANDARD LVCMOS33 } [get_ports { uart_tx_out }]; #IO_L19N_T3_VREF_16 Sch=uart_rxd_out
set_property -dict { PACKAGE_PIN A9    IOSTANDARD LVCMOS33 } [get_ports { uart_rx_in }]; #IO_L14N_T2_SRCC_16 Sch=uart_txd_in
