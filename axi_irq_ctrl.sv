/**
 * File              : axi_irq_ctrl.sv
 * License           : MIT license <Check LICENSE>
 * Author            : Anderson Ignacio da Silva (aignacio) <anderson@aignacio.com>
 * Date              : 31.10.2022
 * Last Modified Date: 01.11.2022
 *
 * Simple AXI IRQ Controller
 * - Up to 32 IRQs support;
 * - Can individually mask each IRQ;
 * - Each IRQ can be either Level (0) or Edge (1) type;
 * - Interrupts are logged in a sync. FIFO;
 * - Edge: L-to-H / Level: H
 *
 * Priority:
 * - 0  - Highest priority
 * - 31 - Lower priority
 *
 * CSRs:
 *  _________________________________
 * |_Address_|_AC_|___Description____|
 * |   0x00  | R  | IRQ ID FIFO read |
 * |   0x04  | RW | IRQ Mask         |
 * |   0x08  | WO | IRQ FIFO Clear   |
 * |_________|____|__________________|
 *
 * */
module axi_irq_ctrl
  import amba_axi_pkg::*;
  import amba_ahb_pkg::*;
#(
  parameter int BASE_ADDR     = 32'h0,
  parameter int TYPE_OF_IRQ   = 32'h0, // Level (0) or Edge (1)
  parameter int DEPTH_OF_FIFO = 4      // Must be power of 2
)(
  input                 clk,
  input                 rst,
  input   [31:0]        irq_i,
  output  logic         irq_summary_o,
  input   s_axi_mosi_t  axi_mosi,
  output  s_axi_miso_t  axi_miso
);
  localparam IRQ_N_WIDTH = $clog2(32);

  typedef struct packed {
    logic         vld;
    logic [15:0]  addr;
  } s_axi_req_t;

  s_axi_mosi_t  axi_mosi_int;
  s_axi_miso_t  axi_miso_int;
  axi_tid_t     rid_ff, next_rid;
  axi_tid_t     bid_ff, next_bid;
  s_axi_req_t   wr_req_ff, next_wr_req;
  s_axi_req_t   rd_req_ff, next_rd_req;

  logic [31:0] irq_mask_ff, next_irq_mask;
  logic        fifo_empty;
  logic        clear_fifo;
  logic        rd_fifo;
  logic        wr_fifo;
  logic        rd_err_ff, next_rd_err;
  logic        wr_err_ff, next_wr_err;
  logic        bvalid_ff, next_bvalid;

  logic [IRQ_N_WIDTH-1:0] fifo_rd_data;
  logic [IRQ_N_WIDTH-1:0] fifo_wr_data;
  logic [31:0]            irq_trigger;
  logic [31:0]            sampled;

  for (genvar i=0; i<32; i++) begin
    irq_trigger #(
      .IRQ_TYPE  (TYPE_OF_IRQ[i])
    ) u_irq_trigger (
      .clk       (clk),
      .rst       (rst),
      .irq_i     (irq_i[i]),
      .sampled_i (sampled[i]),
      .trigger_o (irq_trigger[i])
    );
  end

  always_comb begin
    wr_fifo = 1'b0;
    fifo_wr_data = '0;
    sampled = '0;

    if (|irq_trigger) begin
      for (int i=0; i<32; i++) begin
        if (irq_trigger[i] && irq_mask_ff[i]) begin
          /* verilator lint_off WIDTH */
          wr_fifo = 1'b1;
          fifo_wr_data = i;
          sampled[i] = 1'b1;
          /* verilator lint_on WIDTH */
          break;
        end
      end
    end
  end

  always_comb begin
    // Default values for AXI Slave
    axi_miso = s_axi_miso_t'('0);

    // Always available to answer
    axi_miso.awready = 1'b1;
    axi_miso.wready  = 1'b1;
    axi_miso.arready = 1'b1;
    axi_miso.rid     = rid_ff;
    axi_miso.bid     = bid_ff;

    irq_summary_o = ~fifo_empty;

    rd_fifo     = 1'b0;
    clear_fifo  = 1'b0;
    next_wr_req = wr_req_ff;
    next_rd_req = rd_req_ff;
    next_rd_err = rd_err_ff;
    next_wr_err = wr_err_ff;
    next_bvalid = bvalid_ff;
    next_irq_mask = irq_mask_ff;

    next_rid = rid_ff;
    next_bid = bid_ff;

    // Write address phase
    if (axi_mosi.awvalid) begin
      next_bid = axi_mosi.awid;
      if (((axi_mosi.awaddr[15:0]-BASE_ADDR[15:0]) == 'h0004) ||
          ((axi_mosi.awaddr[15:0]-BASE_ADDR[15:0]) == 'h0008)) begin
        next_wr_req.vld   = 'b1;
        next_wr_req.addr  = axi_mosi.awaddr[15:0]-BASE_ADDR[15:0];
      end
      else begin
        next_wr_req.vld  = 1'b1;
        next_wr_err      = 1'b1;
      end
    end

    // Write data phase
    if (wr_req_ff.vld && axi_mosi.wvalid) begin
      if (~wr_err_ff) begin
        case (wr_req_ff.addr)
          'h0004: next_irq_mask = axi_mosi.wdata;
          'h0008: clear_fifo    = 1'b1;
        endcase
      end

      next_wr_req.vld = 'b0;
      next_bvalid     = 'b1;
    end

    // Write response
    if (bvalid_ff) begin
      axi_miso.bvalid = 'b1;
      axi_miso.bresp  = (wr_err_ff ? AXI_SLVERR : AXI_OKAY);
      next_wr_err     = axi_mosi.bready ? 1'b0 : wr_err_ff;
      next_bvalid     = ~axi_mosi.bready;
    end

    // Read address channel
    if (axi_mosi.arvalid) begin
      next_rid = axi_mosi.arid;
      if (((axi_mosi.araddr[15:0]-BASE_ADDR[15:0]) == 'h0000) ||
          ((axi_mosi.araddr[15:0]-BASE_ADDR[15:0]) == 'h0004)) begin
        next_rd_req.vld  = 'b1;
        next_rd_req.addr = axi_mosi.araddr[15:0]-BASE_ADDR[15:0];
      end
      else begin
        next_rd_req.vld  = 1'b1;
        next_rd_err      = 1'b1;
      end
    end

    // Read data phase
    if (rd_req_ff.vld) begin
      if (~rd_err_ff) begin
        case (rd_req_ff.addr)
          'h0000:  axi_miso.rdata = fifo_empty ? 'hFFFF_FFFF : {27'd0,fifo_rd_data};
          'h0004:  axi_miso.rdata = irq_mask_ff;
          default: axi_miso.rdata = '0;
        endcase
      end
      axi_miso.rresp  = (rd_err_ff ? AXI_SLVERR : AXI_OKAY);
      axi_miso.rvalid = 'b1;
      axi_miso.rlast  = 'b1;
      next_rd_req.vld = ~axi_mosi.rready;
      next_rd_err     = axi_mosi.rready ? 1'b0 : rd_err_ff;
      rd_fifo         = ~fifo_empty     &&
                        axi_miso.rvalid &&
                        axi_miso.rlast  &&
                        axi_mosi.rready;
    end
  end

  always_ff @ (posedge clk) begin
    if (rst) begin
      rid_ff      <= '0;
      bid_ff      <= '0;
      wr_req_ff   <= '0;
      rd_req_ff   <= '0;
      rd_err_ff   <= '0;
      wr_err_ff   <= '0;
      bvalid_ff   <= '0;
      irq_mask_ff <= '1;
    end
    else begin
      rid_ff      <= next_rid;
      bid_ff      <= next_bid;
      wr_req_ff   <= next_wr_req;
      rd_req_ff   <= next_rd_req;
      rd_err_ff   <= next_rd_err;
      wr_err_ff   <= next_wr_err;
      bvalid_ff   <= next_bvalid;
      irq_mask_ff <= next_irq_mask;
    end
  end

  sync_gp_fifo # (
    .SLOTS (DEPTH_OF_FIFO),
    .WIDTH (IRQ_N_WIDTH)
  ) u_sync_gp_fifo (
    .clk    (clk),
    .rst    (rst),
    .clear_i(clear_fifo),
    .write_i(wr_fifo),
    .read_i (rd_fifo),
    .data_i (fifo_wr_data),
    .data_o (fifo_rd_data),
    .error_o(),
    .full_o (),
    .empty_o(fifo_empty),
    .ocup_o (),
    .free_o ()
  );
endmodule

module irq_trigger #(
  parameter IRQ_TYPE = 1'b0 //Level (0) or Edge (1)
)(
  input        clk,
  input        rst,
  input        irq_i,
  input        sampled_i,
  output logic trigger_o
);
  logic trigger_ff, next_trigger;
  logic irq_st_ff, next_irq;

  always_comb begin
    if (trigger_ff) begin
      next_trigger = sampled_i ? 1'b0 : 1'b1;
    end
    else begin
      next_trigger = 1'b0;
    end

    next_irq = irq_i;

    if (IRQ_TYPE == 0) begin
      next_trigger = irq_i;
    end
    else begin
      next_trigger = (irq_st_ff == 1'b0) && (next_irq == 1'b1);
    end

    trigger_o = trigger_ff;
  end

  always_ff @ (posedge clk) begin
    if (rst) begin
      trigger_ff <= 1'b0;
      irq_st_ff  <= 1'b0;
    end
    else begin
      trigger_ff <= next_trigger;
      irq_st_ff  <= next_irq;
    end
  end
endmodule
