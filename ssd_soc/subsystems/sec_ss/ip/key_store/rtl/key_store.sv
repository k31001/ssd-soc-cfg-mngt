// SPDX-License-Identifier: Apache-2.0
// IP: key_store
// Hardware key store (OTP backed)
//
// NOTE: 본 파일은 형상관리 시스템 데모를 위한 STUB RTL입니다.
//       실제 합성 가능한 구현은 IP-owner 팀이 채워야 합니다.

`ifndef KEY_STORE_SV
`define KEY_STORE_SV

module key_store #(
  parameter int NUM_KEYS = 32,
  parameter int KEY_W = 256
) (
  input  logic        clk,
  input  logic        rst_n,
  apb_if.slave        s_apb
);

  // ─────────── STUB BODY ───────────
  // synthesis translate_off
  initial begin
    $display("[STUB] %m instantiated, NUM_KEYS=%0d, KEY_W=%0d", NUM_KEYS, KEY_W);
  end
  // synthesis translate_on

  // Stub tie-offs intentionally omitted (interfaces only).

endmodule

`endif // KEY_STORE_SV
