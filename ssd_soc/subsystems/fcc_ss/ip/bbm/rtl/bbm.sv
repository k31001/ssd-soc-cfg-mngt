// SPDX-License-Identifier: Apache-2.0
// IP: bbm
// Bad block manager / WL helper
//
// NOTE: 본 파일은 형상관리 시스템 데모를 위한 STUB RTL입니다.
//       실제 합성 가능한 구현은 IP-owner 팀이 채워야 합니다.

`ifndef BBM_SV
`define BBM_SV

module bbm #(
  parameter int BLOCKS = 4096
) (
  input  logic        clk,
  input  logic        rst_n,
  apb_if.slave        s_apb
);

  // ─────────── STUB BODY ───────────
  // synthesis translate_off
  initial begin
    $display("[STUB] %m instantiated, BLOCKS=%0d", BLOCKS);
  end
  // synthesis translate_on

  // Stub tie-offs intentionally omitted (interfaces only).

endmodule

`endif // BBM_SV
