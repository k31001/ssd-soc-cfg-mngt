// SPDX-License-Identifier: Apache-2.0
// Top: ssd_soc_top
// Virtual SSD Controller SoC — Top-level integration (STUB).

`include "ssd_soc_pkg.svh"

module ssd_soc_top (
  input  logic        clk,
  input  logic        rst_n,
  // External pads (stubbed)
  output logic [3:0]  pcie_tx_p, pcie_tx_n,
  input  logic [3:0]  pcie_rx_p, pcie_rx_n,
  inout  wire  [63:0] ddr_dq,
  output logic [7:0]  nand_ce_n,
  inout  wire  [7:0]  nand_dq
);

  // SoC interconnect (placeholder)
  axi_if #(.ADDR_W(40), .DATA_W(64)) sys_axi();
  apb_if #(.ADDR_W(32), .DATA_W(32)) sys_apb();

  // synthesis translate_off
  initial $display("[STUB] ssd_soc_top instantiated");
  // synthesis translate_on

  host_ss u_host_ss (.clk(clk), .rst_n(rst_n), .s_axi(sys_axi), .s_apb(sys_apb));
  fcc_ss u_fcc_ss (.clk(clk), .rst_n(rst_n), .s_axi(sys_axi), .s_apb(sys_apb));
  mem_ss u_mem_ss (.clk(clk), .rst_n(rst_n), .s_axi(sys_axi), .s_apb(sys_apb));
  cpu_ss u_cpu_ss (.clk(clk), .rst_n(rst_n), .s_axi(sys_axi), .s_apb(sys_apb));
  sec_ss u_sec_ss (.clk(clk), .rst_n(rst_n), .s_axi(sys_axi), .s_apb(sys_apb));

  // Tie-offs for pads
  assign pcie_tx_p = '0;
  assign pcie_tx_n = '0;
  assign nand_ce_n = '1;

endmodule
