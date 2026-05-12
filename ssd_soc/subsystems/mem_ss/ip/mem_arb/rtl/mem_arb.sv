// SPDX-License-Identifier: Apache-2.0
// IP: mem_arb
// Memory arbiter / QoS
//
// NOTE: 본 파일은 형상관리 시스템 데모를 위한 STUB RTL입니다.
//       실제 합성 가능한 구현은 IP-owner 팀이 채워야 합니다.

`ifndef MEM_ARB_SV
`define MEM_ARB_SV

module mem_arb #(
  parameter int PORTS = 8
) (
  input  logic        clk,
  input  logic        rst_n,
  apb_if.slave        s_apb
);

  // ─────────── STUB BODY ───────────
  // synthesis translate_off
  initial begin
    $display("[STUB] %m instantiated, PORTS=%0d", PORTS);
  end
  // synthesis translate_on

  // Stub tie-offs intentionally omitted (interfaces only).

endmodule

`endif // MEM_ARB_SV
