// SPDX-License-Identifier: Apache-2.0
// Subsystem: fcc_ss
// Flash Channel Controller subsystem (NAND interface)
//
// 본 wrapper는 소속 IP들을 단순 인스턴스화한 STUB 입니다.

`include "ssd_soc_pkg.svh"

module fcc_ss (
  input  logic clk,
  input  logic rst_n,
  axi_if.slave s_axi,
  apb_if.slave s_apb
);
  // synthesis translate_off
  initial $display("[STUB] subsystem %m instantiated");
  // synthesis translate_on

  // ── nand_phy ──
  nand_phy u_nand_phy (.clk(clk), .rst_n(rst_n), .s_axi(s_axi));
  // ── nand_ctrl ──
  nand_ctrl u_nand_ctrl (.clk(clk), .rst_n(rst_n), .s_axi(s_axi));
  // ── ldpc_codec ──
  ldpc_codec u_ldpc_codec (.clk(clk), .rst_n(rst_n), .s_axi(s_axi));
  // ── flash_dma ──
  flash_dma u_flash_dma (.clk(clk), .rst_n(rst_n), .s_axi(s_axi));
  // ── bbm ──
  bbm u_bbm (.clk(clk), .rst_n(rst_n), .s_apb(s_apb));
endmodule
