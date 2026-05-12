// SPDX-License-Identifier: Apache-2.0
// IP: aes_engine
// AES-256 XTS engine (data path encryption)
//
// NOTE: 본 파일은 형상관리 시스템 데모를 위한 STUB RTL입니다.
//       실제 합성 가능한 구현은 IP-owner 팀이 채워야 합니다.

`ifndef AES_ENGINE_SV
`define AES_ENGINE_SV

module aes_engine #(
  parameter int KEY_W = 256,
  parameter         MODE = "XTS"
) (
  input  logic        clk,
  input  logic        rst_n,
  axi_if.slave        s_axi
);

  // ─────────── STUB BODY ───────────
  // synthesis translate_off
  initial begin
    $display("[STUB] %m instantiated, KEY_W=%0d", KEY_W);
  end
  // synthesis translate_on

  // Stub tie-offs intentionally omitted (interfaces only).

endmodule

`endif // AES_ENGINE_SV
