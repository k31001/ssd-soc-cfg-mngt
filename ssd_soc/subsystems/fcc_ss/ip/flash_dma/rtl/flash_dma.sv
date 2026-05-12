// SPDX-License-Identifier: Apache-2.0
// IP: flash_dma
// NAND-side DMA + buffer manager
//
// NOTE: 본 파일은 형상관리 시스템 데모를 위한 STUB RTL입니다.
//       실제 합성 가능한 구현은 IP-owner 팀이 채워야 합니다.

`ifndef FLASH_DMA_SV
`define FLASH_DMA_SV

module flash_dma #(
  parameter int CHANNELS = 8,
  parameter int BUF_KB = 64
) (
  input  logic        clk,
  input  logic        rst_n,
  axi_if.slave        s_axi
);

  // ─────────── STUB BODY ───────────
  // synthesis translate_off
  initial begin
    $display("[STUB] %m instantiated, CHANNELS=%0d, BUF_KB=%0d", CHANNELS, BUF_KB);
  end
  // synthesis translate_on

  // Stub tie-offs intentionally omitted (interfaces only).

endmodule

`endif // FLASH_DMA_SV
