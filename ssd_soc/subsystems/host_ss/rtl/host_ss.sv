// SPDX-License-Identifier: Apache-2.0
// Subsystem: host_ss
// PCIe Gen4/NVMe host interface subsystem
//
// 본 wrapper는 소속 IP들을 단순 인스턴스화한 STUB 입니다.

`include "ssd_soc_pkg.svh"

module host_ss (
  input  logic clk,
  input  logic rst_n,
  axi_if.slave s_axi,
  apb_if.slave s_apb
);
  // synthesis translate_off
  initial $display("[STUB] subsystem %m instantiated");
  // synthesis translate_on

  // ── pcie_phy ──
  pcie_phy u_pcie_phy (.clk(clk), .rst_n(rst_n), .s_axi(s_axi));
  // ── pcie_ctrl ──
  pcie_ctrl u_pcie_ctrl (.clk(clk), .rst_n(rst_n), .s_axi(s_axi));
  // ── nvme_cmd_proc ──
  nvme_cmd_proc u_nvme_cmd_proc (.clk(clk), .rst_n(rst_n), .s_axi(s_axi));
  // ── host_dma ──
  host_dma u_host_dma (.clk(clk), .rst_n(rst_n), .s_axi(s_axi));
  // ── pcie_cfg ──
  pcie_cfg u_pcie_cfg (.clk(clk), .rst_n(rst_n), .s_apb(s_apb));
endmodule
