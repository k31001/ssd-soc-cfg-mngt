// SPDX-License-Identifier: Apache-2.0
// IP: sha_engine
// SHA-2/3 hash engine
//
// NOTE: 본 파일은 형상관리 시스템 데모를 위한 STUB RTL입니다.
//       실제 합성 가능한 구현은 IP-owner 팀이 채워야 합니다.

`ifndef SHA_ENGINE_SV
`define SHA_ENGINE_SV

module sha_engine #(
  parameter         WIDTHS = "256_384_512"
) (
  input  logic        clk,
  input  logic        rst_n,
  axi_if.slave        s_axi
);

  // ─────────── STUB BODY ───────────
  // synthesis translate_off
  initial begin
    $display("[STUB] %m instantiated", 0);
  end
  // synthesis translate_on

  // Stub tie-offs intentionally omitted (interfaces only).

endmodule

`endif // SHA_ENGINE_SV
