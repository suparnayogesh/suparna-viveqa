## ============================================================
## secure_boot.xdc
## Pin constraints for Mini Secure-Boot SHA-256 demo
## AT-STLN-ARTIX7-001
## ============================================================

## System clock - 24 MHz oscillator
create_clock -period 41.667 -name sys_clk [get_ports clk_24mhz]
set_property -dict {PACKAGE_PIN D13 IOSTANDARD LVCMOS33} [get_ports clk_24mhz]

## UART RX input - PMOD J16, IO_0 (jumper this to J13 pin 6 / ESP_TX)
set_property -dict {PACKAGE_PIN T2 IOSTANDARD LVCMOS33} [get_ports uart_rx_pin]

## Status LEDs (Bank 35)
set_property -dict {PACKAGE_PIN D5 IOSTANDARD LVCMOS33} [get_ports led_pass]
set_property -dict {PACKAGE_PIN A3 IOSTANDARD LVCMOS33} [get_ports led_fail]
set_property -dict {PACKAGE_PIN B4 IOSTANDARD LVCMOS33} [get_ports led_busy]

## 16x2 LCD (Bank 35)
set_property -dict {PACKAGE_PIN G4 IOSTANDARD LVCMOS33} [get_ports lcd_rs]
set_property -dict {PACKAGE_PIN H3 IOSTANDARD LVCMOS33} [get_ports lcd_rw]
set_property -dict {PACKAGE_PIN E1 IOSTANDARD LVCMOS33} [get_ports lcd_e]
set_property -dict {PACKAGE_PIN G2 IOSTANDARD LVCMOS33} [get_ports {lcd_d[0]}]
set_property -dict {PACKAGE_PIN G1 IOSTANDARD LVCMOS33} [get_ports {lcd_d[1]}]
set_property -dict {PACKAGE_PIN H5 IOSTANDARD LVCMOS33} [get_ports {lcd_d[2]}]
set_property -dict {PACKAGE_PIN H4 IOSTANDARD LVCMOS33} [get_ports {lcd_d[3]}]
set_property -dict {PACKAGE_PIN J5 IOSTANDARD LVCMOS33} [get_ports {lcd_d[4]}]
set_property -dict {PACKAGE_PIN J4 IOSTANDARD LVCMOS33} [get_ports {lcd_d[5]}]
set_property -dict {PACKAGE_PIN H2 IOSTANDARD LVCMOS33} [get_ports {lcd_d[6]}]
set_property -dict {PACKAGE_PIN H1 IOSTANDARD LVCMOS33} [get_ports {lcd_d[7]}]

## Buzzer (Bank 35)
set_property -dict {PACKAGE_PIN K5 IOSTANDARD LVCMOS33} [get_ports buzzer_out]
