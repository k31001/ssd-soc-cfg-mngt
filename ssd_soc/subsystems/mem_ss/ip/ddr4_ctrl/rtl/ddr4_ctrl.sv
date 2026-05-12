// SPDX-License-Identifier: Apache-2.0
// IP: ddr4_ctrl
// DDR4 controller (command scheduler)
//
// NOTE: 본 파일은 형상관리 시스템 데모를 위한 STUB RTL입니다.
//       실제 합성 가능한 구현은 IP-owner 팀이 채워야 합니다.

`ifndef DDR4_CTRL_SV
`define DDR4_CTRL_SV

module ddr4_ctrl #(
  parameter int DATA_W = 64,
  parameter int RANKS = 2
) (
  input  logic        clk,
  input  logic        rst_n,
  axi_if.slave        s_axi
);

  // ─────────── STUB BODY ───────────
  // synthesis translate_off
  initial begin
    $display("[STUB] %m instantiated, DATA_W=%0d, RANKS=%0d", DATA_W, RANKS);
  end
  // synthesis translate_on

  // Stub tie-offs intentionally omitted (interfaces only).

endmodule

`endif // DDR4_CTRL_SV
