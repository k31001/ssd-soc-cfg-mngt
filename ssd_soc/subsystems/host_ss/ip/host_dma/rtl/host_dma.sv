// SPDX-License-Identifier: Apache-2.0
// IP: host_dma
// Host-side DMA engine (PRP/SGL)
//
// NOTE: 본 파일은 형상관리 시스템 데모를 위한 STUB RTL입니다.
//       실제 합성 가능한 구현은 IP-owner 팀이 채워야 합니다.

`ifndef HOST_DMA_SV
`define HOST_DMA_SV

module host_dma #(
  parameter int CHANNELS = 8,
  parameter int OUTSTANDING = 32
) (
  input  logic        clk,
  input  logic        rst_n,
  axi_if.slave        s_axi
);

  // ─────────── STUB BODY ───────────
  // synthesis translate_off
  initial begin
    $display("[STUB] %m instantiated, CHANNELS=%0d, OUTSTANDING=%0d", CHANNELS, OUTSTANDING);
  end
  // synthesis translate_on

  // Stub tie-offs intentionally omitted (interfaces only).

endmodule

`endif // HOST_DMA_SV
