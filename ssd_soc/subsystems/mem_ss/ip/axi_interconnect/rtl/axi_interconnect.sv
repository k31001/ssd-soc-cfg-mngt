// SPDX-License-Identifier: Apache-2.0
// IP: axi_interconnect
// SoC-level AXI interconnect (NoC stub)
//
// NOTE: 본 파일은 형상관리 시스템 데모를 위한 STUB RTL입니다.
//       실제 합성 가능한 구현은 IP-owner 팀이 채워야 합니다.

`ifndef AXI_INTERCONNECT_SV
`define AXI_INTERCONNECT_SV

module axi_interconnect #(
  parameter int NUM_MASTERS = 8,
  parameter int NUM_SLAVES = 12
) (
  input  logic        clk,
  input  logic        rst_n,
  axi_if.slave        s_axi
);

  // ─────────── STUB BODY ───────────
  // synthesis translate_off
  initial begin
    $display("[STUB] %m instantiated, NUM_MASTERS=%0d, NUM_SLAVES=%0d", NUM_MASTERS, NUM_SLAVES);
  end
  // synthesis translate_on

  // Stub tie-offs intentionally omitted (interfaces only).

endmodule

`endif // AXI_INTERCONNECT_SV
