// SPDX-License-Identifier: Apache-2.0
// Subsystem: cpu_ss
// Embedded RISC-V CPU subsystem (FW execution)
//
// 본 wrapper는 소속 IP들을 단순 인스턴스화한 STUB 입니다.

`include "ssd_soc_pkg.svh"

module cpu_ss (
  input  logic clk,
  input  logic rst_n,
  axi_if.slave s_axi,
  apb_if.slave s_apb
);
  // synthesis translate_off
  initial $display("[STUB] subsystem %m instantiated");
  // synthesis translate_on

  // ── riscv_core ──
  riscv_core u_riscv_core (.clk(clk), .rst_n(rst_n), .s_axi(s_axi));
  // ── icache ──
  icache u_icache (.clk(clk), .rst_n(rst_n), .s_axi(s_axi));
  // ── dcache ──
  dcache u_dcache (.clk(clk), .rst_n(rst_n), .s_axi(s_axi));
  // ── debug_module ──
  debug_module u_debug_module (.clk(clk), .rst_n(rst_n), .s_apb(s_apb));
  // ── irq_ctrl ──
  irq_ctrl u_irq_ctrl (.clk(clk), .rst_n(rst_n), .s_apb(s_apb));
endmodule
