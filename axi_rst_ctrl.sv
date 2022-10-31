/**
 * File              : axi_rst_ctrl.sv
 * License           : MIT license <Check LICENSE>
 * Author            : Anderson Ignacio da Silva (aignacio) <anderson@aignacio.com>
 * Date              : 13.03.2022
 * Last Modified Date: 13.04.2022
 */
module axi_rst_ctrl
  import amba_axi_pkg::*;
  import amba_ahb_pkg::*;
#(
  parameter int RESET_VECTOR_ADDR = 32'h0,
  parameter int BASE_ADDR         = 32'h0
)(
  input                 clk,
  input                 rst,
  input                 bootloader_i, // Active-high
  input   s_axi_mosi_t  axi_mosi,
  output  s_axi_miso_t  axi_miso,
  output  logic [31:0]  rst_addr_o
);
  s_axi_mosi_t  axi_mosi_int;
  s_axi_miso_t  axi_miso_int;
  axi_tid_t     rid_ff, next_rid;
  axi_tid_t     wid_ff, next_wid;

  logic [31:0] rst_addr_ff, next_rst;
  logic        wr_rst_ff,   next_wr_rst;
  logic        rd_rst_ff,   next_rd_rst;
  logic        bvalid_ff,   next_bvalid;
  logic [31:0] rst_loading; // This reset loading is used by tb to change reset vector of the CPU during sims

`ifdef SIMULATION
  logic next_char, char_ff;

  function [7:0] getbufferReq;
    /* verilator public */
    begin
      getbufferReq = (axi_mosi.wdata[7:0]);
    end
  endfunction

  function printfbufferReq;
    /* verilator public */
    begin
      printfbufferReq = char_ff && axi_mosi.wvalid;
    end
  endfunction
`endif

  /* verilator lint_off WIDTH */
  always_comb begin
    next_rst    = rst_addr_ff;
    next_wr_rst = wr_rst_ff;
    next_rd_rst = rd_rst_ff;
    axi_miso    = s_axi_miso_t'('0);
    next_bvalid = bvalid_ff;
    rst_addr_o  = rst_addr_ff;

    axi_miso.awready = 1'b1;
    axi_miso.wready  = 1'b1;
    axi_miso.arready = 1'b1;
    axi_miso.bvalid  = bvalid_ff;

    if (axi_mosi.awvalid && ((axi_mosi.awaddr[15:0]-BASE_ADDR[15:0]) == 'h0000)) begin
      next_wr_rst = 1'b1;
    end

  `ifdef SIMULATION
    next_char = char_ff;

    if (axi_mosi.awvalid && ((axi_mosi.awaddr[15:0]-BASE_ADDR[15:0]) == 'h0010)) begin
      next_char = 1'b1;
    end

    if (axi_mosi.wvalid && char_ff) begin
      next_char   = 1'b0;
      next_bvalid = 'b1;
    end
  `endif

    if (axi_mosi.wvalid && wr_rst_ff) begin
      next_wr_rst = 1'b0;
      next_rst    = axi_mosi.wdata;
      next_bvalid = 'b1;
    end

    if (bvalid_ff) begin
      next_bvalid = axi_mosi.bready ? 'b0 : 'b1;
    end

    if (axi_mosi.arvalid && ((axi_mosi.araddr[15:0]-BASE_ADDR[15:0]) == '0)) begin
      next_rd_rst = 'b1;
    end

    if (rd_rst_ff) begin
      axi_miso.rvalid = 'b1;
      axi_miso.rlast  = 'b1;
      axi_miso.rdata  = rst_addr_ff;
      if (axi_mosi.rready) begin
        next_rd_rst = 'b0;
      end
    end

    next_rid = rid_ff;
    next_wid = wid_ff;
    axi_miso.rid = rid_ff;
    axi_miso.bid = wid_ff;

    if (axi_mosi.arvalid && axi_miso.arready) begin
      next_rid = axi_mosi.arid;
    end

    if (axi_mosi.awvalid && axi_miso.awready) begin
      next_wid = axi_mosi.awid;
    end
  end
  /* verilator lint_on WIDTH */

  always_ff @ (posedge clk) begin
    if (rst) begin
      rid_ff <= '0;
      wid_ff <= '0;
    end
    else begin
      rid_ff <= next_rid;
      wid_ff <= next_wid;
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      wr_rst_ff   <= '0;
      bvalid_ff   <= '0;
      rd_rst_ff   <= '0;
    `ifdef SIMULATION
      char_ff     <= 1'b0;
    `endif
    end
    else begin
      wr_rst_ff   <= next_wr_rst;
      bvalid_ff   <= next_bvalid;
      rd_rst_ff   <= next_rd_rst;
    `ifdef SIMULATION
      char_ff     <= next_char;
    `endif
    end
  end

  always_ff @ (posedge clk) begin
    if (bootloader_i) begin
      rst_addr_ff <= RESET_VECTOR_ADDR;
    end
    else begin
    `ifdef SIMULATION
      rst_addr_ff <= rst_loading;
    `else
      rst_addr_ff <= next_rst;
    `endif
    end
  end
endmodule
