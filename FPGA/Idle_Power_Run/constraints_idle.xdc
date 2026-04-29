set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]

## 12 MHz clock (Cmod A7)
set_property -dict { PACKAGE_PIN L17 IOSTANDARD LVCMOS33 } [get_ports { clk }]
create_clock -add -name sys_clk_pin -period 83.33 -waveform {0 41.66} [get_ports { clk }]

## UART output from FPGA to FTDI/PC (FPGA -> PC)
set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS33 } [get_ports { uart_rxd_out }]