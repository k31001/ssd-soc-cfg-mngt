// SPDX-License-Identifier: Apache-2.0
// IP: debug_module
// RISC-V debug module (JTAG/DM)
//
// NOTE: 본 파일은 형상관리 시스템 데모를 위한 STUB RTL입니다.
//       실제 합성 가능한 구현은 IP-owner 팀이 채워야 합니다.

`ifndef DEBUG_MODULE_SV
`define DEBUG_MODULE_SV

module debug_module #(
  parameter int HARTS = 1
) (
  input  logic        clk,
  input  logic        rst_n,
  apb_if.slave        s_apb
);

  // ─────────── STUB BODY ───────────
  // synthesis translate_off
  initial begin
    $display("[STUB] %m instantiated, HARTS=%0d", HARTS);
  end
  // synthesis translate_on

  // Stub tie-offs intentionally omitted (interfaces only).

endmodule

`endif // DEBUG_MODULE_SV
