# SoC Components 

Collection of util SoC components used through different personal RTL projects.

`axi_crossbar_wrapper.sv` - Wrapper around [axi_crossbar](https://github.com/aignacio/verilog-axi/blob/master/rtl/axi_crossbar.v) from **verilog-axi**' using SV structs from [bus_arch_sv_pkg](https://github.com/aignacio/bus_arch_sv_pkg);

`axi_interconnect_wrapper.sv` - Wrapper around [axi_interconnect](https://github.com/aignacio/verilog-axi/blob/master/rtl/axi_interconnect.v) from **verilog-axi** using SV structs from [bus_arch_sv_pkg](https://github.com/aignacio/bus_arch_sv_pkg);

`axi_mem_wrapper.sv` - Wrapper around [axi_ram](https://github.com/aignacio/verilog-axi/blob/master/rtl/axi_ram_wo_reset.v) from **verilog-axi** with the additional change of set initial value;

`axi_rom_wrapper.sv` - Wrapper for ROM memory module generated through the python script;

`axi_rst_ctrl.sv` - Reset Controller with a dedicated register to be used as printf mirroring for sims;

`axi_spi_master.sv` - SPI Master controller;

`axi_timer.sv` - Simple timer with IRQ output;

`axi_uart_wrapper.sv` - Wrapper around **wbuart32** using SV structs from [bus_arch_sv_pkg](https://github.com/aignacio/bus_arch_sv_pkg);

`axi_irq_ctrl.sv` - IRQ controller capable of handling up to 32x IRQs with sync. FIFO;

`axil_to_axi.sv` - Simple bridge between AXI to AXI-Lite;

`cdc_2ff_sync.sv` - Simple 2ff synchronizer;

`cdc_async_fifo.sv` - Asynchronous FIFO with gray ptrs;
