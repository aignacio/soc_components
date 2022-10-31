# SoC Components 

Collection of util SoC components used through different personal RTL projects.

`axi_crossbar_wrapper.sv` - Wrapper around [axi_crossbar](verilog-axi/axi_crossbar.v) from **verilog-axi**' using SV structs from [amba_sv_structs](amba_sv_structs);

`axi_interconnect_wrapper.sv` - Wrapper around [axi_interconnect](verilog-axi/axi_interconnect.v) from **verilog-axi** using SV structs from [amba_sv_structs](amba_sv_structs);

`axi_mem_wrapper.sv` - Wrapper around [axi_ram](verilog-axi/axi_ram_wo_reset.sv) from **verilog-axi** with the additional change of set initial value;

`axi_rom_wrapper.sv` - Wrapper for ROM memory module generated through the python script;

`axi_rst_ctrl.sv` - Reset Controller with a dedicated register to be used as printf mirroring for sims;

`axi_spi_master.sv` - SPI Master controller;

`axi_timer.sv` - Simple timer with IRQ output;

`axi_uart_wrapper.sv` - Wrapper around **wbuart32** using SV structs from [amba_sv_structs](amba_sv_structs);

`axil_to_axi.sv` - Simple bridge between AXI to AXI-Lite;

`cdc_2ff_sync.sv` - Simple 2ff synchronizer;

`cdc_async_fifo.sv` - Asynchronous FIFO with gray ptrs;
