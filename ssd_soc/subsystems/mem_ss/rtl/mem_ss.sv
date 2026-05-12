// SPDX-License-Identifier: Apache-2.0
// Subsystem: mem_ss
// On-die memory and interconnect subsystem
//
// 본 wrapper는 소속 IP들을 단순 인스턴스화한 STUB 입니다.

`include "ssd_soc_pkg.svh"

module mem_ss (
  input  logic clk,
  input  logic rst_n,
  axi_if.slave s_axi,
  apb_if.slave s_apb
);
  // synthesis translate_off
  initial $display("[STUB] subsystem %m instantiated");
  // synthesis translate_on

  // ── ddr4_ctrl ──
  ddr4_ctrl u_ddr4_ctrl (.clk(clk), .rst_n(rst_n), .s_axi(s_axi));
  // ── ddr4_phy ──
  ddr4_phy u_ddr4_phy (.clk(clk), .rst_n(rst_n), .s_axi(s_axi));
  // ── sram_scratchpad ──
  sram_scratchpad u_sram_scratchpad (.clk(clk), .rst_n(rst_n), .s_axi(s_axi));
  // ── axi_interconnect ──
  axi_interconnect u_axi_interconnect (.clk(clk), .rst_n(rst_n), .s_axi(s_axi));
  // ── mem_arb ──
  mem_arb u_mem_arb (.clk(clk), .rst_n(rst_n), .s_apb(s_apb));
endmodule
