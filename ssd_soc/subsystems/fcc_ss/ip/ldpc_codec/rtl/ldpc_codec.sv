// SPDX-License-Identifier: Apache-2.0
// IP: ldpc_codec
// LDPC encoder/decoder (ECC)
//
// NOTE: 본 파일은 형상관리 시스템 데모를 위한 STUB RTL입니다.
//       실제 합성 가능한 구현은 IP-owner 팀이 채워야 합니다.

`ifndef LDPC_CODEC_SV
`define LDPC_CODEC_SV

module ldpc_codec #(
  parameter int CODEWORD = 4096,
  parameter int ITERATIONS = 16
) (
  input  logic        clk,
  input  logic        rst_n,
  axi_if.slave        s_axi
);

  // ─────────── STUB BODY ───────────
  // synthesis translate_off
  initial begin
    $display("[STUB] %m instantiated, CODEWORD=%0d, ITERATIONS=%0d", CODEWORD, ITERATIONS);
  end
  // synthesis translate_on

  // Stub tie-offs intentionally omitted (interfaces only).

endmodule

`endif // LDPC_CODEC_SV
