// SPDX-License-Identifier: Apache-2.0
// Subsystem: sec_ss
// Security subsystem (crypto + secure boot)
//
// 본 wrapper는 소속 IP들을 단순 인스턴스화한 STUB 입니다.

`include "ssd_soc_pkg.svh"

module sec_ss (
  input  logic clk,
  input  logic rst_n,
  axi_if.slave s_axi,
  apb_if.slave s_apb
);
  // synthesis translate_off
  initial $display("[STUB] subsystem %m instantiated");
  // synthesis translate_on

  // ── aes_engine ──
  aes_engine u_aes_engine (.clk(clk), .rst_n(rst_n), .s_axi(s_axi));
  // ── sha_engine ──
  sha_engine u_sha_engine (.clk(clk), .rst_n(rst_n), .s_axi(s_axi));
  // ── trng ──
  trng u_trng (.clk(clk), .rst_n(rst_n), .s_apb(s_apb));
  // ── secure_boot_rom ──
  secure_boot_rom u_secure_boot_rom (.clk(clk), .rst_n(rst_n), .s_axi(s_axi));
  // ── key_store ──
  key_store u_key_store (.clk(clk), .rst_n(rst_n), .s_apb(s_apb));
endmodule
