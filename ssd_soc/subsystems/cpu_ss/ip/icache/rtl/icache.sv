// SPDX-License-Identifier: Apache-2.0
// IP: icache
// Instruction cache 32KB 4-way
//
// NOTE: 본 파일은 형상관리 시스템 데모를 위한 STUB RTL입니다.
//       실제 합성 가능한 구현은 IP-owner 팀이 채워야 합니다.

`ifndef ICACHE_SV
`define ICACHE_SV

module icache #(
  parameter int SIZE_KB = 32,
  parameter int WAYS = 4
) (
  input  logic        clk,
  input  logic        rst_n,
  axi_if.slave        s_axi
);

  // ─────────── STUB BODY ───────────
  // synthesis translate_off
  initial begin
    $display("[STUB] %m instantiated, SIZE_KB=%0d, WAYS=%0d", SIZE_KB, WAYS);
  end
  // synthesis translate_on

  // Stub tie-offs intentionally omitted (interfaces only).

endmodule

`endif // ICACHE_SV
